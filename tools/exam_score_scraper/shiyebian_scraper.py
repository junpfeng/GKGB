"""
事业编进面分数线爬取
数据源：
  - 各省人社厅事业单位公开招聘公告
  - 华图教育事业编分数线汇总
  - 各地市人事考试网
"""

import re
import io
import logging
from typing import Optional

import pandas as pd
from bs4 import BeautifulSoup

from scraper_base import ScraperBase

logger = logging.getLogger(__name__)


# 省份 → 事业编数据源配置
SHIYEBIAN_CONFIG = {
    '江苏': {
        # 江苏事业单位统考分数线
        'article_urls': {
            2024: 'https://js.huatu.com/sydw/zhaokao/2024/',
        },
        # 官方源：江苏省属事业单位公开招聘
        'official_urls': {
            2024: 'https://jshrss.jiangsu.gov.cn/col/col57298/index.html',
        },
    },
    '浙江': {
        'article_urls': {
            2024: 'https://zj.huatu.com/sydw/zhaokao/2024/',
        },
        'official_urls': {
            2024: 'http://www.zjks.gov.cn/sydw/',
        },
    },
    '山东': {
        'article_urls': {
            2024: 'https://sd.huatu.com/sydw/zhaokao/2024/',
        },
        'official_urls': {
            2024: 'https://hrss.shandong.gov.cn/rsks/channels/ch03574/',
        },
    },
    '上海': {
        'article_urls': {
            2024: 'https://sh.huatu.com/sydw/zhaokao/2024/',
        },
    },
}


