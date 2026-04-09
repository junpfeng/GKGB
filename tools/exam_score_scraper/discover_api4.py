"""
华图 API 深度探测 - 第四轮
理解 get_result 数据结构，找分数字段
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

def post(endpoint, data, delay=2):
    time.sleep(delay)
    resp = requests.post(f'{BASE_URL}{endpoint}', data=data, headers=HEADERS, timeout=15)
    try:
        return resp.json()
    except Exception:
        return {'error': resp.text[:500]}

# 遍历山东营口的各单位，找有数据的 get_result
print('=== 山东营口各单位的岗位代码 + get_result ===')
r = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_bumen', 'zwk_sheng': '山东', 'zwk_diqu': '营口'})
units = r.get('data', [])
print(f'营口单位数: {len(units)}')

found_data = False
for unit in units[:5]:
    r2 = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_zwdm', 'zwk_sheng': '山东', 'zwk_diqu': '营口', 'zwk_bumen': unit})
    codes = r2.get('data', [])
    for code in codes[:2]:
        r3 = post('/api/shengkao/get_result', {
            'zwk_year': 2024, 'zwk_sheng': '山东',
            'zwk_diqu': '营口', 'zwk_bumen': unit, 'zwk_zwdm': code
        })
        data = r3.get('data', [])
        if data:
            print(f'  有数据! 单位={unit}, 代码={code}')
            print(f'  字段: {list(data[0].keys())}')
            print(f'  记录: {json.dumps(data[0], ensure_ascii=False)}')
            found_data = True
            break
    if found_data:
        break

if not found_data:
    print('营口无数据，尝试济南...')
    r = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_bumen', 'zwk_sheng': '山东', 'zwk_diqu': '济南'})
    units = r.get('data', [])
    print(f'济南单位数: {len(units)}')

    for unit in units[:3]:
        r2 = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_zwdm', 'zwk_sheng': '山东', 'zwk_diqu': '济南', 'zwk_bumen': unit})
        codes = r2.get('data', [])
        for code in codes[:2]:
            r3 = post('/api/shengkao/get_result', {
                'zwk_year': 2024, 'zwk_sheng': '山东',
                'zwk_diqu': '济南', 'zwk_bumen': unit, 'zwk_zwdm': code
            })
            data = r3.get('data', [])
            if data:
                print(f'  有数据! 单位={unit}, 代码={code}')
                print(f'  字段: {list(data[0].keys())}')
                print(f'  记录: {json.dumps(data[0], ensure_ascii=False)}')
                found_data = True
                break
        if found_data:
            break

# 换策略：不依赖get_result，改用get_distinct遍历zwk_zwdm
# 获取完整岗位代码列表后，改用 fs_list 按单位查询
print()
print('=== 测试 fs_list 按单位查询（无需 zwk_zwdm）===')
r = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_bumen', 'zwk_sheng': '山东', 'zwk_diqu': '济南'})
units = r.get('data', [])
if units:
    unit = units[0]
    r2 = post('/api/shengkao/fs_list', {
        'zwk_year': 2024, 'zwk_sheng': '山东',
        'zwk_zwlx': '全国', 'page': 1,
        'zwk_diqu': '济南', 'zwk_bumen': unit
    })
    print(f'  按单位 fs_list: code={r2.get("code")}, data len={len(r2.get("data", []))}, extra={r2.get("extra")}')

# 测试按城市查询 fs_list
print()
print('=== 测试 fs_list 按城市查询 ===')
r = post('/api/shengkao/fs_list', {
    'zwk_year': 2024, 'zwk_sheng': '山东',
    'zwk_zwlx': '全国', 'page': 1,
    'zwk_diqu': '济南'
})
print(f'  按城市济南 fs_list: code={r.get("code")}, data len={len(r.get("data", []))}, extra={r.get("extra")}')

print()
print('探测完成')
