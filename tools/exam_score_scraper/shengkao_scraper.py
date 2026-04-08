"""
省考进面分数线爬取

数据源（已验证可用，2025-04）：
  - 江苏：qihejy.com 各地市进面名单 Excel（download.qihejy.com 允许）
           Excel 为进面人员名单，含职位、行测/申论/总分，按职位聚合得出最低进面分
  - 山东：sd.huatu.com 文章页有 Excel 链接，但链接指向 u3.huatu.com
           u3.huatu.com robots.txt 禁止，HTML 表格也为空，暂无可用来源
  - 浙江：暂无已验证的可用结构化来源
  - 上海：暂无已验证的可用结构化来源

robots.txt 检查结果：
  - www.qihejy.com：允许
  - download.qihejy.com：允许
  - sd.huatu.com：允许（HTML 页面）
  - u3.huatu.com：禁止（Excel 下载路径），回退到 HTML 但 HTML 无表格
"""

import re
import io
import logging
import time
from typing import Optional
from urllib.parse import unquote

import pandas as pd
from bs4 import BeautifulSoup

from scraper_base import ScraperBase

logger = logging.getLogger(__name__)


# 省份配置：仅江苏有可用的真实数据源
PROVINCE_CONFIG = {
    '江苏': {
        # qihejy.com 汇总页，含各地市 Excel 下载链接
        'index_urls': {
            2024: 'https://www.qihejy.com/news/info?id=15592',
        },
    },
    # 山东、浙江、上海：暂无可用结构化来源，export_json.py 会保留已有示例数据
}


