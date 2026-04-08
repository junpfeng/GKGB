"""
国考进面分数线爬取
数据源：上岸鸭 (gwy.com) — 历年国考进面分数线汇总 HTML 表格
官方源：国家公务员局 (scs.gov.cn) — 各部门面试公告
"""

import re
import logging
from typing import Optional

from bs4 import BeautifulSoup

from scraper_base import ScraperBase

logger = logging.getLogger(__name__)


class GuokaoScraper(ScraperBase):
    """国考进面分数线爬取"""

    # 上岸鸭历年国考分数线汇总页面
    # 这些页面包含按省份/部门整理的 HTML 表格数据
    GWY_COM_URLS = {
        2024: 'https://m.gwy.com/gjgwy/347874.html',
        2025: 'https://m.gwy.com/gjgwy/347874.html',
    }

    # 国家公务员局面试公告列表（各招录机关分别发布）
    SCS_ANNOUNCEMENT_BASE = 'http://bm.scs.gov.cn/pp/gkweb/core/web/ui/business/article/articlelist.html'

    def scrape(self, year: Optional[int] = None) -> list[dict]:
        """
        爬取国考进面分数线数据

        Args:
            year: 指定年份，None 表示爬取所有可用年份
        Returns:
            标准化数据行列表
        """
        results = []

        years = [year] if year else list(self.GWY_COM_URLS.keys())

        for y in years:
            url = self.GWY_COM_URLS.get(y)
            if not url:
                logger.warning(f'无 {y} 年国考数据源 URL')
                continue

            data = self._scrape_gwy_com(url, y)
            results.extend(data)
            logger.info(f'{y} 年国考数据: {len(data)} 条')

        return results

    def _scrape_gwy_com(self, url: str, year: int) -> list[dict]:
        """从 gwy.com 解析国考分数线 HTML 表格"""
        resp = self.fetch(url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, 'lxml')
        results = []

        # 查找所有表格 — 该页面包含多个按地区/部门分组的 table
        tables = soup.find_all('table')
        for table in tables:
            rows = table.find_all('tr')
            if len(rows) < 2:
                continue

            # 解析表头确定列映射
            headers = [th.get_text(strip=True) for th in rows[0].find_all(['th', 'td'])]
            col_map = self._map_columns(headers)
            if not col_map:
                continue

            # 解析数据行
            for row in rows[1:]:
                cells = [td.get_text(strip=True) for td in row.find_all('td')]
                if len(cells) < len(headers):
                    continue

                record = self._parse_row(cells, col_map, year, url)
                if record:
                    results.append(record)

        return results

    def _map_columns(self, headers: list[str]) -> Optional[dict]:
        """
        根据表头文字识别列索引

        常见表头：地区/省份, 部门/招录机关, 职位名称, 职位代码,
                  招录人数, 最低分/最低进面分, 最高分, 进面人数
        """
        col_map = {}
        for i, h in enumerate(headers):
            h_clean = h.replace(' ', '')
            if any(k in h_clean for k in ['地区', '省份']):
                col_map['province'] = i
            elif any(k in h_clean for k in ['部门', '招录机关', '用人单位']):
                col_map['department'] = i
            elif any(k in h_clean for k in ['职位名称', '岗位名称', '岗位']):
                col_map['position_name'] = i
            elif any(k in h_clean for k in ['职位代码', '岗位代码']):
                col_map['position_code'] = i
            elif any(k in h_clean for k in ['招录人数', '招考人数', '录用']):
                col_map['recruit_count'] = i
            elif any(k in h_clean for k in ['最低分', '最低进面', '笔试最低']):
                col_map['min_score'] = i
            elif any(k in h_clean for k in ['最高分', '最高进面', '笔试最高']):
                col_map['max_score'] = i
            elif any(k in h_clean for k in ['进面人数', '面试人数']):
                col_map['entry_count'] = i
            elif any(k in h_clean for k in ['学历', '学历要求']):
                col_map['education_req'] = i
            elif any(k in h_clean for k in ['专业', '专业要求']):
                col_map['major_req'] = i
            elif any(k in h_clean for k in ['城市', '地市']):
                col_map['city'] = i

        # 至少需要职位名称和分数
        if 'position_name' not in col_map and 'department' not in col_map:
            return None
        if 'min_score' not in col_map and 'max_score' not in col_map:
            return None

        return col_map

    def _parse_row(self, cells: list[str], col_map: dict, year: int, source_url: str) -> Optional[dict]:
        """解析单行数据为标准格式"""
        try:
            province = cells[col_map['province']] if 'province' in col_map else '全国'
            city = cells[col_map.get('city', -1)] if 'city' in col_map else province

            department = cells[col_map['department']] if 'department' in col_map else ''
            position_name = cells[col_map.get('position_name', col_map.get('department', 0))]

            if not position_name.strip():
                return None

            min_score = self._parse_score(cells[col_map['min_score']]) if 'min_score' in col_map else None
            max_score = self._parse_score(cells[col_map['max_score']]) if 'max_score' in col_map else None

            if min_score is None and max_score is None:
                return None

            return {
                'province': province,
                'city': city if city else province,
                'year': year,
                'exam_type': '国考',
                'department': department,
                'position_name': position_name,
                'position_code': cells[col_map.get('position_code', -1)] if 'position_code' in col_map else None,
                'recruit_count': self._parse_int(cells[col_map['recruit_count']]) if 'recruit_count' in col_map else None,
                'education_req': cells[col_map.get('education_req', -1)] if 'education_req' in col_map else None,
                'major_req': cells[col_map.get('major_req', -1)] if 'major_req' in col_map else None,
                'min_entry_score': min_score,
                'max_entry_score': max_score,
                'entry_count': self._parse_int(cells[col_map['entry_count']]) if 'entry_count' in col_map else None,
                'source_url': source_url,
            }
        except (IndexError, ValueError) as e:
            logger.debug(f'解析行失败: {e}')
            return None

    @staticmethod
    def _parse_score(text: str) -> Optional[float]:
        """从文本中提取分数"""
        text = text.strip()
        if not text or text in ('-', '—', '/'):
            return None
        # 匹配数字（含小数）
        match = re.search(r'(\d+\.?\d*)', text)
        if match:
            return float(match.group(1))
        return None

    @staticmethod
    def _parse_int(text: str) -> Optional[int]:
        """从文本中提取整数"""
        text = text.strip()
        match = re.search(r'(\d+)', text)
        if match:
            return int(match.group(1))
        return None


if __name__ == '__main__':
    scraper = GuokaoScraper()
    data = scraper.scrape(year=2024)
    print(f'共获取 {len(data)} 条国考数据')
    for row in data[:5]:
        print(f"  {row['province']} {row['department']} {row['position_name']} "
              f"分数: {row['min_entry_score']}-{row['max_entry_score']}")
