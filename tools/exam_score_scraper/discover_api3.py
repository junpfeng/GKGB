"""
华图 API 深度探测 - 第三轮
验证 get_result 是否含分数字段，并评估全量遍历的可行性
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


# 测试山东营口中医院的第一个岗位代码
test_params = {
    'zwk_year': 2024, 'zwk_sheng': '山东',
    'zwk_diqu': '营口', 'zwk_bumen': '营口市中医医院',
    'zwk_zwdm': '13705003001000001'
}

print('=== get_result 完整响应（山东 营口 中医院）===')
r = post('/api/shengkao/get_result', test_params)
print(json.dumps(r, ensure_ascii=False, indent=2))

# 检查是否有分数字段
print()
data = r.get('data', [])
if data:
    print('字段列表:', list(data[0].keys()))
    print('zwk_zdf (最低分):', data[0].get('zwk_zdf'))
    print('zwk_zgf (最高分):', data[0].get('zwk_zgf'))

# 统计山东2024的规模
print()
print('=== 山东2024数据规模评估 ===')
r = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_diqu', 'zwk_sheng': '山东'})
cities = r.get('data', [])
print(f'城市数: {len(cities)}')

r = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_zwdm', 'zwk_sheng': '山东'})
all_codes = r.get('data', [])
print(f'总岗位代码数: {len(all_codes)}')

# 评估各省规模
print()
print('=== 各省2024岗位代码数量 ===')
for prov in ['山东', '江苏', '浙江', '上海']:
    r = post('/api/shengkao/get_distinct', {'zwk_year': 2024, 'field': 'zwk_zwdm', 'zwk_sheng': prov})
    codes = r.get('data', [])
    print(f'  {prov} 2024: {len(codes)} 个岗位代码')

# 评估各年份规模（山东）
print()
print('=== 山东各年份岗位数量 ===')
for year in [2022, 2023, 2024]:
    r = post('/api/shengkao/get_distinct', {'zwk_year': year, 'field': 'zwk_zwdm', 'zwk_sheng': '山东'})
    codes = r.get('data', [])
    print(f'  山东 {year}: {len(codes)} 个岗位代码')

print()
print('探测完成')
