"""
国考进面分数线爬取

数据源（已验证可用，2025-04）：
  1. eoffcn.com 按地区汇总页  — 31省份 + 进面人数 + 最低进面分（2024）
  2. eoffcn.com 按部门汇总页  — 金融监管总局等部门最低/最高分（2024）
  3. eoffcn.com TOP50 页      — 竞争最激烈 50 个职位代码 + 最低分（2024）
  4. gwy.com 历年国考汇总页   — 31省份 min/max（2023 历史数据）

robots.txt 检查结果：
  - www.eoffcn.com：允许
  - m.gwy.com：允许
  - www.chinagwy.org：禁止（/files/ 路径），不采集
"""

import re
import logging
from typing import Optional

from bs4 import BeautifulSoup

from scraper_base import ScraperBase

logger = logging.getLogger(__name__)

# 只保留这四个省份的数据
TARGET_PROVINCES = {'江苏', '浙江', '上海', '山东'}

# 省份名称规范化（页面中的简称 → 标准名）
PROVINCE_ABBR = {
    '苏': '江苏', '浙': '浙江', '沪': '上海', '鲁': '山东',
    '江苏': '江苏', '浙江': '浙江', '上海': '上海', '山东': '山东',
}


class GuokaoScraper(ScraperBase):
    """国考进面分数线爬取"""

    # eoffcn.com 国考分数线专题页（已验证 2025-04）
    EOFFCN_URLS = {
        # 按地区汇总：地区 + 进面人数 + 最低进面分
        'by_region_2024': 'https://www.eoffcn.com/kszx/detail/1270019.html',
        # 金融监管总局等部门：部门 + 进面人数 + 最低分 + 最高分
        'by_dept_2024': 'https://www.eoffcn.com/kszx/detail/1270012.html',
        # TOP50 竞争岗位：录用机关 + 司局 + 职位 + 职位代码 + 最低分
        'top50_2024': 'https://www.eoffcn.com/kszx/detail/1270027.html',
    }

    # gwy.com 上岸鸭历年汇总（2023 数据）
    GWY_COM_URLS = {
        2023: 'https://m.gwy.com/gjgwy/347874.html',
    }

    def scrape(self, year: Optional[int] = None) -> list[dict]:
        """
        爬取国考进面分数线数据

        Args:
            year: 指定年份，None 表示爬取所有可用年份
        Returns:
            标准化数据行列表（仅保留江苏/浙江/上海/山东）
        """
        results = []

        # 2024 年数据：eoffcn.com
        if year is None or year == 2024:
            data = self._scrape_eoffcn_2024()
            results.extend(data)
            logger.info(f'eoffcn 2024国考数据: {len(data)} 条')

        # 2023 年历史数据：gwy.com
        if year is None or year == 2023:
            data = self._scrape_gwy_com(self.GWY_COM_URLS[2023], 2023)
            results.extend(data)
            logger.info(f'gwy.com 2023国考数据: {len(data)} 条')

        # 过滤：只保留目标省份
        results = [r for r in results if r.get('province') in TARGET_PROVINCES]
        logger.info(f'国考数据（过滤后）: {len(results)} 条')
        return results

    # -------------------------------------------------------------------------
    # eoffcn.com 数据采集（2024）
    # -------------------------------------------------------------------------

    def _scrape_eoffcn_2024(self) -> list[dict]:
        """从 eoffcn.com 三个专题页采集 2024 年国考数据"""
        results = []

        # 1. 按地区汇总（省份级别）
        region_data = self._scrape_eoffcn_by_region(
            self.EOFFCN_URLS['by_region_2024'], 2024
        )
        results.extend(region_data)
        logger.info(f'eoffcn 按地区: {len(region_data)} 条')

        # 2. 按部门（含最低/最高分）
        dept_data = self._scrape_eoffcn_by_dept(
            self.EOFFCN_URLS['by_dept_2024'], 2024
        )
        results.extend(dept_data)
        logger.info(f'eoffcn 按部门: {len(dept_data)} 条')

        # 3. TOP50 竞争岗位（含职位代码）
        top50_data = self._scrape_eoffcn_top50(
            self.EOFFCN_URLS['top50_2024'], 2024
        )
        results.extend(top50_data)
        logger.info(f'eoffcn TOP50: {len(top50_data)} 条')

        return results

    def _scrape_eoffcn_by_region(self, url: str, year: int) -> list[dict]:
        """
        解析 eoffcn 按地区汇总页
        表头：地区 | 进面人数 | 最低进面分数
        """
        resp = self.fetch(url)
        if resp is None:
            return []

        resp.encoding = 'utf-8'
        soup = BeautifulSoup(resp.text, 'lxml')
        tables = soup.find_all('table')
        results = []

        for table in tables:
            rows = table.find_all('tr')
            if len(rows) < 2:
                continue

            headers = [th.get_text(strip=True) for th in rows[0].find_all(['th', 'td'])]
            # 识别：地区 + 最低分（必须有）
            if not any('地区' in h or '省' in h for h in headers):
                continue
            if not any('最低' in h or '分数' in h for h in headers):
                continue

            # 找各列位置
            region_idx, entry_count_idx, min_score_idx = None, None, None
            for i, h in enumerate(headers):
                if '地区' in h or '省份' in h:
                    region_idx = i
                elif '进面人数' in h or '人数' in h:
                    entry_count_idx = i
                elif '最低' in h or '分数' in h:
                    min_score_idx = i

            if region_idx is None or min_score_idx is None:
                continue

            for row in rows[1:]:
                cells = [td.get_text(strip=True) for td in row.find_all('td')]
                if len(cells) <= max(filter(lambda x: x is not None,
                                           [region_idx, min_score_idx])):
                    continue

                province_raw = cells[region_idx].strip()
                province = self._normalize_province(province_raw)
                if not province:
                    continue

                min_score = self._parse_score(cells[min_score_idx])
                if min_score is None:
                    continue

                entry_count = None
                if entry_count_idx is not None and entry_count_idx < len(cells):
                    entry_count = self._parse_int(cells[entry_count_idx])

                results.append({
                    'province': province,
                    'city': province,
                    'year': year,
                    'exam_type': '国考',
                    'department': '国考汇总',
                    'position_name': f'{province}考区综合',
                    'position_code': None,
                    'recruit_count': None,
                    'education_req': None,
                    'major_req': None,
                    'min_entry_score': min_score,
                    'max_entry_score': None,
                    'entry_count': entry_count,
                    'source_url': url,
                })

        return results

    def _scrape_eoffcn_by_dept(self, url: str, year: int) -> list[dict]:
        """
        解析 eoffcn 按部门汇总页
        表头：部门/招录机关 | 进面人数 | 最低进面分(最低值) | 最低进面分(最高值)
        """
        resp = self.fetch(url)
        if resp is None:
            return []

        resp.encoding = 'utf-8'
        soup = BeautifulSoup(resp.text, 'lxml')
        tables = soup.find_all('table')
        results = []

        for table in tables:
            rows = table.find_all('tr')
            if len(rows) < 2:
                continue

            headers = [th.get_text(strip=True) for th in rows[0].find_all(['th', 'td'])]
            # 识别：部门 + 分数（必须有）
            if not any('部门' in h or '机关' in h or '单位' in h for h in headers):
                continue
            if not any('最低' in h or '分' in h for h in headers):
                continue

            dept_idx, entry_count_idx, min_score_idx, max_score_idx = None, None, None, None
            for i, h in enumerate(headers):
                h_clean = h.replace(' ', '')
                if any(k in h_clean for k in ['部门', '机关', '单位']):
                    dept_idx = i
                elif '进面人数' in h_clean or ('人数' in h_clean and '进面' in h_clean):
                    entry_count_idx = i
                elif '最低' in h_clean and '最高' not in h_clean:
                    min_score_idx = i
                elif '最高' in h_clean:
                    max_score_idx = i
                elif '最低' not in h_clean and '最高' not in h_clean and '分' in h_clean:
                    min_score_idx = i

            if dept_idx is None or min_score_idx is None:
                continue

            for row in rows[1:]:
                cells = [td.get_text(strip=True) for td in row.find_all('td')]
                if not cells or dept_idx >= len(cells):
                    continue

                department = cells[dept_idx].strip()
                if not department:
                    continue

                min_score = self._parse_score(cells[min_score_idx]) if min_score_idx < len(cells) else None
                max_score = self._parse_score(cells[max_score_idx]) if max_score_idx is not None and max_score_idx < len(cells) else None

                if min_score is None and max_score is None:
                    continue

                entry_count = None
                if entry_count_idx is not None and entry_count_idx < len(cells):
                    entry_count = self._parse_int(cells[entry_count_idx])

                results.append({
                    'province': '全国',
                    'city': '全国',
                    'year': year,
                    'exam_type': '国考',
                    'department': department,
                    'position_name': f'{department}综合',
                    'position_code': None,
                    'recruit_count': None,
                    'education_req': None,
                    'major_req': None,
                    'min_entry_score': min_score,
                    'max_entry_score': max_score,
                    'entry_count': entry_count,
                    'source_url': url,
                })

        return results

    def _scrape_eoffcn_top50(self, url: str, year: int) -> list[dict]:
        """
        解析 eoffcn TOP50 竞争岗位页
        表头：录用机关 | 用人司局 | 拟考职位 | 职位代码 | 最低进面分数
        """
        resp = self.fetch(url)
        if resp is None:
            return []

        resp.encoding = 'utf-8'
        soup = BeautifulSoup(resp.text, 'lxml')
        tables = soup.find_all('table')
        results = []

        for table in tables:
            rows = table.find_all('tr')
            if len(rows) < 2:
                continue

            headers = [th.get_text(strip=True) for th in rows[0].find_all(['th', 'td'])]
            # 识别：职位 + 分数
            if not any('职位' in h or '岗位' in h or '机关' in h for h in headers):
                continue
            if not any('分' in h for h in headers):
                continue

            dept_idx, sub_dept_idx, pos_idx, code_idx, score_idx = None, None, None, None, None
            for i, h in enumerate(headers):
                h_clean = h.replace(' ', '')
                if '录用机关' in h_clean or ('机关' in h_clean and sub_dept_idx is None):
                    dept_idx = i
                elif '用人司局' in h_clean or '司局' in h_clean:
                    sub_dept_idx = i
                elif '职位' in h_clean or '岗位' in h_clean:
                    pos_idx = i
                elif '代码' in h_clean:
                    code_idx = i
                elif '分' in h_clean:
                    score_idx = i

            if pos_idx is None or score_idx is None:
                continue

            for row in rows[1:]:
                cells = [td.get_text(strip=True) for td in row.find_all('td')]
                if not cells or pos_idx >= len(cells):
                    continue

                department = cells[dept_idx].strip() if dept_idx is not None and dept_idx < len(cells) else ''
                sub_dept = cells[sub_dept_idx].strip() if sub_dept_idx is not None and sub_dept_idx < len(cells) else ''
                position_name = cells[pos_idx].strip()
                position_code = cells[code_idx].strip() if code_idx is not None and code_idx < len(cells) else None

                if not position_name:
                    continue

                min_score = self._parse_score(cells[score_idx]) if score_idx < len(cells) else None
                if min_score is None:
                    continue

                # 从部门名推断省份（如：国家税务总局青岛市税务局 → 山东）
                province = self._infer_province_from_dept(department + sub_dept)

                full_dept = f'{department} {sub_dept}'.strip() if sub_dept else department

                results.append({
                    'province': province or '全国',
                    'city': province or '全国',
                    'year': year,
                    'exam_type': '国考',
                    'department': full_dept,
                    'position_name': position_name,
                    'position_code': position_code,
                    'recruit_count': None,
                    'education_req': None,
                    'major_req': None,
                    'min_entry_score': min_score,
                    'max_entry_score': None,
                    'entry_count': None,
                    'source_url': url,
                })

        return results

    # -------------------------------------------------------------------------
    # gwy.com 历史数据（2023）
    # -------------------------------------------------------------------------

    def _scrape_gwy_com(self, url: str, year: int) -> list[dict]:
        """
        从 gwy.com 解析国考历年分数线 HTML 表格
        表头：地区 | 进面人数 | 最低分 | 最高分
        """
        resp = self.fetch(url)
        if resp is None:
            return []

        resp.encoding = resp.apparent_encoding
        soup = BeautifulSoup(resp.text, 'lxml')
        results = []

        tables = soup.find_all('table')
        for table in tables:
            rows = table.find_all('tr')
            if len(rows) < 2:
                continue

            headers = [th.get_text(strip=True) for th in rows[0].find_all(['th', 'td'])]
            # 识别：地区 + 分数
            if not any('地区' in h or '省' in h for h in headers):
                continue

            region_idx, entry_count_idx, min_score_idx, max_score_idx = None, None, None, None
            score_col_indices = []
            for i, h in enumerate(headers):
                h_clean = h.replace(' ', '')
                if '地区' in h_clean or '省份' in h_clean:
                    region_idx = i
                elif '进面人数' in h_clean or '人数' in h_clean:
                    entry_count_idx = i
                elif '最高' in h_clean and '最低' not in h_clean:
                    max_score_idx = i
                elif '最低' in h_clean and '最高' not in h_clean:
                    min_score_idx = i
                elif '分' in h_clean:
                    score_col_indices.append(i)

            # gwy.com 特殊格式：
            #   列标题均含"最低"："最低进面分数(最低值)" 和 "最低进面分数(最高值)"
            #   实际含义：(最低值)=单科门槛分 (~42-50)，(最高值)=最低进面总分 (~140+)
            #   我们只取"最高值"列作为最低进面分
            all_score_cols = [i for i, h in enumerate(headers) if '分' in h or '最低' in h or '最高' in h]
            if min_score_idx is None and max_score_idx is None and len(all_score_cols) >= 2:
                # 两列均含分数关键词：取数值较大的为进面总分（min_entry_score）
                # 方案：直接用最后一个分数列作为 min_entry_score
                min_score_idx = all_score_cols[-1]
            elif min_score_idx is not None and max_score_idx is None:
                # 只找到一个"最低"列，检查是否还有第二个分数列（gwy格式）
                remaining = [i for i in all_score_cols if i != min_score_idx]
                if remaining:
                    # 两列都是分数：选数值较大的那列作为进面总分
                    # 无法提前判断，约定：取索引靠后的为进面总分
                    if remaining[-1] > min_score_idx:
                        min_score_idx = remaining[-1]  # 用较大索引的列

            if region_idx is None or min_score_idx is None:
                continue

            for row in rows[1:]:
                cells = [td.get_text(strip=True) for td in row.find_all('td')]
                if len(cells) <= min_score_idx:
                    continue

                province_raw = cells[region_idx].strip()
                province = self._normalize_province(province_raw)
                if not province:
                    continue

                min_score = self._parse_score(cells[min_score_idx])
                if min_score is None:
                    continue

                max_score = self._parse_score(cells[max_score_idx]) if max_score_idx is not None and max_score_idx < len(cells) else None
                entry_count = self._parse_int(cells[entry_count_idx]) if entry_count_idx is not None and entry_count_idx < len(cells) else None

                results.append({
                    'province': province,
                    'city': province,
                    'year': year,
                    'exam_type': '国考',
                    'department': '国考汇总',
                    'position_name': f'{province}考区综合',
                    'position_code': None,
                    'recruit_count': None,
                    'education_req': None,
                    'major_req': None,
                    'min_entry_score': min_score,
                    'max_entry_score': max_score,
                    'entry_count': entry_count,
                    'source_url': url,
                })

        return results

    # -------------------------------------------------------------------------
    # 辅助方法
    # -------------------------------------------------------------------------

    def _normalize_province(self, text: str) -> Optional[str]:
        """将页面中的省份名/简称标准化，返回目标省份或 None"""
        text = text.strip()
        # 直接映射
        if text in PROVINCE_ABBR:
            return PROVINCE_ABBR[text]
        # 模糊匹配
        for key, val in PROVINCE_ABBR.items():
            if key in text:
                return val
        return None

    def _infer_province_from_dept(self, dept_name: str) -> Optional[str]:
        """从部门名称推断所在省份（仅目标省份）"""
        province_keywords = {
            '江苏': ['江苏', '南京', '苏州', '无锡', '常州', '南通', '连云港', '淮安', '盐城', '扬州', '镇江', '泰州', '宿迁'],
            '浙江': ['浙江', '杭州', '宁波', '温州', '嘉兴', '湖州', '绍兴', '金华', '衢州', '舟山', '台州', '丽水'],
            '上海': ['上海'],
            '山东': ['山东', '济南', '青岛', '烟台', '潍坊', '济宁', '泰安', '威海', '日照', '临沂', '德州', '聊城', '滨州', '菏泽', '淄博'],
        }
        for province, keywords in province_keywords.items():
            for kw in keywords:
                if kw in dept_name:
                    return province
        return None

    @staticmethod
    def _parse_score(text: str) -> Optional[float]:
        """从文本中提取分数"""
        if not text:
            return None
        text = text.strip()
        if text in ('-', '—', '/', ''):
            return None
        match = re.search(r'(\d+\.?\d*)', text)
        if match:
            return float(match.group(1))
        return None

    @staticmethod
    def _parse_int(text: str) -> Optional[int]:
        """从文本中提取整数"""
        if not text:
            return None
        text = text.strip()
        match = re.search(r'(\d+)', text)
        if match:
            return int(match.group(1))
        return None


if __name__ == '__main__':
    import logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

    scraper = GuokaoScraper()
    data = scraper.scrape(year=2024)
    print(f'共获取 {len(data)} 条国考数据')
    for row in data[:10]:
        print(f"  {row['province']} {row['department']} {row['position_name']} "
              f"分数: {row['min_entry_score']}-{row['max_entry_score']}")
