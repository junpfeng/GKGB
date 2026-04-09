"""
华图 ECharts 数据提取爬虫

原始设计（Phase 4）：
  通过正则表达式提取华图各省站页面 ECharts JS 数组数据，
  产出城市级汇总分数（非岗位级）。

探测结果（2026-04）：
  - js.huatu.com, zj.huatu.com, sh.huatu.com：
    页面无 ECharts 数据，无进面分数相关内容
  - sd.huatu.com/gwy/kaoshi/fenshu/：404
  - 各省站历年文章页：大多为通知性质，无结构化图表数据
  - 华图 skfscx 页面已有静态 HTML 表格（在 HuatuApiScraper 中处理）

实际实现：
  改为从 https://www.huatu.com/z/2025skfscx/ 提取 2024 年各省汇总表格数据
  （该页包含 2024 年省考各省最高/最低进面分的静态表格）

数据说明：
  - 来源: 华图 2025skfscx 页面静态表格（2024 年数据）
  - 包含: 23 个省份的最高/最低进面分数线（省级汇总）
  - 目标省份: 江苏、浙江、上海、山东
  - 精度: 省级汇总（非岗位级，反映全省进面分布区间）

robots.txt 检查：
  - www.huatu.com: 允许
"""

import re
import logging
from typing import Optional

from bs4 import BeautifulSoup

from scraper_base import ScraperBase

logger = logging.getLogger(__name__)

# 2025skfscx 页面展示 2024 年数据
PAGE_URL_2025 = 'https://www.huatu.com/z/2025skfscx/'

# 目标省份
TARGET_PROVINCES = {'江苏', '浙江', '上海', '山东'}

# 2024 年各省汇总分数（从 2025skfscx 页面提取，作为内置备用数据）
# 来源：华图 2025skfscx 静态表格（2026-04 实测）
HARDCODED_2024_SCORES = {
    '江苏': (90.0, 160.0),
    '上海': (87.0, 139.5),
    '浙江': (23.73, 165.17),
    '山东': (45.0, 77.9),
    # 非目标省份（供参考）
    '福建': (49.75, 156.3),
    '湖南': (41.45, 74.0),
    '辽宁': (58.5, 122.5),
    '山西': (40.55, 72.1),
    '云南': (95.0, 159.0),
    '广西': (45.0, 210.15),
    '陕西': (116.0, 222.5),
    '河南': (45.0, 80.65),
    '宁夏': (65.0, 145.0),
    '青海': (38.0, 73.58),
    '新疆': (60.0, 130.0),
    '北京': (45.0, 110.0),
    '重庆': (44.31, 149.5),
    '江西': (100.8, 208.59),
    '黑龙江': (99.0, 145.0),
    '安徽': (40.0, 110.0),
    '四川': (101.5, 159.0),
    '贵州': (49.0, 82.73),
    '甘肃': (32.75, 78.75),
}


class HuatuEchartsScraper(ScraperBase):
    """
    华图分数线数据提取爬虫

    原计划用于 ECharts 数据提取，实际改为从华图 2025skfscx 页面
    提取 2024 年各省汇总分数线静态表格数据。
    """

    def scrape(self, province: Optional[str] = None,
               year: Optional[int] = None) -> list[dict]:
        """
        提取华图页面上的省级汇总分数数据

        Args:
            province: 指定省份，None 表示提取所有目标省份
            year: 当前仅支持 2024 年数据（2025skfscx 页面）
        Returns:
            标准化数据行列表
        """
        results = []

        # 目前仅有 2024 年数据（来自 2025skfscx 页面）
        if year is not None and year != 2024:
            logger.info(f'ECharts 爬虫仅有 2024 年数据，跳过 {year} 年')
            return []

        # 从实时页面提取，失败则用内置数据
        try:
            resp = self.fetch(PAGE_URL_2025)
            if resp:
                resp.encoding = 'utf-8'
                parsed = self._parse_2024_table(resp.text)
                if parsed:
                    logger.info(f'从 2025skfscx 页面提取到 {len(parsed)} 省数据')
                    source = parsed
                else:
                    source = HARDCODED_2024_SCORES
                    logger.info('使用内置 2024 年省级分数数据')
            else:
                source = HARDCODED_2024_SCORES
        except Exception as e:
            logger.warning(f'页面提取失败: {e}，使用内置数据')
            source = HARDCODED_2024_SCORES

        # 过滤省份
        provinces_to_use = [province] if province else list(TARGET_PROVINCES)
        for prov in provinces_to_use:
            if prov not in source:
                continue
            min_s, max_s = source[prov]
            results.append({
                'province': prov,
                'city': prov,
                'year': 2024,
                'exam_type': '省考',
                'department': '全省汇总',
                'position_name': f'{prov}2024省考进面分数线',
                'position_code': None,
                'recruit_count': None,
                'education_req': None,
                'major_req': None,
                'min_entry_score': min_s,
                'max_entry_score': max_s,
                'entry_count': None,
                'source_url': PAGE_URL_2025,
            })

        logger.info(f'ECharts 爬虫（实为 2024 汇总）: {len(results)} 条')
        return results

    def _parse_2024_table(self, html: str) -> dict:
        """
        解析 2025skfscx 页面中的 2024 年各省汇总分数表格
        返回 {省份名: (min_score, max_score)}
        """
        soup = BeautifulSoup(html, 'lxml')
        result = {}

        for table in soup.find_all('table'):
            rows = table.find_all('tr')
            if len(rows) < 3:
                continue

            headers = [th.get_text(strip=True) for th in rows[0].find_all(['th', 'td'])]
            if not any('省' in h or '地区' in h for h in headers):
                continue
            if not any('高' in h or '低' in h or '分' in h for h in headers):
                continue

            prov_idx = max_idx = min_idx = None
            for i, h in enumerate(headers):
                if '省' in h or '地区' in h:
                    prov_idx = i
                elif '最高' in h:
                    max_idx = i
                elif '最低' in h:
                    min_idx = i

            if prov_idx is None:
                continue

            for row in rows[1:]:
                cells = [td.get_text(strip=True) for td in row.find_all('td')]
                if not cells or prov_idx >= len(cells):
                    continue
                prov_name = cells[prov_idx].strip()
                min_s = _parse_score(cells[min_idx]) if min_idx and min_idx < len(cells) else None
                max_s = _parse_score(cells[max_idx]) if max_idx and max_idx < len(cells) else None
                if prov_name and (min_s or max_s):
                    result[prov_name] = (min_s or 0, max_s or 0)

        return result


def _parse_score(text) -> Optional[float]:
    """解析分数"""
    if not text:
        return None
    try:
        text = str(text).strip()
        if text in ('-', '—', '/', ''):
            return None
        m = re.search(r'(\d+\.?\d*)', text)
        if m:
            val = float(m.group(1))
            return val if 20 <= val <= 300 else None
    except (ValueError, TypeError):
        pass
    return None


if __name__ == '__main__':
    import logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

    scraper = HuatuEchartsScraper()
    data = scraper.scrape()
    print(f'共获取 {len(data)} 条省级汇总数据')
    for row in data:
        print(f"  {row['province']} {row['year']}: {row['min_entry_score']}-{row['max_entry_score']}")
