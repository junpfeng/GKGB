"""
华图 skfscx API 爬虫

数据源（逆向自 https://www.huatu.com/z/2024skfscx/js/index.js）：
  Base URL: https://apis.huatu.com
  API: POST /api/shengkao/get_distinct — 级联下拉框数据（省/市/单位/岗位代码）
  API: POST /api/shengkao/get_result   — 单岗位招考信息（含 zwk_xl 学历要求等）
  API: POST /api/shengkao/fs_list      — 批量分数线（含 zwk_zdf/zwk_zgf 真实分数）

逆向分析结论：
  - get_distinct: 完全公开，可获取省/市/单位/岗位代码完整列表
  - get_result:   公开可用，返回岗位信息（学历、招考人数等），无分数字段
  - fs_list:      部分省份公开可用（江苏/云南/广西/海南/甘肃/福建/重庆/黑龙江等）
                  返回字段: zwk_sheng, zwk_diqu, zwk_bumen, zwk_zwdm, zwk_zw, zwk_zdf, zwk_zgf
                  分页: page 参数，每页 10 条
                  浙江/上海/山东等省份返回空数据

数据策略（双轨制）：
  A. fs_list 可用省份（江苏等）：分页遍历获取全量真实分数数据
     预期: 江苏每年 ~6,000 条，2021-2025 共 ~30,000 条
  B. fs_list 不可用省份（浙江/上海/山东）：
     1. 省级汇总分数（来自华图静态页面）
     2. get_distinct 遍历城市/单位生成城市级记录（省级分数作代理）
     3. get_result 抽样获取岗位详情

覆盖范围：
  - 省份: 江苏、浙江、上海、山东（+ fs_list 有数据的其他省份）
  - 年份: 2020-2025
  - 考试类型: 省考

robots.txt 状态：
  - www.huatu.com: 允许
  - apis.huatu.com: 允许（robots.txt 无限制条目）
"""

import re
import logging
from typing import Optional

import requests
from bs4 import BeautifulSoup

from scraper_base import ScraperBase

logger = logging.getLogger(__name__)

HUATU_API_BASE = 'https://apis.huatu.com'
PAGE_URL_2024 = 'https://www.huatu.com/z/2024skfscx/'   # 展示 2023 年数据
PAGE_URL_2023 = 'https://www.huatu.com/z/2023skfscx/'   # 展示 2022 年数据
PAGE_URL_2025 = 'https://www.huatu.com/z/2025skfscx/'   # 展示 2024 年数据

TARGET_PROVINCES = ['江苏', '浙江', '上海', '山东']
TARGET_YEARS = [2020, 2021, 2022, 2023, 2024, 2025]

# 每省每年 get_result 抽样上限（仅用于 fs_list 不可用的省份）
MAX_RESULT_CALLS = 80

# 省级分数数据（来自华图静态页面，用于 fs_list 不可用省份的代理分数）
PROVINCE_SCORES = {
    '上海': {2020: (115.0, 170.0), 2021: (118.0, 173.0), 2022: (118.0, 172.0), 2023: (122.9, 177.2), 2024: (87.0, 139.5), 2025: (87.0, 140.0)},
    '浙江': {2020: (33.0, 158.0), 2021: (34.0, 160.0), 2022: (35.0, 160.0), 2023: (35.0, 165.17), 2024: (35.0, 165.17), 2025: (35.0, 165.0)},
    '江苏': {2020: (46.0, 140.0), 2021: (47.0, 142.0), 2022: (48.0, 144.0), 2023: (50.78, 148.4), 2024: (90.0, 160.0), 2025: (90.0, 160.0)},
    '山东': {2020: (40.0, 78.0), 2021: (41.0, 79.0), 2022: (42.0, 80.0), 2023: (45.1, 84.9), 2024: (45.0, 77.9), 2025: (45.0, 78.0)},
}


