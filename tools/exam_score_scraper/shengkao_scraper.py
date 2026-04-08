"""
省考进面分数线爬取
数据源：
  - 华图教育多省查询工具: https://www.huatu.com/z/2024skfscx/
  - 华图各省站点：含 Excel 下载（山东等）
  - 各省人事考试网（官方 HTML 公告）
"""

import re
import io
import logging
from typing import Optional

import pandas as pd
from bs4 import BeautifulSoup

from scraper_base import ScraperBase

logger = logging.getLogger(__name__)


# 省份 → 华图省站域名 和 分数线文章 URL 模式
PROVINCE_CONFIG = {
    '江苏': {
        'huatu_domain': 'js.huatu.com',
        # 华图江苏站分数线查询工具
        'query_tool': 'https://js.huatu.com/zt/fsxxt/',
        # 历年分数线汇总文章（含 HTML 表格）
        'article_urls': {
            2024: 'https://js.huatu.com/gwy/zhaokao/2024/',
            2025: 'https://js.huatu.com/gwy/zhaokao/2025/',
        },
    },
    '浙江': {
        'huatu_domain': 'zj.huatu.com',
        'query_tool': 'https://zj.huatu.com/zt/skfsx/',
        'article_urls': {
            2024: 'https://zj.huatu.com/gwy/zhaokao/2024/',
            2025: 'https://zj.huatu.com/gwy/zhaokao/2025/',
        },
    },
    '上海': {
        'huatu_domain': 'sh.huatu.com',
        'query_tool': 'https://sh.huatu.com/zt/skfsx/',
        'article_urls': {
            2024: 'https://sh.huatu.com/gwy/zhaokao/2024/',
        },
    },
    '山东': {
        'huatu_domain': 'sd.huatu.com',
        'query_tool': 'https://sd.huatu.com/zt/skfsx/',
        'article_urls': {
            # 山东华图提供 Excel 下载
            2024: 'https://sd.huatu.com/2024/1029/1559730.html',
            2025: 'https://sd.huatu.com/gwy/zhaokao/2025/',
        },
    },
}

