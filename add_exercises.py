import json

PATH = 'assets/data/speed_calc_preset.json'

# Load existing data
import json as _json
try:
    with open(PATH, 'r', encoding='utf-8') as _f:
        data = _json.load(_f)
    if len(data) < 5:
        raise ValueError('too few items')
    print(f'Loaded {len(data)} existing items')
except Exception as e:
    print(f'Could not load existing file ({e}), starting fresh')
    data = []

new_items = [
  # percentage_change difficulty=2 (need 2 more)
  {
    "calc_type": "percentage_change",
    "expression": "9630 * 16.7% = ?",
    "display_text": "某市2023年文化产业增加值为9630亿元，同比增长16.7%，求增长量（亿元）",
    "correct_answer": "1608.2",
    "tolerance": 2.0,
    "difficulty": 2,
    "shortcut_hint": "16.7% = 1/6，9630 / 6 = 1605，精确为1608.2",
    "explanation": "增长量 = 9630 x 16.7% = 9630 x 0.167 = 1608.2（亿元）。特征数字法：1/6 ≈ 16.67%，9630/6=1605（近似）。"
  },
  {
    "calc_type": "percentage_change",
    "expression": "7512.6 * 21.3% = ?",
    "display_text": "某省2023年战略性新兴产业产值为7512.6亿元，同比增长21.3%，求增长量（亿元）",
    "correct_answer": "1600.2",
    "tolerance": 2.0,
    "difficulty": 2,
    "shortcut_hint": "21.3% = 20% + 1.3%，分段计算：7512.6×20%=1502.5，7512.6×1.3%=97.7",
    "explanation": "增长量 = 7512.6 x 21.3%。速算：7512.6 x 20% = 1502.5，7512.6 x 1.3% = 97.7，合计 1600.2（亿元）。"
  },
  # percentage_change difficulty=3 (need 1 more)
  {
    "calc_type": "percentage_change",
    "expression": "43210 * 26.3% = ?",
    "display_text": "全国2023年跨境电商进出口规模为43210亿元，同比增长26.3%，求增长量（亿元）",
    "correct_answer": "11364.2",
    "tolerance": 10.0,
    "difficulty": 3,
    "shortcut_hint": "26.3% = 25% + 1.3%，43210×25%=10802.5，43210×1.3%=561.7，合计11364.2",
    "explanation": "增长量 = 43210 x 26.3%。速算：43210 x 25% = 10802.5，43210 x 1.3% = 561.7，合计 11364.2（亿元）。"
  },
  # base_period difficulty=1 (need 1 more)
  {
    "calc_type": "base_period",
    "expression": "8064 / (1 + 12.0%) = ?",
    "display_text": "某省2023年数字经济规模为8064亿元，同比增长12%，求2022年的值（亿元）",
    "correct_answer": "7200.0",
    "tolerance": 1.0,
    "difficulty": 1,
    "shortcut_hint": "除以1.12，等价 x 25/28，8064 x 25/28 = 7200，整除",
    "explanation": "基期量 = 8064 / 1.12 = 8064 x 25/28 = 201600/28 = 7200（亿元）。验证：7200 x 1.12 = 8064，整除。"
  },
  # base_period difficulty=2 (need 5 more)
  {
    "calc_type": "base_period",
    "expression": "4567.8 / (1 + 8.5%) = ?",
    "display_text": "某市2023年工业总产值为4567.8亿元，同比增长8.5%，求2022年的值（亿元）",
    "correct_answer": "4209.5",
    "tolerance": 1.0,
    "difficulty": 2,
    "shortcut_hint": "除以1.085，近似：4567.8 × (1 - 7.83%) ≈ 4567.8 - 357.7 = 4210",
    "explanation": "基期量 = 4567.8 / 1.085 = 4209.5（亿元）。速算：4567.8 / 1.085 ≈ 4567.8 x 0.9217 = 4210。"
  },
  {
    "calc_type": "base_period",
    "expression": "6630 / (1 + 20.0%) = ?",
    "display_text": "某地区2023年新能源汽车产值为6630亿元，同比增长20%，求2022年的值（亿元）",
    "correct_answer": "5525.0",
    "tolerance": 1.0,
    "difficulty": 2,
    "shortcut_hint": "除以1.2，等价 x 5/6，6630 x 5/6 = 5525，整除",
    "explanation": "基期量 = 6630 / 1.2 = 6630 x 5/6 = 33150/6 = 5525（亿元）。特征数字法：÷1.2 = ×5/6，整除。"
  },
  {
    "calc_type": "base_period",
    "expression": "12880 / (1 + 16.0%) = ?",
    "display_text": "某省2023年高新技术产业产值为12880亿元，同比增长16%，求2022年的值（亿元）",
    "correct_answer": "11103.4",
    "tolerance": 2.0,
    "difficulty": 2,
    "shortcut_hint": "除以1.16，近似：12880 / 1.16 ≈ 12880 x 0.862 = 11102",
    "explanation": "基期量 = 12880 / 1.16 = 11103.4（亿元）。速算：12880 x 25/29 = 322000/29 = 11103.4。"
  },
  {
    "calc_type": "base_period",
    "expression": "9240 / (1 + 5.0%) = ?",
    "display_text": "某市2023年社会消费品零售总额为9240亿元，同比增长5%，求2022年的值（亿元）",
    "correct_answer": "8800.0",
    "tolerance": 1.0,
    "difficulty": 2,
    "shortcut_hint": "除以1.05，等价 x 20/21，9240 x 20/21 = 8800，整除",
    "explanation": "基期量 = 9240 / 1.05 = 9240 x 20/21 = 184800/21 = 8800（亿元）。验证：8800 x 1.05 = 9240。"
  },
  {
    "calc_type": "base_period",
    "expression": "3375 / (1 + 35.0%) = ?",
    "display_text": "某市2023年新能源装机量为3375万千瓦，同比增长35%，求2022年的装机量（万千瓦）",
    "correct_answer": "2500.0",
    "tolerance": 0.5,
    "difficulty": 2,
    "shortcut_hint": "除以1.35：3375/1.35=2500，整除",
    "explanation": "基期量 = 3375 / 1.35 = 2500（万千瓦）。速算：3375 x 20/27 = 3375/1.35 = 2500，整除。"
  },
  # base_period difficulty=3 (need 4 more)
  {
    "calc_type": "base_period",
    "expression": "56160 / (1 + 17.0%) = ?",
    "display_text": "全国2023年规模以上工业总产值为56160亿元，同比增长17%，求2022年的值（亿元）",
    "correct_answer": "48000.0",
    "tolerance": 5.0,
    "difficulty": 3,
    "shortcut_hint": "除以1.17，等价 x 100/117，56160 x 100/117 = 48000，整除",
    "explanation": "基期量 = 56160 / 1.17 = 48000（亿元）。验证：48000 x 1.17 = 56160，整除。"
  },
  {
    "calc_type": "base_period",
    "expression": "7722 / (1 + 11.0%) = ?",
    "display_text": "某省2023年居民人均可支配收入为7722元，同比增长11%，求2022年的值（元）",
    "correct_answer": "6956.8",
    "tolerance": 2.0,
    "difficulty": 3,
    "shortcut_hint": "除以1.11，等价 x 100/111，7722/1.11 ≈ 6956.8",
    "explanation": "基期量 = 7722 / 1.11 = 6956.8（元）。速算：7722 x 100/111 = 772200/111 = 6956.8。"
  },
  {
    "calc_type": "base_period",
    "expression": "23920 / (1 + 36.0%) = ?",
    "display_text": "某市2023年战略性新兴产业营收为23920亿元，同比增长36%，求2022年的值（亿元）",
    "correct_answer": "17588.2",
    "tolerance": 5.0,
    "difficulty": 3,
    "shortcut_hint": "除以1.36，等价 x 25/34，23920 x 25/34 ≈ 17588",
    "explanation": "基期量 = 23920 / 1.36 = 23920 x 25/34 = 598000/34 = 17588.2（亿元）。"
  },
  {
    "calc_type": "base_period",
    "expression": "18720 / (1 + 4.0%) = ?",
    "display_text": "全国2023年社会保障基金收入为18720亿元，同比增长4%，求2022年的值（亿元）",
    "correct_answer": "18000.0",
    "tolerance": 1.0,
    "difficulty": 3,
    "shortcut_hint": "除以1.04，等价 x 25/26，18720 x 25/26 = 18000，整除",
    "explanation": "基期量 = 18720 / 1.04 = 18720 x 25/26 = 468000/26 = 18000（亿元）。验证：18000 x 1.04 = 18720。"
  },
  # proportion difficulty=2 (need 4 more)
  {
    "calc_type": "proportion",
    "expression": "2468.0 / 9876.0 = ?%",
    "display_text": "某省2023年工业用电量为2468.0亿千瓦时，全社会用电量为9876.0亿千瓦时，求工业用电占比",
    "correct_answer": "25.0%",
    "tolerance": 0.1,
    "difficulty": 2,
    "shortcut_hint": "2468/9876 ≈ 25%，9876/4=2469≈2468",
    "explanation": "比重 = 2468.0 / 9876.0 = 0.2499 ≈ 25.0%。速算：9876/4 = 2469 ≈ 2468，故约25%。"
  },
  {
    "calc_type": "proportion",
    "expression": "4567 / 19876 = ?%",
    "display_text": "某地区2023年高技术产业产值为4567亿元，规模以上工业总产值为19876亿元，求高技术产业占比",
    "correct_answer": "22.9%",
    "tolerance": 0.3,
    "difficulty": 2,
    "shortcut_hint": "截位直除：4567/19876 ≈ 4.567/19.876 ≈ 23%，精确22.9%",
    "explanation": "比重 = 4567 / 19876 = 0.2298 = 22.9%（四舍五入）。速算：4567/19876 ≈ 4.57/19.88 ≈ 23.0%，精确22.9%。"
  },
  {
    "calc_type": "proportion",
    "expression": "3456.7 / 12300.0 = ?%",
    "display_text": "某省2023年一般公共预算支出中社会保障支出为3456.7亿元，总支出为12300.0亿元，求占比",
    "correct_answer": "28.1%",
    "tolerance": 0.3,
    "difficulty": 2,
    "shortcut_hint": "截位直除：3457/12300 ≈ 3.457/12.3 ≈ 28.1%",
    "explanation": "比重 = 3456.7 / 12300.0 = 0.2811 = 28.1%（四舍五入）。速算：3457/12300 ≈ 28.1%。"
  },
  {
    "calc_type": "proportion",
    "expression": "5000 / 32000 = ?%",
    "display_text": "某市2023年清洁能源发电量为5000亿千瓦时，全市发电总量为32000亿千瓦时，求清洁能源占比",
    "correct_answer": "15.6%",
    "tolerance": 0.1,
    "difficulty": 2,
    "shortcut_hint": "5000/32000 = 5/32 = 15.625% ≈ 15.6%",
    "explanation": "比重 = 5000 / 32000 = 5/32 = 0.15625 = 15.6%。特征数字法：5/32精确计算。"
  },
  # proportion difficulty=3 (need 3 more)
  {
    "calc_type": "proportion",
    "expression": "8765 / 43210 = ?%",
    "display_text": "全国2023年高技术产品出口额为8765亿美元，商品出口总额为43210亿美元，求高技术产品占比",
    "correct_answer": "20.3%",
    "tolerance": 0.3,
    "difficulty": 3,
    "shortcut_hint": "截位直除：8765/43210 ≈ 8.77/43.21 ≈ 20.3%",
    "explanation": "比重 = 8765 / 43210 = 0.2029 = 20.3%（四舍五入）。速算：8765/43210 ≈ 8.77/43.21 ≈ 20.3%。"
  },
  {
    "calc_type": "proportion",
    "expression": "6789 / 39876 = ?%",
    "display_text": "某省2023年第一产业增加值为6789亿元，地区生产总值为39876亿元，求第一产业比重",
    "correct_answer": "17.0%",
    "tolerance": 0.3,
    "difficulty": 3,
    "shortcut_hint": "截位直除：6789/39876 ≈ 6.79/39.88 ≈ 17.0%",
    "explanation": "比重 = 6789 / 39876 = 0.1702 = 17.0%（四舍五入）。速算：6789/39876 ≈ 6.79/39.88 ≈ 17.0%。"
  },
  {
    "calc_type": "proportion",
    "expression": "12345.6 / 56789.1 = ?%",
    "display_text": "全国2023年农村居民人均消费支出为12345.6元，全国人均消费支出为56789.1元，求农村居民消费支出占比",
    "correct_answer": "21.7%",
    "tolerance": 0.3,
    "difficulty": 3,
    "shortcut_hint": "截位直除：1.2346 / 5.6789 ≈ 21.7%",
    "explanation": "比重 = 12345.6 / 56789.1 = 0.2174 = 21.7%（四舍五入）。速算：12346/56789 ≈ 21.7%。"
  },
  # growth_rate_compare difficulty=1 (need 7 more)
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:200→230, B:400→468, C:600→690, D:800→936 增长率最高者为？",
    "display_text": "某市四类产业投资2022年至2023年（亿元）：A从200增至230，B从400增至468，C从600增至690，D从800增至936，哪类增长率最高？",
    "correct_answer": "D",
    "tolerance": 0,
    "difficulty": 1,
    "shortcut_hint": "A=15%,B=17%,C=15%,D=17%，B和D并列最高均为17%",
    "explanation": "A增长率=30/200=15%；B增长率=68/400=17%；C增长率=90/600=15%；D增长率=136/800=17%。B和D均为17%最高，选D。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:1500→1680, B:2500→2725, C:3500→3815, D:4500→4950 增长率最低者为？",
    "display_text": "某省四类经济指标2022年至2023年（亿元）：A从1500增至1680，B从2500增至2725，C从3500增至3815，D从4500增至4950，哪类增长率最低？",
    "correct_answer": "B",
    "tolerance": 0,
    "difficulty": 1,
    "shortcut_hint": "A=12%,B=9%,C=9%,D=10%，B和C均为9%最低，选B",
    "explanation": "A增长率=180/1500=12%；B增长率=225/2500=9%；C增长率=315/3500=9%；D增长率=450/4500=10%。B和C均为9%最低，选B。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:320→384, B:640→736, C:960→1085, D:1280→1446 增长率最高者为？",
    "display_text": "某地区四类数字经济指标2022年至2023年（亿元）：A从320增至384，B从640增至736，C从960增至1085，D从1280增至1446，哪类增长率最高？",
    "correct_answer": "A",
    "tolerance": 0,
    "difficulty": 1,
    "shortcut_hint": "A=20%,B=15%,C≈13%,D≈13%，A最高",
    "explanation": "A增长率=64/320=20%；B增长率=96/640=15%；C增长率=125/960≈13.0%；D增长率=166/1280≈13.0%。A最高为20%，选A。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:750→825, B:1500→1650, C:2250→2520, D:3000→3270 增长率最高者为？",
    "display_text": "某省四项财政支出2022年至2023年（亿元）：A从750增至825，B从1500增至1650，C从2250增至2520，D从3000增至3270，哪项增长率最高？",
    "correct_answer": "C",
    "tolerance": 0,
    "difficulty": 1,
    "shortcut_hint": "A=10%,B=10%,C=12%,D=9%，C最高",
    "explanation": "A增长率=75/750=10%；B增长率=150/1500=10%；C增长率=270/2250=12%；D增长率=270/3000=9%。C最高为12%，选C。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:180→207, B:360→410, C:720→806, D:1440→1598 增长率最高者为？",
    "display_text": "某市四项新能源指标2022年至2023年（亿元）：A从180增至207，B从360增至410，C从720增至806，D从1440增至1598，哪项增长率最高？",
    "correct_answer": "A",
    "tolerance": 0,
    "difficulty": 1,
    "shortcut_hint": "A=15%,B≈13.9%,C≈11.9%,D≈11%，A最高",
    "explanation": "A增长率=27/180=15%；B增长率=50/360≈13.9%；C增长率=86/720≈11.9%；D增长率=158/1440≈11.0%。A最高为15%，选A。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:900→990, B:1800→1980, C:2700→2970, D:3600→3996 增长率最高者为？",
    "display_text": "某省四类规模指标2022年至2023年（亿元）：A从900增至990，B从1800增至1980，C从2700增至2970，D从3600增至3996，哪类增长率最高？",
    "correct_answer": "D",
    "tolerance": 0,
    "difficulty": 1,
    "shortcut_hint": "A=10%,B=10%,C=10%,D=11%，D最高",
    "explanation": "A增长率=90/900=10%；B增长率=180/1800=10%；C增长率=270/2700=10%；D增长率=396/3600=11%。D最高为11%，选D。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:600→660, B:800→880, C:1000→1120, D:1200→1320 增长率最高者为？",
    "display_text": "某市四类社会指标2022年至2023年变化：A从600增至660，B从800增至880，C从1000增至1120，D从1200增至1320，哪类增长率最高？",
    "correct_answer": "C",
    "tolerance": 0,
    "difficulty": 1,
    "shortcut_hint": "A=10%,B=10%,C=12%,D=10%，C最高",
    "explanation": "A增长率=60/600=10%；B增长率=80/800=10%；C增长率=120/1000=12%；D增长率=120/1200=10%。C最高为12%，选C。"
  },
  # growth_rate_compare difficulty=2 (need 7 more)
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:2345→2627, B:4567→5138, C:6789→7544, D:8901→9902 增长率最高者为？",
    "display_text": "某省四类产业增加值2022年至2023年（亿元）：A从2345增至2627，B从4567增至5138，C从6789增至7544，D从8901增至9902，哪类增长率最高？",
    "correct_answer": "B",
    "tolerance": 0,
    "difficulty": 2,
    "shortcut_hint": "A=282/2345≈12%,B=571/4567≈12.5%,C=755/6789≈11.1%,D=1001/8901≈11.2%，B最高",
    "explanation": "A增长率=282/2345≈12.0%；B增长率=571/4567≈12.5%；C增长率=755/6789≈11.1%；D增长率=1001/8901≈11.2%。B最高约12.5%，选B。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:3456→3802, B:6789→7399, C:9012→9913, D:1234→1370 增长率最低者为？",
    "display_text": "某地区四类消费数据2022年至2023年（亿元）：A从3456增至3802，B从6789增至7399，C从9012增至9913，D从1234增至1370，哪类增长率最低？",
    "correct_answer": "B",
    "tolerance": 0,
    "difficulty": 2,
    "shortcut_hint": "A≈10%,B≈9%,C≈10%,D≈11%，B最低",
    "explanation": "A增长率=346/3456≈10.0%；B增长率=610/6789≈9.0%；C增长率=901/9012≈10.0%；D增长率=136/1234≈11.0%。B最低约9%，选B。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:1111→1244, B:3333→3766, C:5555→6194, D:7777→8690 增长率最高者为？",
    "display_text": "某省四类工业产值2022年至2023年（亿元）：A从1111增至1244，B从3333增至3766，C从5555增至6194，D从7777增至8690，哪类增长率最高？",
    "correct_answer": "B",
    "tolerance": 0,
    "difficulty": 2,
    "shortcut_hint": "A=12%,B≈13%,C≈11.5%,D≈11.7%，B最高",
    "explanation": "A增长率=133/1111≈12.0%；B增长率=433/3333≈13.0%；C增长率=639/5555≈11.5%；D增长率=913/7777≈11.7%。B最高约13%，选B。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:4321→5054, B:8765→9983, C:12345→14197, D:23456→26566 增长率最低者为？",
    "display_text": "全国四类货物贸易额2022年至2023年（亿元）：A从4321增至5054，B从8765增至9983，C从12345增至14197，D从23456增至26566，哪类增长率最低？",
    "correct_answer": "D",
    "tolerance": 0,
    "difficulty": 2,
    "shortcut_hint": "A≈17%,B≈13.9%,C≈15%,D≈13.3%，D最低",
    "explanation": "A增长率=733/4321≈17.0%；B增长率=1218/8765≈13.9%；C增长率=1852/12345≈15.0%；D增长率=3110/23456≈13.3%。D最低约13.3%，选D。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:5400→6210, B:7200→8100, C:9000→10125, D:10800→12204 增长率最高者为？",
    "display_text": "某省四类新兴产业产值2022年至2023年（亿元）：A从5400增至6210，B从7200增至8100，C从9000增至10125，D从10800增至12204，哪类增长率最高？",
    "correct_answer": "A",
    "tolerance": 0,
    "difficulty": 2,
    "shortcut_hint": "A=15%,B=12.5%,C=12.5%,D=13%，A最高",
    "explanation": "A增长率=810/5400=15%；B增长率=900/7200=12.5%；C增长率=1125/9000=12.5%；D增长率=1404/10800=13%。A最高为15%，选A。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:2000→2300, B:5000→5650, C:8000→8960, D:10000→11100 增长率排第二者为？",
    "display_text": "某地区四类产业规模2022年至2023年（亿元）：A从2000增至2300，B从5000增至5650，C从8000增至8960，D从10000增至11100，增长率排第二的是哪类？",
    "correct_answer": "B",
    "tolerance": 0,
    "difficulty": 2,
    "shortcut_hint": "A=15%,B=13%,C=12%,D=11%，排序A>B>C>D，第二为B",
    "explanation": "A增长率=300/2000=15%；B增长率=650/5000=13%；C增长率=960/8000=12%；D增长率=1100/10000=11%。排序A>B>C>D，第二为B，选B。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:1200→1392, B:3400→3876, C:5600→6216, D:7800→8658 增长率最高者为？",
    "display_text": "某省四类清洁能源装机量2022年至2023年（万千瓦）：A从1200增至1392，B从3400增至3876，C从5600增至6216，D从7800增至8658，哪类增长率最高？",
    "correct_answer": "A",
    "tolerance": 0,
    "difficulty": 2,
    "shortcut_hint": "A=16%,B=14%,C=11%,D=11%，A最高",
    "explanation": "A增长率=192/1200=16%；B增长率=476/3400=14%；C增长率=616/5600=11%；D增长率=858/7800=11%。A最高为16%，选A。"
  },
  # growth_rate_compare difficulty=3 (need 6 more)
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:13500→15390, B:9000→10260, C:6300→7245, D:3600→4176 增长率最高者为？",
    "display_text": "某省四类基础设施存量2022年至2023年（亿元）：A从13500增至15390，B从9000增至10260，C从6300增至7245，D从3600增至4176，哪类增长率最高？",
    "correct_answer": "D",
    "tolerance": 0,
    "difficulty": 3,
    "shortcut_hint": "A=14%,B=14%,C=15%,D=16%，D最高",
    "explanation": "A增长率=1890/13500=14%；B增长率=1260/9000=14%；C增长率=945/6300=15%；D增长率=576/3600=16%。D最高为16%，选D。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:23100→25872, B:15600→17082, C:9800→11074, D:5200→5824 增长率最低者为？",
    "display_text": "全国四类能源产量2022年至2023年（亿吨/万亿度）：A从23100增至25872，B从15600增至17082，C从9800增至11074，D从5200增至5824，哪类增长率最低？",
    "correct_answer": "B",
    "tolerance": 0,
    "difficulty": 3,
    "shortcut_hint": "A=12%,B=9.5%,C=13%,D=12%，B最低",
    "explanation": "A增长率=2772/23100=12.0%；B增长率=1482/15600=9.5%；C增长率=1274/9800=13.0%；D增长率=624/5200=12.0%。B最低为9.5%，选B。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:4500→5130, B:7500→8700, C:12000→13560, D:20000→22200 增长率第二高者为？",
    "display_text": "某市四类投资规模2022年至2023年（亿元）：A从4500增至5130，B从7500增至8700，C从12000增至13560，D从20000增至22200，增长率第二高的是哪类？",
    "correct_answer": "A",
    "tolerance": 0,
    "difficulty": 3,
    "shortcut_hint": "A=14%,B=16%,C=13%,D=11%，排序B>A>C>D，第二为A",
    "explanation": "A增长率=630/4500=14%；B增长率=1200/7500=16%；C增长率=1560/12000=13%；D增长率=2200/20000=11%。排序B>A>C>D，第二为A，选A。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:5678→6472, B:9012→10003, C:14567→16024, D:23456→25331 增长率最高者为？",
    "display_text": "全国四类固定资产投资2022年至2023年（亿元）：A从5678增至6472，B从9012增至10003，C从14567增至16024，D从23456增至25331，哪类增长率最高？",
    "correct_answer": "A",
    "tolerance": 0,
    "difficulty": 3,
    "shortcut_hint": "A=794/5678≈14%,B=991/9012≈11%,C=1457/14567=10%,D=1875/23456≈8%，A最高",
    "explanation": "A增长率=794/5678≈14.0%；B增长率=991/9012≈11.0%；C增长率=1457/14567=10.0%；D增长率=1875/23456≈8.0%。A最高约14%，选A。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:34567→37677, B:56789→61730, C:78901→85413, D:12345→13456 增长率最低者为？",
    "display_text": "全国四类服务业营收2022年至2023年（亿元）：A从34567增至37677，B从56789增至61730，C从78901增至85413，D从12345增至13456，哪类增长率最低？",
    "correct_answer": "C",
    "tolerance": 0,
    "difficulty": 3,
    "shortcut_hint": "A≈9%,B≈8.7%,C≈8.25%,D≈9%，C最低",
    "explanation": "A增长率=3110/34567≈9.0%；B增长率=4941/56789≈8.7%；C增长率=6512/78901≈8.25%；D增长率=1111/12345≈9.0%。C最低约8.25%，选C。"
  },
  {
    "calc_type": "growth_rate_compare",
    "expression": "A:8765→9992, B:6543→7505, C:4321→4994, D:2109→2468 增长率最高者为？",
    "display_text": "某省四类新兴行业营收2022年至2023年（亿元）：A从8765增至9992，B从6543增至7505，C从4321增至4994，D从2109增至2468，哪类增长率最高？",
    "correct_answer": "D",
    "tolerance": 0,
    "difficulty": 3,
    "shortcut_hint": "A≈14%,B≈14.7%,C≈15.6%,D≈17%，D最高",
    "explanation": "A增长率=1227/8765≈14.0%；B增长率=962/6543≈14.7%；C增长率=673/4321≈15.6%；D增长率=359/2109≈17.0%。D最高约17%，选D。"
  },
  # estimate difficulty=3 (need 2 more)
  {
    "calc_type": "estimate",
    "expression": "45678 * 5.6% + 23456 * 12.3% = ?",
    "display_text": "估算两项增量之和：45678亿元增长5.6%的增量，加上23456亿元增长12.3%的增量",
    "correct_answer": "5443.1",
    "tolerance": 5.0,
    "difficulty": 3,
    "shortcut_hint": "45678×5.6%=2558.0，23456×12.3%=2885.1，合计5443.1",
    "explanation": "45678×5.6% = 45678×0.056 = 2558.0，23456×12.3% = 23456×0.123 = 2885.1，合计 5443.1（亿元）。速算：分别计算后相加。"
  },
  {
    "calc_type": "estimate",
    "expression": "1 / (1.05 * 1.08) * 10000 ≈ ?",
    "display_text": "估算某基期量折算：现期量10000亿元连续两年增长5%和8%后的基期（两年前）值",
    "correct_answer": "8816.9",
    "tolerance": 5.0,
    "difficulty": 3,
    "shortcut_hint": "1.05×1.08=1.134，10000/1.134≈8817",
    "explanation": "基期量 = 10000 / (1.05 × 1.08) = 10000 / 1.134 = 8816.9（亿元）。速算：1.05×1.08=1.134，10000/1.134≈8817。"
  }
]

data.extend(new_items)
print(f'New total: {len(data)}')

from collections import Counter
types = Counter(d['calc_type'] for d in data)
print('By type:', dict(types))
diffs = {}
for d in data:
    key = (d['calc_type'], d['difficulty'])
    diffs[key] = diffs.get(key, 0) + 1
print('Distribution:')
for t in ['percentage_change','base_period','proportion','growth_rate_compare','estimate']:
    row = []
    for diff in [1,2,3]:
        row.append(diffs.get((t,diff),0))
    print(f'  {t}: easy={row[0]}, med={row[1]}, hard={row[2]}, total={sum(row)}')

with open(PATH, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print('Written successfully')