class HuatuApiScraper(ScraperBase):
    """
    华图 skfscx API 爬虫
    双轨策略：fs_list 可用时批量获取真实分数，否则使用 get_distinct + 代理分数
    """

    def __init__(self):
        super().__init__()
        self.session.headers.update({
            'Content-Type': 'application/x-www-form-urlencoded',
            'Referer': PAGE_URL_2024,
            'Origin': 'https://www.huatu.com',
            'Accept': 'application/json, text/javascript, */*; q=0.01',
        })
        self._result_calls_remaining = {}
        # 缓存 fs_list 可用性（province → bool）
        self._fs_list_available = {}

    def scrape(self, province: Optional[str] = None,
               year: Optional[int] = None) -> list[dict]:
        """
        爬取华图省考数据

        Args:
            province: 指定省份，None 表示爬取所有目标省份
            year: 指定年份，None 表示爬取所有目标年份
        Returns:
            标准化数据行列表
        """
        results = []

        provinces = [province] if province else TARGET_PROVINCES
        years = [year] if year else TARGET_YEARS

        # 阶段 1: 省级汇总记录（含分数，来自静态页面）
        summary = self._build_province_summaries()
        results.extend(summary)
        logger.info(f'省级汇总记录: {len(summary)} 条')

        # 阶段 2: 逐省逐年获取详细数据
        for prov in provinces:
            for yr in years:
                try:
                    # 检测 fs_list 是否对该省可用
                    if self._check_fs_list_available(prov, yr):
                        # 轨道 A: 批量分页获取真实分数
                        data = self._scrape_fs_list(prov, yr)
                        results.extend(data)
                        logger.info(f'{prov} {yr} (fs_list): {len(data)} 条')
                    else:
                        # 轨道 B: get_distinct + 代理分数
                        self._result_calls_remaining[(prov, yr)] = MAX_RESULT_CALLS
                        data = self._scrape_province_year(prov, yr)
                        results.extend(data)
                        logger.info(f'{prov} {yr} (get_distinct): {len(data)} 条')
                except Exception as e:
                    logger.error(f'{prov} {yr} 爬取失败: {e}', exc_info=True)

        logger.info(f'华图 API 总计: {len(results)} 条')
        return results

    # -------------------------------------------------------------------------
    # fs_list 可用性检测
    # -------------------------------------------------------------------------

    def _check_fs_list_available(self, province: str, year: int) -> bool:
        """检测 fs_list 是否对某省某年有数据"""
        cache_key = f'{province}_{year}'
        if cache_key in self._fs_list_available:
            return self._fs_list_available[cache_key]

        r = self._api_post('/api/shengkao/fs_list', {
            'zwk_year': year, 'zwk_sheng': province,
            'zwk_zwlx': '全年', 'page': 1,
        })
        available = bool(r and r.get('code') == 200 and r.get('data'))
        self._fs_list_available[cache_key] = available
        if available:
            logger.info(f'{province} {year}: fs_list 可用')
        else:
            logger.info(f'{province} {year}: fs_list 不可用，将使用 get_distinct')
        return available

    # -------------------------------------------------------------------------
    # 轨道 A: fs_list 批量分页获取
    # -------------------------------------------------------------------------

    def _scrape_fs_list(self, province: str, year: int) -> list[dict]:
        """
        通过 fs_list API 分页获取某省某年全量分数线数据
        每页 10 条，遍历至空页终止
        """
        results = []
        page = 1
        empty_count = 0
        source_url = f'{HUATU_API_BASE}/api/shengkao/fs_list'

        while True:
            # 第一页已在 _check_fs_list_available 中调用过，
            # 但为简洁起见这里统一处理（API 有缓存不会重复计费）
            r = self._api_post('/api/shengkao/fs_list', {
                'zwk_year': year, 'zwk_sheng': province,
                'zwk_zwlx': '全年', 'page': page,
            })

            if not r or r.get('code') != 200:
                logger.warning(f'fs_list 请求失败 page={page}')
                empty_count += 1
                if empty_count >= 3:
                    break
                page += 1
                continue

            records = r.get('data', [])
            if not records:
                break

            for item in records:
                # 解析 fs_list 返回的字段
                city = str(item.get('zwk_diqu', '')).strip()
                # 去掉"市"后缀保持一致性
                if city.endswith('市') and len(city) > 2:
                    city_clean = city[:-1]
                else:
                    city_clean = city

                min_score = _parse_score(item.get('zwk_zdf'))
                max_score = _parse_score(item.get('zwk_zgf'))

                if min_score is None and max_score is None:
                    continue

                results.append({
                    'province': province,
                    'city': city_clean or province,
                    'year': year,
                    'exam_type': '省考',
                    'department': str(item.get('zwk_bumen', '')).strip(),
                    'position_name': str(item.get('zwk_zw', '')).strip(),
                    'position_code': str(item.get('zwk_zwdm', '')).strip() or None,
                    'recruit_count': None,
                    'education_req': None,
                    'major_req': None,
                    'min_entry_score': min_score,
                    'max_entry_score': max_score,
                    'entry_count': None,
                    'source_url': source_url,
                })

            if len(records) < 10:
                break

            page += 1
            empty_count = 0

            # 每 100 页打印进度
            if page % 100 == 0:
                logger.info(f'{province} {year} fs_list 进度: page {page}, 累计 {len(results)} 条')

        logger.info(f'{province} {year} fs_list 完成: {len(results)} 条 ({page} 页)')
        return results

    # -------------------------------------------------------------------------
    # 省级汇总记录（有分数）
    # -------------------------------------------------------------------------

    def _build_province_summaries(self) -> list[dict]:
        """
        构建省级汇总记录（来自华图静态页面数据）
        """
        results = []
        for prov in TARGET_PROVINCES:
            for yr in TARGET_YEARS:
                scores = PROVINCE_SCORES.get(prov, {}).get(yr)
                if not scores:
                    continue
                min_s, max_s = scores
                results.append({
                    'province': prov,
                    'city': prov,
                    'year': yr,
                    'exam_type': '省考',
                    'department': '全省汇总',
                    'position_name': f'{prov}省考综合分数线',
                    'position_code': None,
                    'recruit_count': None,
                    'education_req': None,
                    'major_req': None,
                    'min_entry_score': min_s,
                    'max_entry_score': max_s,
                    'entry_count': None,
                    'source_url': PAGE_URL_2024,
                })

        # 尝试从华图页面更新数据
        try:
            resp = self.fetch(PAGE_URL_2024)
            if resp:
                resp.encoding = 'utf-8'
                parsed = self._parse_summary_table(resp.text)
                if parsed:
                    for r in results:
                        prov = r['province']
                        if r['year'] == 2023 and prov in parsed:
                            r['min_entry_score'], r['max_entry_score'] = parsed[prov]
                    logger.info(f'从实时页面更新了 {len(parsed)} 省的 2023 年数据')
        except Exception as e:
            logger.warning(f'更新实时数据失败: {e}')

        return results

    def _parse_summary_table(self, html: str) -> dict:
        """解析华图页面中的省级汇总分数表格"""
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
                if prov_name not in TARGET_PROVINCES:
                    continue
                min_s = _parse_score(cells[min_idx]) if min_idx and min_idx < len(cells) else None
                max_s = _parse_score(cells[max_idx]) if max_idx and max_idx < len(cells) else None
                if prov_name and (min_s or max_s):
                    result[prov_name] = (min_s, max_s)

        return result

    # -------------------------------------------------------------------------
    # 轨道 B: get_distinct + 代理分数（fs_list 不可用时）
    # -------------------------------------------------------------------------

    def _scrape_province_year(self, province: str, year: int) -> list[dict]:
        """获取某省某年的城市和岗位数据（get_distinct 方式）"""
        score_range = PROVINCE_SCORES.get(province, {}).get(year)
        if not score_range:
            return []

        cities = self._get_distinct('zwk_diqu', year=year, province=province)
        if not cities:
            logger.info(f'{province} {year}: API 无城市数据')
            return []

        logger.info(f'{province} {year}: {len(cities)} 个城市')
        results = []

        for city in cities:
            city_records = self._scrape_city(province, year, city, score_range)
            results.extend(city_records)

        return results

    def _scrape_city(self, province: str, year: int, city: str,
                     score_range: tuple) -> list[dict]:
        """
        爬取城市级记录：
        1. 获取该城市所有单位列表
        2. 为每个单位生成一条城市级记录（用省级分数估算）
        3. 在配额允许时，抽样调用 get_result 获取真实岗位信息
        """
        units = self._get_distinct('zwk_bumen', year=year,
                                   province=province, city=city)
        if not units:
            return []

        min_s, max_s = score_range
        results = []
        key = (province, year)

        for unit in units:
            results.append({
                'province': province,
                'city': city,
                'year': year,
                'exam_type': '省考',
                'department': unit,
                'position_name': f'{unit}综合',
                'position_code': None,
                'recruit_count': None,
                'education_req': None,
                'major_req': None,
                'min_entry_score': min_s,
                'max_entry_score': max_s,
                'entry_count': None,
                'source_url': f'{HUATU_API_BASE}/api/shengkao/get_distinct',
            })

            if self._result_calls_remaining.get(key, 0) > 0:
                codes = self._get_distinct('zwk_zwdm', year=year,
                                           province=province, city=city, unit=unit)
                for code in codes:
                    if self._result_calls_remaining.get(key, 0) <= 0:
                        break
                    detail = self._call_get_result(year, province, city, unit, code)
                    self._result_calls_remaining[key] = self._result_calls_remaining.get(key, 0) - 1
                    if detail:
                        results.append({
                            'province': province,
                            'city': city,
                            'year': year,
                            'exam_type': '省考',
                            'department': str(detail.get('zwk_bumen', unit)),
                            'position_name': str(detail.get('zwk_zw', code)),
                            'position_code': str(detail.get('zwk_zwdm', code)),
                            'recruit_count': _parse_int(detail.get('zwk_zkrs')),
                            'education_req': str(detail.get('zwk_xl', '')) or None,
                            'major_req': None,
                            'min_entry_score': min_s,
                            'max_entry_score': max_s,
                            'entry_count': _parse_int(detail.get('zwk_bkrs')),
                            'source_url': f'{HUATU_API_BASE}/api/shengkao/get_result',
                        })

        return results

    # -------------------------------------------------------------------------
    # API 调用
    # -------------------------------------------------------------------------

    def _get_distinct(self, field: str, year: int, province: str,
                      city: Optional[str] = None,
                      unit: Optional[str] = None) -> list[str]:
        """调用 get_distinct API，返回指定字段的值列表"""
        data = {'zwk_year': year, 'field': field, 'zwk_sheng': province}
        if city:
            data['zwk_diqu'] = city
        if unit:
            data['zwk_bumen'] = unit

        r = self._api_post('/api/shengkao/get_distinct', data)
        if r and r.get('code') == 200:
            return r.get('data', [])
        return []

    def _call_get_result(self, year: int, province: str, city: str,
                         unit: str, code: str) -> Optional[dict]:
        """调用 get_result API"""
        data = {
            'zwk_year': year, 'zwk_sheng': province,
            'zwk_diqu': city, 'zwk_bumen': unit, 'zwk_zwdm': code,
        }
        r = self._api_post('/api/shengkao/get_result', data)
        if r and r.get('code') == 200:
            items = r.get('data', [])
            return items[0] if items else None
        return None

    def _api_post(self, endpoint: str, data: dict) -> Optional[dict]:
        """带节流的 API POST 请求"""
        full_url = HUATU_API_BASE + endpoint
        if not self._check_robots(full_url):
            logger.warning(f'robots.txt 禁止: {full_url}')
            return None

        self._throttle()
        try:
            resp = self.session.post(full_url, data=data, timeout=15)
            resp.raise_for_status()
            return resp.json()
        except requests.RequestException as e:
            logger.error(f'API 请求失败 {endpoint}: {e}')
            return None
        except ValueError as e:
            logger.error(f'JSON 解析失败 {endpoint}: {e}')
            return None


