"""
一次性脚本：探测华图 apis.huatu.com API 端点行为
用于在开发 huatu_api_scraper.py 前验证 API 可用性和参数结构

发现的 API（来自 /z/2024skfscx/js/index.js）：
  - POST https://apis.huatu.com/api/shengkao/get_distinct
    参数: zwk_year, field (zwk_sheng/zwk_diqu/zwk_bumen/zwk_zwdm), [zwk_sheng], [zwk_diqu], [zwk_bumen]
    作用: 级联下拉框数据
  - POST https://apis.huatu.com/api/shengkao/fs_list
    参数: zwk_year, zwk_sheng, zwk_zwlx, page, [zwk_diqu], [zwk_bumen], [zwk_zwdm]
    作用: 批量分数线列表
  - POST https://apis.huatu.com/api/shengkao/get_result
    参数: zwk_year, zwk_sheng, zwk_diqu, zwk_bumen, zwk_zwdm
    作用: 单岗位精确查询

字段含义（从 JS 推断）：
  zwk_year   = 年份（2022/2023/2024）
  zwk_sheng  = 省份（如 "山东"）
  zwk_diqu   = 地区/城市
  zwk_bumen  = 单位/部门
  zwk_zwdm   = 岗位代码
  zwk_zw     = 岗位名称
  zwk_zdf    = 最低分
  zwk_zgf    = 最高分
  zwk_xl     = 学历要求
  zwk_zkrs   = 招考人数
  zwk_bkrs   = 笔试人数
  zwk_zwlx   = 职位类型（如 "全国"）
"""

import requests
import json
import time

BASE_URL = 'https://apis.huatu.com'
HEADERS = {
    'User-Agent': 'ExamPrepApp/1.0 (exam-entry-scores-data-collector; educational-use)',
    'Content-Type': 'application/x-www-form-urlencoded',
    'Referer': 'https://www.huatu.com/z/2024skfscx/',
    'Origin': 'https://www.huatu.com',
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}

TARGET_PROVINCES = ['江苏', '浙江', '上海', '山东']
TARGET_YEARS = [2022, 2023, 2024]


def post(endpoint, data):
    time.sleep(2)
    resp = requests.post(f'{BASE_URL}{endpoint}', data=data, headers=HEADERS, timeout=15)
    return resp.json() if resp.status_code == 200 else {'code': resp.status_code, 'error': resp.text[:200]}


def test_get_distinct():
    print('=== 测试 get_distinct: 获取省份列表 ===')
    for year in TARGET_YEARS:
        result = post('/api/shengkao/get_distinct', {'zwk_year': year, 'field': 'zwk_sheng'})
        print(f'  {year}年省份: code={result.get("code")}, data={result.get("data", [])[:10]}')

    print()
    print('=== 测试 get_distinct: 获取城市列表（山东 2024）===')
    result = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_diqu', 'zwk_sheng': '山东'})
    print(f'  山东2024城市: code={result.get("code")}, data={result.get("data", [])}')

    return result


def test_fs_list():
    print()
    print('=== 测试 fs_list: 批量获取（山东 2024）===')
    result = post('/api/shengkao/fs_list', {
        'zwk_year': 2024,
        'zwk_sheng': '山东',
        'zwk_zwlx': '全国',
        'page': 1,
    })
    print(f'  状态: code={result.get("code")}')
    data = result.get('data', [])
    print(f'  记录数: {len(data)}')
    if data:
        print(f'  第一条: {json.dumps(data[0], ensure_ascii=False)}')
        print(f'  所有字段: {list(data[0].keys())}')
    print(f'  完整响应键: {list(result.keys())}')
    return result


def test_fs_list_provinces():
    print()
    print('=== 测试 fs_list: 各省份 2024 ===')
    for prov in TARGET_PROVINCES:
        result = post('/api/shengkao/fs_list', {
            'zwk_year': 2024,
            'zwk_sheng': prov,
            'zwk_zwlx': '全国',
            'page': 1,
        })
        data = result.get('data', [])
        print(f'  {prov} 2024: code={result.get("code")}, 记录数={len(data)}')


def test_pagination():
    print()
    print('=== 测试分页（山东 2024）===')
    for page in [1, 2, 3]:
        result = post('/api/shengkao/fs_list', {
            'zwk_year': 2024,
            'zwk_sheng': '山东',
            'zwk_zwlx': '全国',
            'page': page,
        })
        data = result.get('data', [])
        print(f'  页 {page}: code={result.get("code")}, 记录数={len(data)}')
        if not data:
            break


if __name__ == '__main__':
    print('华图 API 探测脚本')
    print('Base URL:', BASE_URL)
    print()

    test_get_distinct()
    test_fs_list()
    test_fs_list_provinces()
    test_pagination()

    print()
    print('探测完成')