class ShengkaoScraper(ScraperBase):
    """省考进面分数线爬取"""

    def scrape(self, province: Optional[str] = None, year: Optional[int] = None) -> list[dict]:
        """
        爬取省考分数线

        Args:
            province: 指定省份，None 表示爬取所有已配置省份
            year: 指定年份，None 表示爬取所有可用年份
        Returns:
            标准化数据行列表
        """
        results = []

        provinces = [province] if province else list(PROVINCE_CONFIG.keys())

        for prov in provinces:
            config = PROVINCE_CONFIG.get(prov)
            if not config:
                logger.warning(f'未配置可用数据源: {prov}，跳过')
                continue

            years = [year] if year else list(config['index_urls'].keys())
            for y in years:
                data = self._scrape_province(prov, y, config)
                results.extend(data)
                logger.info(f'{prov} {y}年省考数据: {len(data)} 条')

        return results

    def _scrape_province(self, province: str, year: int, config: dict) -> list[dict]:
        """爬取单个省份单个年份的数据"""
        url = config['index_urls'].get(year)
        if not url:
            logger.warning(f'无 {province} {year}年数据源 URL')
            return []

        if province == '江苏':
            return self._scrape_jiangsu(url, year)

        return []

    # -------------------------------------------------------------------------
    # 江苏：qihejy.com → download.qihejy.com Excel
    # -------------------------------------------------------------------------

    def _scrape_jiangsu(self, index_url: str, year: int) -> list[dict]:
        """
        江苏省考：从 qihejy.com 汇总页获取各地市 Excel 下载链接，
        下载并解析进面名单，按职位聚合计算最低进面分数线
        """
        resp = self.fetch(index_url)
        if resp is None:
            return []

        resp.encoding = 'utf-8'
        soup = BeautifulSoup(resp.text, 'lxml')

        # 收集当年进面名单 Excel 链接（排除体检名单）
        excel_links = self._find_jiangsu_excel_links(soup, year)
        logger.info(f'江苏 {year}年进面名单 Excel: {len(excel_links)} 个')

        results = []
        for filename, href in excel_links:
            logger.info(f'下载: {filename}')
            data = self._parse_jiangsu_entry_list(href, year, filename)
            results.extend(data)
            logger.info(f'  → {len(data)} 条职位分数线')

        return results

    def _find_jiangsu_excel_links(self, soup: BeautifulSoup, year: int) -> list[tuple[str, str]]:
        """
        从页面中找出目标年份的进面名单 Excel 链接
        返回 [(filename, url), ...]
        """
        links = []
        year_str = str(year)

        # 找所有 Excel 链接
        all_excel = soup.find_all('a', href=re.compile(r'\.(xlsx?|xls)', re.I))
        for link in all_excel:
            href = link.get('href', '')
            if not href:
                continue

            filename = unquote(href.split('/')[-1])

            # 过滤：必须含目标年份
            if year_str not in filename:
                continue

            # 过滤：进面名单关键词（排除体检、拟进入体检）
            has_entry_kw = any(k in filename for k in ['进面', '入围面', '面试人员', '面试人选', '进入面试'])
            has_exclude_kw = any(k in filename for k in ['体检', '拟进入体检', '考察'])
            if not has_entry_kw or has_exclude_kw:
                continue

            links.append((filename, href))

        return links

    def _parse_jiangsu_entry_list(self, url: str, year: int, filename: str) -> list[dict]:
        """
        下载并解析江苏进面名单 Excel
        不同城市格式有差异，支持多种格式：
          - 格式A（南通/泰州/宿迁）：地区 | 单位名称 | 职位名称 | ... | 总分 | 排名
          - 格式B（扬州）：准考证号 | 所在市 | 所在县 | 单位名称 | 职位名称 | 职位代码 | ... | 笔试成绩 | 职位排名
          - 格式C（徐州）：序号 | 准考证号 | 姓名 | 单位代码 | 单位名称 | 职位序号 | 职位名称 | ... | 总分 | 排名
        按职位聚合，取总分 min/max 作为进面分数线
        """
        content = self.fetch_binary(url)
        if content is None:
            return []

        results = []
        try:
            # 尝试不同的 header 行（0 或 1），选择能识别出列结构的
            df = None
            col_map = None
            # 根据文件名选择 engine（.xls 用 xlrd，.xlsx 用 openpyxl）
            engine = 'xlrd' if filename.lower().endswith('.xls') else 'openpyxl'

            for header_row in [0, 1]:
                try:
                    _df = pd.read_excel(io.BytesIO(content), engine=engine, header=header_row)
                    if len(_df.columns) < 6:
                        continue
                    _col_map = self._map_jiangsu_columns(list(_df.columns))
                    if _col_map:
                        df = _df
                        col_map = _col_map
                        break
                except Exception as e:
                    logger.debug(f'尝试 header={header_row} 失败: {e}')
                    continue

            if df is None or col_map is None:
                try:
                    _df_debug = pd.read_excel(io.BytesIO(content), engine=engine, header=0)
                    debug_cols = list(_df_debug.columns)[:8]
                except Exception:
                    debug_cols = ['(读取失败)']
                logger.warning(f'无法识别列结构: {filename}, 列名: {debug_cols}')
                return []

            # 从文件名提取城市名
            city = self._extract_city_from_filename(filename)

            pos_col = col_map['position_name']

            # 确定分数列：优先用总分，否则用行测+申论求和
            if col_map.get('use_sum'):
                xc_col = col_map['score_xingce']
                sl_col = col_map['score_shenlun']
                df['_calc_total'] = (
                    pd.to_numeric(df[xc_col], errors='coerce') +
                    pd.to_numeric(df[sl_col], errors='coerce')
                )
                score_col = '_calc_total'
            else:
                score_col = col_map['total_score']

            # 过滤有效行（职位名和总分不能为空）
            df_valid = df.dropna(subset=[pos_col, score_col]).copy()
            df_valid = df_valid[pd.to_numeric(df_valid[score_col], errors='coerce').notna()]
            df_valid[score_col] = pd.to_numeric(df_valid[score_col], errors='coerce')

            if df_valid.empty:
                logger.warning(f'无有效数据行: {filename}')
                return []

            # 按 [城市, 单位, 职位] 分组，计算 min/max 进面分
            group_cols = [pos_col]
            dept_col = col_map.get('department')
            if dept_col:
                group_cols = [dept_col] + group_cols

            grouped = df_valid.groupby(group_cols, dropna=False)[score_col].agg(['min', 'max', 'count'])

            for idx, row in grouped.iterrows():
                if isinstance(idx, tuple):
                    dept = str(idx[0]).strip() if len(idx) > 1 else ''
                    pos = str(idx[-1]).strip()
                else:
                    dept = ''
                    pos = str(idx).strip()

                if not pos or pos in ('nan', 'NaN'):
                    continue

                min_score = round(float(row['min']), 1)
                max_score = round(float(row['max']), 1)
                entry_count = int(row['count'])

                # 过滤不合理分数
                if not (30 <= min_score <= 300):
                    continue

                results.append({
                    'province': '江苏',
                    'city': city or '江苏',
                    'year': year,
                    'exam_type': '省考',
                    'department': dept,
                    'position_name': pos,
                    'position_code': None,
                    'recruit_count': None,
                    'education_req': None,
                    'major_req': None,
                    'min_entry_score': min_score,
                    'max_entry_score': max_score,
                    'entry_count': entry_count,
                    'source_url': url,
                })

            logger.info(f'聚合职位分数线: {len(results)} 条 ({filename})')

        except Exception as e:
            logger.error(f'解析 Excel 失败 ({filename}): {e}')

        return results

    def _map_jiangsu_columns(self, columns: list) -> Optional[dict]:
        """
        识别江苏进面名单 Excel 的列结构，支持多种格式变体
        返回 {role: column_name} 或 None（识别失败）
        """
        col_map = {}
        for col in columns:
            # 将含换行的列名展平（如 "职位\n名称" → "职位名称"）
            col_str = str(col).strip().replace('\n', '').replace(' ', '')

            if any(k in col_str for k in ['地区', '考区', '城市', '所在市']):
                col_map['city'] = col
            elif any(k in col_str for k in ['单位名称', '招录机关', '部门', '招考单位', '用人单位']):
                col_map['department'] = col
            elif any(k in col_str for k in ['职位名称', '岗位名称']):
                # 排除"职位代码"（只取名称列）
                if '代码' not in col_str and '序号' not in col_str:
                    col_map['position_name'] = col
            elif any(k in col_str for k in ['总分', '综合成绩', '笔试总分', '笔试成绩']):
                col_map['total_score'] = col
            elif any(k in col_str for k in ['行测', '行政职业能力']):
                col_map['score_xingce'] = col
            elif any(k in col_str for k in ['申论', '写作']):
                col_map['score_shenlun'] = col
            elif any(k in col_str for k in ['排名', '名次', '职位排名']):
                col_map['rank'] = col

        # 必需：职位名 + 总分（或可以从行测+申论推算）
        if 'position_name' not in col_map:
            return None

        if 'total_score' not in col_map:
            # 尝试用行测+申论成绩
            if 'score_xingce' in col_map and 'score_shenlun' in col_map:
                col_map['use_sum'] = True  # 标记需要计算总分
            else:
                return None

        return col_map

    def _extract_city_from_filename(self, filename: str) -> Optional[str]:
        """从文件名提取城市名"""
        # 常见格式：南通市2024年度...xlsx、扬州市2024...xlsx
        city_pattern = re.match(r'^(.{2,4})[市县区]', filename)
        if city_pattern:
            return city_pattern.group(1)
        return None


if __name__ == '__main__':
    import logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

    scraper = ShengkaoScraper()

    # 爬取江苏 2024 省考数据
    data = scraper.scrape(province='江苏', year=2024)
    print(f'共获取 {len(data)} 条江苏省考数据')
    for row in data[:5]:
        print(f"  {row['city']} {row['department']} {row['position_name']} "
              f"分数: {row['min_entry_score']}-{row['max_entry_score']}")