class ShiyebianScraper(ScraperBase):
    """事业编进面分数线爬取"""

    def scrape(self, province: Optional[str] = None, year: Optional[int] = None) -> list[dict]:
        """
        爬取事业编分数线

        Args:
            province: 指定省份，None 表示爬取所有已配置省份
            year: 指定年份
        Returns:
            标准化数据行列表
        """
        results = []

        provinces = [province] if province else list(SHIYEBIAN_CONFIG.keys())

        for prov in provinces:
            config = SHIYEBIAN_CONFIG.get(prov)
            if not config:
                logger.warning(f'未配置省份: {prov}')
                continue

            years = [year] if year else list(config['article_urls'].keys())
            for y in years:
                # 优先尝试华图汇总文章
                url = config['article_urls'].get(y)
                if url:
                    data = self._scrape_article(url, prov, y)
                    results.extend(data)
                    logger.info(f'{prov} {y}年事业编数据（华图）: {len(data)} 条')

                # 补充尝试官方源
                official_url = config.get('official_urls', {}).get(y)
                if official_url and not data:
                    data = self._scrape_official(official_url, prov, y)
                    results.extend(data)
                    logger.info(f'{prov} {y}年事业编数据（官方）: {len(data)} 条')

        return results

    def _scrape_article(self, url: str, province: str, year: int) -> list[dict]:
        """从华图文章页面解析分数线数据"""
        resp = self.fetch(url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, 'lxml')
        results = []

        # 查找文章列表页中的分数线相关链接
        score_links = []
        for link in soup.find_all('a', href=True):
            text = link.get_text(strip=True)
            if any(k in text for k in ['分数线', '进面', '入面', '面试名单']):
                href = link['href']
                if not href.startswith('http'):
                    from urllib.parse import urljoin
                    href = urljoin(url, href)
                score_links.append(href)

        # 逐个解析分数线文章
        for link_url in score_links[:10]:  # 限制最多 10 个链接
            data = self._parse_score_article(link_url, province, year)
            results.extend(data)

        # 如果没有找到链接，直接解析当前页面的表格
        if not score_links:
            results = self._parse_tables(soup, province, year, url)

        return results

    def _scrape_official(self, url: str, province: str, year: int) -> list[dict]:
        """从官方网站解析"""
        resp = self.fetch(url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, 'lxml')

        # 查找公示/公告链接
        results = []
        for link in soup.find_all('a', href=True):
            text = link.get_text(strip=True)
            if any(k in text for k in ['面试', '入围', '进入面试']):
                href = link['href']
                if not href.startswith('http'):
                    from urllib.parse import urljoin
                    href = urljoin(url, href)
                data = self._parse_score_article(href, province, year)
                results.extend(data)

                if len(results) > 100:
                    break

        return results

    def _parse_score_article(self, url: str, province: str, year: int) -> list[dict]:
        """解析单篇分数线文章"""
        resp = self.fetch(url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, 'lxml')
        results = self._parse_tables(soup, province, year, url)

        # 尝试查找 Excel 附件下载
        if not results:
            excel_links = soup.find_all('a', href=re.compile(r'\.(xlsx?|xls)'))
            for link in excel_links:
                href = link.get('href', '')
                if not href.startswith('http'):
                    from urllib.parse import urljoin
                    href = urljoin(url, href)
                data = self._parse_excel(href, province, year)
                results.extend(data)

        return results

    def _parse_tables(self, soup: BeautifulSoup, province: str, year: int, source_url: str) -> list[dict]:
        """解析页面中的所有表格"""
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

                record = self._parse_row(cells, col_map, province, year, source_url)
                if record:
                    results.append(record)

        return results

    def _parse_excel(self, url: str, province: str, year: int) -> list[dict]:
        """下载并解析 Excel 附件"""
        content = self.fetch_binary(url)
        if content is None:
            return []

        results = []
        try:
            df = pd.read_excel(io.BytesIO(content), engine='openpyxl')

            col_rename = {}
            for col in df.columns:
                col_str = str(col).strip()
                if any(k in col_str for k in ['地市', '城市', '考区']):
                    col_rename[col] = 'city'
                elif any(k in col_str for k in ['招聘单位', '部门', '单位名称']):
                    col_rename[col] = 'department'
                elif any(k in col_str for k in ['岗位名称', '职位名称']):
                    col_rename[col] = 'position_name'
                elif any(k in col_str for k in ['岗位代码', '职位代码']):
                    col_rename[col] = 'position_code'
                elif any(k in col_str for k in ['招聘人数', '招录人数']):
                    col_rename[col] = 'recruit_count'
                elif any(k in col_str for k in ['最低分', '入面最低']):
                    col_rename[col] = 'min_entry_score'
                elif any(k in col_str for k in ['最高分', '入面最高']):
                    col_rename[col] = 'max_entry_score'
                elif any(k in col_str for k in ['进面人数', '面试人数']):
                    col_rename[col] = 'entry_count'
                elif any(k in col_str for k in ['学历']):
                    col_rename[col] = 'education_req'
                elif any(k in col_str for k in ['专业']):
                    col_rename[col] = 'major_req'
                elif any(k in col_str for k in ['岗位类别', '类别']):
                    col_rename[col] = 'category'

            df = df.rename(columns=col_rename)

            for _, row in df.iterrows():
                # 事业编类别信息记录在 other_req
                category = str(row.get('category', '')).strip() if pd.notna(row.get('category')) else ''
                other_req = f'类别: {category}' if category else None

                record = {
                    'province': province,
                    'city': str(row.get('city', province)).strip() if pd.notna(row.get('city')) else province,
                    'year': year,
                    'exam_type': '事业编',
                    'department': str(row.get('department', '')).strip() if pd.notna(row.get('department')) else '',
                    'position_name': str(row.get('position_name', '')).strip() if pd.notna(row.get('position_name')) else '',
                    'position_code': str(row.get('position_code', '')).strip() if pd.notna(row.get('position_code')) else None,
                    'recruit_count': int(row['recruit_count']) if 'recruit_count' in row.index and pd.notna(row.get('recruit_count')) else None,
                    'education_req': str(row.get('education_req', '')).strip() if pd.notna(row.get('education_req')) else None,
                    'major_req': str(row.get('major_req', '')).strip() if pd.notna(row.get('major_req')) else None,
                    'other_req': other_req,
                    'min_entry_score': float(row['min_entry_score']) if 'min_entry_score' in row.index and pd.notna(row.get('min_entry_score')) else None,
                    'max_entry_score': float(row['max_entry_score']) if 'max_entry_score' in row.index and pd.notna(row.get('max_entry_score')) else None,
                    'entry_count': int(row['entry_count']) if 'entry_count' in row.index and pd.notna(row.get('entry_count')) else None,
                    'source_url': url,
                }

                if not record['position_name'] or (record['min_entry_score'] is None and record['max_entry_score'] is None):
                    continue

                results.append(record)

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

            # 事业编类别记录在 other_req
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
    scraper = ShiyebianScraper()
    data = scraper.scrape(province='江苏', year=2024)
    print(f'共获取 {len(data)} 条事业编数据')
    for row in data[:5]:
        print(f"  {row['city']} {row['department']} {row['position_name']} "
              f"分数: {row['min_entry_score']}-{row['max_entry_score']}")
