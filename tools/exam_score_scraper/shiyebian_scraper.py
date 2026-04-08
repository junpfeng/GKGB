"""
事业编进面分数线爬取

数据源状态（2025-04 验证）：
  - 江苏 js.huatu.com：URL 返回 200 但内容为分类导航页，无直接分数线表格
  - 浙江 zj.huatu.com：同上
  - 山东 sd.huatu.com：同上
  - 上海 sh.huatu.com：同上
  - 各省人社厅官方站：无统一结构化分数线汇总页

当前状态：暂无已验证的可用结构化事业编数据源。
现有 assets/data/exam_entry_scores/*_shiyebian_*.json 为示例数据，保持不变。

待补充：
  - 若找到可用来源后在此处添加 URL 并实现解析逻辑
"""

import re
import io
import logging
from typing import Optional

import pandas as pd
from bs4 import BeautifulSoup

from scraper_base import ScraperBase

logger = logging.getLogger(__name__)


# 省份配置：当前无可用来源，配置为空（保留结构供后续扩展）
SHIYEBIAN_CONFIG: dict = {
    # '江苏': {
    #     'article_urls': {
    #         2024: 'TODO: 待添加已验证可用的 URL',
    #     },
    # },
}


class ShiyebianScraper(ScraperBase):
    """事业编进面分数线爬取（当前暂无可用来源）"""

    def scrape(self, province: Optional[str] = None, year: Optional[int] = None) -> list[dict]:
        """
        爬取事业编分数线

        当前所有已知来源（huatu.com 各省站、各省人社厅）均无可直接解析的
        结构化分数线表格，返回空列表，现有示例数据不会被覆盖。

        Args:
            province: 指定省份
            year: 指定年份
        Returns:
            空列表（待后续添加可用数据源后实现）
        """
        if SHIYEBIAN_CONFIG:
            return self._scrape_configured(province, year)

        logger.warning('事业编爬虫：当前无已验证的可用数据源，跳过采集')
        return []

    def _scrape_configured(self, province: Optional[str], year: Optional[int]) -> list[dict]:
        """当 SHIYEBIAN_CONFIG 有配置时执行采集"""
        results = []
        provinces = [province] if province else list(SHIYEBIAN_CONFIG.keys())

        for prov in provinces:
            config = SHIYEBIAN_CONFIG.get(prov)
            if not config:
                continue

            years = [year] if year else list(config['article_urls'].keys())
            for y in years:
                url = config['article_urls'].get(y)
                if not url:
                    continue

                data = self._scrape_html_table(url, prov, y)
                results.extend(data)
                logger.info(f'{prov} {y}年事业编数据: {len(data)} 条')

        return results

    def _scrape_html_table(self, url: str, province: str, year: int) -> list[dict]:
        """从 HTML 页面解析分数线表格"""
        resp = self.fetch(url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, 'lxml')
        results = []

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

        return results

    def _map_columns(self, headers: list[str]) -> Optional[dict]:
        """根据表头识别列索引"""
        col_map = {}
        for i, h in enumerate(headers):
            h_clean = h.replace(' ', '')
            if any(k in h_clean for k in ['城市', '地市', '考区']):
                col_map['city'] = i
            elif any(k in h_clean for k in ['招聘单位', '部门', '单位']):
                col_map['department'] = i
            elif any(k in h_clean for k in ['岗位名称', '职位名称', '岗位']):
                col_map['position_name'] = i
            elif any(k in h_clean for k in ['岗位代码', '职位代码']):
                col_map['position_code'] = i
            elif any(k in h_clean for k in ['招聘人数', '招录人数']):
                col_map['recruit_count'] = i
            elif any(k in h_clean for k in ['最低分', '入面最低']):
                col_map['min_score'] = i
            elif any(k in h_clean for k in ['最高分', '入面最高']):
                col_map['max_score'] = i
            elif any(k in h_clean for k in ['进面人数', '面试人数']):
                col_map['entry_count'] = i
            elif any(k in h_clean for k in ['学历']):
                col_map['education_req'] = i
            elif any(k in h_clean for k in ['专业']):
                col_map['major_req'] = i
            elif any(k in h_clean for k in ['类别', '岗位类别']):
                col_map['category'] = i

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

            category = cells[col_map['category']].strip() if 'category' in col_map else ''
            other_req = f'类别: {category}' if category else None

            return {
                'province': province,
                'city': city if city else province,
                'year': year,
                'exam_type': '事业编',
                'department': department,
                'position_name': position_name,
                'position_code': cells[col_map['position_code']].strip() if 'position_code' in col_map else None,
                'recruit_count': self._parse_int(cells[col_map['recruit_count']]) if 'recruit_count' in col_map else None,
                'education_req': cells[col_map['education_req']].strip() if 'education_req' in col_map else None,
                'major_req': cells[col_map['major_req']].strip() if 'major_req' in col_map else None,
                'other_req': other_req,
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
    import logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

    scraper = ShiyebianScraper()
    data = scraper.scrape(province='江苏', year=2024)
    print(f'共获取 {len(data)} 条事业编数据（当前无可用数据源）')