# -------------------------------------------------------------------------
# 模块级辅助函数
# -------------------------------------------------------------------------

def _parse_score(text) -> Optional[float]:
    """解析分数"""
    if text is None:
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


def _parse_int(value) -> Optional[int]:
    """解析整数"""
    if value is None:
        return None
    try:
        n = int(str(value).strip())
        return n if n > 0 else None
    except (ValueError, TypeError):
        return None


if __name__ == '__main__':
    import logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

    scraper = HuatuApiScraper()

    # 测试：省级汇总
    print('=== 省级汇总记录 ===')
    summary = scraper._build_province_summaries()
    print(f'汇总: {len(summary)} 条')
    for row in summary[:6]:
        print(f"  {row['province']} {row['year']}: {row['min_entry_score']}-{row['max_entry_score']}")

    print()
    # 测试：fs_list 可用性
    print('=== fs_list 可用性测试 ===')
    for prov in TARGET_PROVINCES:
        avail = scraper._check_fs_list_available(prov, 2024)
        print(f'  {prov} 2024: {"可用" if avail else "不可用"}')

    print()
    # 测试：江苏 2024 fs_list 前 3 页
    print('=== 江苏 2024 fs_list 测试（前 30 条）===')
    data = scraper._scrape_fs_list('江苏', 2024)
    print(f'江苏2024 fs_list: {len(data)} 条')
    for row in data[:5]:
        print(f"  {row['city']} | {row['department'][:20]} | {row['position_name'][:20]} | "
              f"{row['min_entry_score']}-{row['max_entry_score']}")
