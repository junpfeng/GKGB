"""
华图 API 深度探测 - 第二轮
发现 fs_list 返回空 data，可能需要认证或其他参数
进一步测试 get_result 和 get_distinct 的全量遍历策略
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
    # 模拟浏览器 Cookie（localStorage 中的 is_yy_skbm 通过 cookie 模拟）
    'Cookie': 'is_yy_skbm=1',
}

def post(endpoint, data, delay=2):
    time.sleep(delay)
    resp = requests.post(f'{BASE_URL}{endpoint}', data=data, headers=HEADERS, timeout=15)
    print(f'  HTTP {resp.status_code}, Content-Type: {resp.headers.get("Content-Type", "?")}')
    try:
        return resp.json()
    except Exception:
        print(f'  响应非JSON: {resp.text[:500]}')
        return {}


print('=== 测试 get_distinct 字段遍历（山东2024）===')
for field in ['zwk_sheng', 'zwk_diqu', 'zwk_bumen', 'zwk_zwdm', 'zwk_zwlx', 'zwk_zw']:
    result = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': field, 'zwk_sheng': '山东'})
    data = result.get('data', [])
    print(f'  field={field}: {len(data)} 条, 示例: {data[:5]}')

print()
print('=== 测试 fs_list 各种参数组合 ===')

# 测试不带 zwk_zwlx 参数
result = post('/api/shengkao/fs_list', {'zwk_year': 2024, 'zwk_sheng': '山东', 'page': 1})
print(f'  无zwk_zwlx: code={result.get("code")}, data len={len(result.get("data", []))}, extra={result.get("extra")}, msg={result.get("msg")}')

# 测试 zwk_zwlx 各种值
for zwlx in ['全国', '省份', '地市', '', '1', 'all']:
    result = post('/api/shengkao/fs_list', {'zwk_year': 2024, 'zwk_sheng': '山东', 'zwk_zwlx': zwlx, 'page': 1})
    print(f'  zwk_zwlx={zwlx!r}: code={result.get("code")}, data len={len(result.get("data", []))}, msg={result.get("msg")!r}')

print()
print('=== 测试 get_result（精确查询）===')
# 先获取山东的地区列表
r = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_diqu', 'zwk_sheng': '山东'})
cities = r.get('data', [])
print(f'  山东城市: {cities}')

if cities:
    city = cities[0]
    print(f'  测试城市: {city}')

    # 获取该城市的单位列表
    r2 = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_bumen', 'zwk_sheng': '山东', 'zwk_diqu': city})
    units = r2.get('data', [])
    print(f'  {city}单位: {units[:5]}')

    if units:
        unit = units[0]
        # 获取岗位代码
        r3 = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_zwdm', 'zwk_sheng': '山东', 'zwk_diqu': city, 'zwk_bumen': unit})
        codes = r3.get('data', [])
        print(f'  {unit}岗位代码: {codes[:5]}')

        if codes:
            code = codes[0]
            # 查询具体结果
            r4 = post('/api/shengkao/get_result', {
                'zwk_year': 2024, 'zwk_sheng': '山东',
                'zwk_diqu': city, 'zwk_bumen': unit, 'zwk_zwdm': code
            })
            print(f'  get_result: code={r4.get("code")}, data={r4.get("data")}')

print()
print('=== 测试 fs_list 是否有分页逻辑（page_size 参数）===')
for extra_param in [
    {'page_size': 100}, {'limit': 100}, {'size': 100}, {'num': 100},
    {'zwk_token': ''}, {'token': ''}, {'auth': '1'}
]:
    data = {'zwk_year': 2024, 'zwk_sheng': '山东', 'zwk_zwlx': '全国', 'page': 1}
    data.update(extra_param)
    result = post('/api/shengkao/fs_list', data, delay=2)
    print(f'  extra={extra_param}: code={result.get("code")}, data len={len(result.get("data", []))}, extra_field={result.get("extra")}')

print()
print('探测完成')