# 华图多省查询工具 URL（按年份）
HUATU_MULTI_PROVINCE_URLS = {
    2024: 'https://www.huatu.com/z/2024skfscx/',
    2025: 'https://www.huatu.com/z/2025skfscx/',
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
                logger.warning(f'未配置省份: {prov}')
                continue

            years = [year] if year else list(config['article_urls'].keys())
            for y in years:
                data = self._scrape_province(prov, y, config)
                results.extend(data)
                logger.info(f'{prov} {y}年省考数据: {len(data)} 条')

        return results

    def _scrape_province(self, province: str, year: int, config: dict) -> list[dict]:
        """爬取单个省份单个年份的数据"""
        url = config['article_urls'].get(year)
        if not url:
            logger.warning(f'无 {province} {year}年数据源 URL')
            return []

        # 山东华图提供 Excel 下载
        if province == '山东' and '.html' in url:
            return self._scrape_shandong_excel(url, year)

        # 其他省份解析 HTML 表格
        return self._scrape_html_table(url, province, year)

    def _scrape_html_table(self, url: str, province: str, year: int) -> list[dict]:
        """从 HTML 页面解析分数线表格"""
        resp = self.fetch(url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, 'lxml')
        results = []

        # 查找页面中的表格
        tables = soup.find_all('table')
        for table in tables:
            rows = table.find_all('tr')
            if len(rows) < 2:
                continue

            headers = [th.get_text(strip=True) for th in rows[0].find_all(['th', 'td'])]
            col_map = self._map_columns(headers)
            if not col_map:
                continue

            for row in rows[1:]:
                cells = [td.get_text(strip=True) for td in row.find_all('td')]
                if len(cells) < 3:
                    continue

                record = self._parse_row(cells, col_map, province, year, url)
                if record:
                    results.append(record)

        # 如果没找到表格，尝试从文章中提取内嵌的 Excel 下载链接
        if not results:
            excel_links = soup.find_all('a', href=re.compile(r'\.(xlsx?|csv)'))
            for link in excel_links:
                href = link.get('href', '')
                if not href.startswith('http'):
                    from urllib.parse import urljoin
                    href = urljoin(url, href)
                excel_data = self._parse_excel(href, province, year)
                results.extend(excel_data)

        return results

    def _scrape_shandong_excel(self, article_url: str, year: int) -> list[dict]:
        """
        山东华图站提供 Excel 下载
        文章页面包含 .xlsx 下载链接
        """
        resp = self.fetch(article_url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, 'lxml')
        results = []

        # 查找 Excel 下载链接
        excel_links = soup.find_all('a', href=re.compile(r'\.(xlsx?|xls)'))
        for link in excel_links:
            href = link.get('href', '')
            if not href.startswith('http'):
                from urllib.parse import urljoin
                href = urljoin(article_url, href)

            logger.info(f'发现 Excel 下载链接: {href}')
            data = self._parse_excel(href, '山东', year)
            results.extend(data)

        # 如果没有 Excel，回退到 HTML 表格解析
        if not results:
            results = self._scrape_html_table(article_url, '山东', year)

        return results

    def _parse_excel(self, url: str, province: str, year: int) -> list[dict]:
        """下载并解析 Excel 文件"""
        content = self.fetch_binary(url)
        if content is None:
            return []

        results = []
        try:
            df = pd.read_excel(io.BytesIO(content), engine='openpyxl')

            # 标准化列名映射
            col_rename = {}
            for col in df.columns:
                col_str = str(col).strip()
                if any(k in col_str for k in ['地市', '城市', '考区']):
                    col_rename[col] = 'city'
                elif any(k in col_str for k in ['招录机关', '部门', '单位']):
                    col_rename[col] = 'department'
                elif any(k in col_str for k in ['职位名称', '岗位名称']):
                    col_rename[col] = 'position_name'
                elif any(k in col_str for k in ['职位代码', '岗位代码']):
                    col_rename[col] = 'position_code'
                elif any(k in col_str for k in ['录用计划', '招录人数', '招考人数']):
                    col_rename[col] = 'recruit_count'
                elif any(k in col_str for k in ['最低分', '最低进面', '入面最低']):
                    col_rename[col] = 'min_entry_score'
                elif any(k in col_str for k in ['最高分', '最高进面', '入面最高']):
                    col_rename[col] = 'max_entry_score'
                elif any(k in col_str for k in ['进面人数', '面试人数', '入面人数']):
                    col_rename[col] = 'entry_count'
                elif any(k in col_str for k in ['学历要求', '学历']):
                    col_rename[col] = 'education_req'
                elif any(k in col_str for k in ['专业要求', '专业']):
                    col_rename[col] = 'major_req'
                elif any(k in col_str for k in ['学位要求', '学位']):
                    col_rename[col] = 'degree_req'
                elif any(k in col_str for k in ['政治面貌']):
                    col_rename[col] = 'political_req'
                elif any(k in col_str for k in ['工作经历', '基层经验']):
                    col_rename[col] = 'work_exp_req'
                elif any(k in col_str for k in ['其他', '备注']):
                    col_rename[col] = 'other_req'

            df = df.rename(columns=col_rename)

            for _, row in df.iterrows():
                record = {
                    'province': province,
                    'city': str(row.get('city', province)).strip() if pd.notna(row.get('city')) else province,
                    'year': year,
                    'exam_type': '省考',
                    'department': str(row.get('department', '')).strip() if pd.notna(row.get('department')) else '',
                    'position_name': str(row.get('position_name', '')).strip() if pd.notna(row.get('position_name')) else '',
                    'position_code': str(row.get('position_code', '')).strip() if pd.notna(row.get('position_code')) else None,
                    'recruit_count': int(row['recruit_count']) if 'recruit_count' in row.index and pd.notna(row.get('recruit_count')) else None,
                    'education_req': str(row.get('education_req', '')).strip() if pd.notna(row.get('education_req')) else None,
                    'degree_req': str(row.get('degree_req', '')).strip() if pd.notna(row.get('degree_req')) else None,
                    'major_req': str(row.get('major_req', '')).strip() if pd.notna(row.get('major_req')) else None,
                    'political_req': str(row.get('political_req', '')).strip() if pd.notna(row.get('political_req')) else None,
                    'work_exp_req': str(row.get('work_exp_req', '')).strip() if pd.notna(row.get('work_exp_req')) else None,
                    'other_req': str(row.get('other_req', '')).strip() if pd.notna(row.get('other_req')) else None,
                    'min_entry_score': float(row['min_entry_score']) if 'min_entry_score' in row.index and pd.notna(row.get('min_entry_score')) else None,
                    'max_entry_score': float(row['max_entry_score']) if 'max_entry_score' in row.index and pd.notna(row.get('max_entry_score')) else None,
                    'entry_count': int(row['entry_count']) if 'entry_count' in row.index and pd.notna(row.get('entry_count')) else None,
                    'source_url': url,
                }

                # 跳过无效行
                if not record['position_name'] or (record['min_entry_score'] is None and record['max_entry_score'] is None):
                    continue

                results.append(record)

            logger.info(f'Excel 解析: {len(results)} 条有效数据')

        except Exception as e:
            logger.error(f'解析 Excel 失败 ({url}): {e}')

        return results

    def _map_columns(self, headers: list[str]) -> Optional[dict]:
        """根据表头识别列索引"""
        col_map = {}
        for i, h in enumerate(headers):
            h_clean = h.replace(' ', '')
            if any(k in h_clean for k in ['城市', '地市', '考区']):
                col_map['city'] = i
            elif any(k in h_clean for k in ['部门', '招录机关', '单位']):
                col_map['department'] = i
            elif any(k in h_clean for k in ['职位名称', '岗位名称', '岗位']):
                col_map['position_name'] = i
            elif any(k in h_clean for k in ['职位代码', '岗位代码']):
                col_map['position_code'] = i
            elif any(k in h_clean for k in ['招录人数', '录用计划']):
                col_map['recruit_count'] = i
            elif any(k in h_clean for k in ['最低分', '最低进面', '入面最低']):
                col_map['min_score'] = i
            elif any(k in h_clean for k in ['最高分', '最高进面']):
                col_map['max_score'] = i
            elif any(k in h_clean for k in ['进面人数', '面试人数']):
                col_map['entry_count'] = i
            elif any(k in h_clean for k in ['学历']):
                col_map['education_req'] = i
            elif any(k in h_clean for k in ['专业']):
                col_map['major_req'] = i

        if 'min_score' not in col_map and 'max_score' not in col_map:
            return None
        return col_map

    def _parse_row(self, cells: list[str], col_map: dict, province: str, year: int, source_url: str) -> Optional[dict]:
        """解析单行数据"""
        try:
            city = cells[col_map['city']].strip() if 'city' in col_map else province
            department = cells[col_map['department']].strip() if 'department' in col_map else ''
            position_name = cells[col_map.get('position_name', col_map.get('department', 0))].strip()

            if not position_name:
                return None

            min_score = self._parse_number(cells[col_map['min_score']]) if 'min_score' in col_map else None
            max_score = self._parse_number(cells[col_map['max_score']]) if 'max_score' in col_map else None

            if min_score is None and max_score is None:
                return None

            return {
                'province': province,
                'city': city if city else province,
                'year': year,
                'exam_type': '省考',
                'department': department,
                'position_name': position_name,
                'position_code': cells[col_map['position_code']].strip() if 'position_code' in col_map else None,
                'recruit_count': self._parse_int(cells[col_map['recruit_count']]) if 'recruit_count' in col_map else None,
                'education_req': cells[col_map['education_req']].strip() if 'education_req' in col_map else None,
                'major_req': cells[col_map['major_req']].strip() if 'major_req' in col_map else None,
                'min_entry_score': min_score,
                'max_entry_score': max_score,
                'entry_count': self._parse_int(cells[col_map['entry_count']]) if 'entry_count' in col_map else None,
                'source_url': source_url,
            }
        except (IndexError, ValueError) as e:
            logger.debug(f'解析行失败: {e}')
            return None

    @staticmethod
    def _parse_number(text: str) -> Optional[float]:
        text = text.strip()
        if not text or text in ('-', '—', '/'):
            return None
        match = re.search(r'(\d+\.?\d*)', text)
        return float(match.group(1)) if match else None

    @staticmethod
    def _parse_int(text: str) -> Optional[int]:
        text = text.strip()
        match = re.search(r'(\d+)', text)
        return int(match.group(1)) if match else None


if __name__ == '__main__':
    scraper = ShengkaoScraper()

    # 爬取山东 2024 省考数据（有 Excel 下载）
    data = scraper.scrape(province='山东', year=2024)
    print(f'共获取 {len(data)} 条山东省考数据')
    for row in data[:5]:
        print(f"  {row['city']} {row['department']} {row['position_name']} "
              f"分数: {row['min_entry_score']}-{row['max_entry_score']}")
