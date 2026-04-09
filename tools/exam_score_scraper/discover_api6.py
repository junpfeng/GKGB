"""
华图 API 深度探测 - 第六轮
检查 2023skfscx 和 2025skfscx 的 JS，寻找分数 API
"""
import requests
import json
import time
import re

HEADERS = {
    'User-Agent': 'ExamPrepApp/1.0 (exam-entry-scores-data-collector; educational-use)',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}

def fetch_js(year_str):
    url = f'https://www.huatu.com/z/{year_str}skfscx/js/index.js'
    resp = requests.get(url, headers={**HEADERS, 'Referer': f'https://www.huatu.com/z/{year_str}skfscx/'}, timeout=15)
    print(f'=== {year_str}skfscx/js/index.js: HTTP {resp.status_code}, {len(resp.text)} chars ===')
    if resp.status_code == 200:
        # 找所有 URL
        urls = re.findall(r'https?://[^\s"\'\\\`<>\)]+', resp.text)
        print('  URLs:', sorted(set(urls)))
        # 找分数相关字段
        score_fields = re.findall(r'zwk_[a-z]+', resp.text)
        print('  Score fields:', sorted(set(score_fields)))
        print()
        return resp.text
    return ''

for yr in ['2023', '2025']:
    js_text = fetch_js(yr)
    time.sleep(2)

# 检查 2025skfscx 的数据（可能已有2025年数据）
print('=== 测试 2025年数据 ===')
resp = requests.post('https://apis.huatu.com/api/shengkao/get_distinct',
                     data={'zwk_year': 2025, 'field': 'zwk_sheng'},
                     headers={**HEADERS, 'Content-Type': 'application/x-www-form-urlencoded',
                              'Referer': 'https://www.huatu.com/z/2025skfscx/',
                              'Origin': 'https://www.huatu.com'}, timeout=15)
try:
    rj = resp.json()
    print(f'  2025省份: code={rj.get("code")}, data={rj.get("data", [])}')
except:
    print(f'  2025: {resp.text[:200]}')

time.sleep(2)

# 检查 fs_list 是否有特定 session/cookie 要求
print()
print('=== 检查 fs_list 的 extra 字段含义 ===')
# 重新测试 fs_list，关注 extra 字段
resp = requests.post('https://apis.huatu.com/api/shengkao/fs_list',
                     data={'zwk_year': 2024, 'zwk_sheng': '山东', 'zwk_zwlx': '全国', 'page': 1},
                     headers={**HEADERS, 'Content-Type': 'application/x-www-form-urlencoded',
                              'Referer': 'https://www.huatu.com/z/2024skfscx/',
                              'Origin': 'https://www.huatu.com'}, timeout=15)
rj = resp.json()
print(f'  fs_list: code={rj.get("code")}, extra={rj.get("extra")}, total={rj.get("extra", {}).get("total") if isinstance(rj.get("extra"), dict) else "N/A"}')
print(f'  全部响应: {json.dumps(rj, ensure_ascii=False)}')

# 关键问题：data为空的原因
# extra={'page': 1, 'total': 0} 表示 total=0，即服务端认为无数据
# 这可能是因为：
# 1. fs_list 只有已登录用户才能看到（需要 UID/token）
# 2. 或者 fs_list 数据尚未发布（分数线还未放出）
# 3. 或者 fs_list 需要特殊参数

# 检查不同的 zwk_zwlx 字符串
time.sleep(2)
print()
print('=== 检查数据库中实际存在的数据状态 ===')
# 用 get_distinct 总结各省数据量
for prov, year in [('山东', 2024), ('山东', 2023), ('江苏', 2024), ('浙江', 2024)]:
    resp = requests.post('https://apis.huatu.com/api/shengkao/get_distinct',
                         data={'zwk_year': year, 'field': 'zwk_zwdm', 'zwk_sheng': prov},
                         headers={**HEADERS, 'Content-Type': 'application/x-www-form-urlencoded',
                                  'Referer': 'https://www.huatu.com/z/2024skfscx/',
                                  'Origin': 'https://www.huatu.com'}, timeout=15)
    rj = resp.json()
    print(f'  {prov} {year}: {len(rj.get("data", []))} 个岗位代码')
    time.sleep(2)

# 关键问题：get_result 有数据，但没有分数 - 意味着 fs_list 不工作时，
# 我们可以通过 get_result 获取所有招考信息（无分数）
# 这仍然有价值：zwk_zkrs(招考人数), zwk_bkrs(报名人数), zwk_xl(学历要求)
# 分数 (zwk_zdf/zwk_zgf) 只能从 fs_list 获取

# 结论：
# - get_distinct + get_result = 全量招考岗位数据（无分数），几千条
# - fs_list = 有分数但需要登录认证（总计=0，受 localStorage 控制）
# 策略：获取全量岗位信息作为补充数据，分数字段留空

print()
print('数据分析完成')
print('结论：')
print('  - get_result 可获取岗位信息（无分数字段），可作为事业编/省考参考数据')
print('  - fs_list 有分数但需要用户登录（服务端 total=0）')
print('  - 建议策略：遍历 get_distinct 岗位代码 → get_result 获取招考信息 → 无 min_entry_score')
print('  - 或：寻找其他有分数的数据源补充')
