"""
华图 API 深度探测 - 第五轮
确认分数数据获取路径，检查是否有其他 API 端点
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

def get(url, delay=2):
    time.sleep(delay)
    resp = requests.get(url, headers={**HEADERS, 'Content-Type': 'text/html'}, timeout=15)
    return resp

# 1. 检查华图是否有 2024skfscx 相关的其他页面
print('=== 探索其他华图 API 端点 ===')

# 尝试直接访问 fs_list 用 GET 方法
r = requests.get('https://apis.huatu.com/api/shengkao/fs_list',
                 params={'zwk_year': 2024, 'zwk_sheng': '山东', 'zwk_zwlx': '全国', 'page': 1},
                 headers=HEADERS, timeout=15)
try:
    rj = r.json()
    print(f'GET fs_list: code={rj.get("code")}, data len={len(rj.get("data", []))}, msg={rj.get("msg")}')
except:
    print(f'GET fs_list: {r.text[:300]}')

time.sleep(2)

# 2. 尝试其他可能的分数 API 端点
print()
print('=== 尝试其他分数 API 路径 ===')
endpoints_to_try = [
    '/api/shengkao/score_list',
    '/api/shengkao/fscx_list',
    '/api/shengkao/get_score',
    '/api/shengkao/score',
    '/api/shengkao/list',
    '/api/fscx/list',
    '/api/fscx/get',
    '/api/score/list',
    '/api/shengkao/fs_list_all',
]

base_data = {'zwk_year': 2024, 'zwk_sheng': '山东', 'page': 1}
for ep in endpoints_to_try:
    r = requests.post(f'{BASE_URL}{ep}', data=base_data, headers=HEADERS, timeout=10)
    try:
        rj = r.json()
        print(f'  {ep}: code={rj.get("code")}, data={str(rj.get("data", []))[:100]}, msg={rj.get("msg")}')
    except:
        print(f'  {ep}: HTTP {r.status_code}: {r.text[:100]}')
    time.sleep(2)

# 3. 实际确认：get_result 返回的是招考信息（无分数），fs_list 才有分数但需登录
# 数据策略转变：用 get_distinct 遍历 zwk_zwdm，再调 get_result 得到招考信息
# 这些信息虽然没有分数，但有招考人数 (zwk_zkrs) 和报名人数 (zwk_bkrs)

# 4. 检查是否有完全不同的 URL 版本（2023版、2022版）
print()
print('=== 检查其他年份版本的页面 ===')
for year_page in ['2022skfscx', '2023skfscx', '2025skfscx']:
    url = f'https://www.huatu.com/z/{year_page}/'
    r = requests.get(url, headers={'User-Agent': HEADERS['User-Agent']}, timeout=10)
    print(f'  {url}: HTTP {r.status_code}')
    if r.status_code == 200:
        import re
        scripts = re.findall(r'<script[^>]+src=["\']([^"\']+)["\']', r.text)
        print(f'    Script URLs: {scripts}')
    time.sleep(2)

# 5. 检查 国考版本的 API
print()
print('=== 检查国考版 API ===')
guokao_pages = ['2024gkfscx', '2024gkfs', '2024guokao']
for page in guokao_pages:
    url = f'https://www.huatu.com/z/{page}/'
    r = requests.get(url, headers={'User-Agent': HEADERS['User-Agent']}, timeout=10)
    print(f'  {url}: HTTP {r.status_code}')
    time.sleep(2)

print()
print('探测完成')
