# 修复日志：预置公告 source_url 全部无效

## 根因

`assets/data/rencaiyinjin_policies_preset.json` 中 25 条公告为 AI 生成的虚构数据，URL 仅取了各地人社局的通用页面地址（首页或栏目列表页），不指向具体公告。

## 修改文件

- `assets/data/rencaiyinjin_policies_preset.json` — 全量替换为真实公告数据

## 修复内容

为 25 个城市搜索了真实的人才引进/事业单位招聘公告，替换了全部数据：

| # | 城市 | 真实公告标题 | URL 来源 |
|---|------|-------------|---------|
| 1 | 杭州 | 2026年市属事业单位统一公开招聘 274人 | hrss.hangzhou.gov.cn |
| 2 | 宁波 | 自然资源和规划局下属事业单位招聘 4人 | rsj.ningbo.gov.cn |
| 3 | 南京 | 2026年事业单位统一公开招聘 607人 | rsj.nanjing.gov.cn |
| 4 | 苏州 | 2026年市属事业单位招聘 107人 | suzhou.bendibao.com |
| 5 | 深圳 | 2026年集中公开招聘高校毕业生 658人 | sydw.huatu.com |
| 6 | 广州 | 2026年事业单位统一招聘 91人 | rsj.gz.gov.cn |
| 7 | 济南 | 2025年泉优计划引进 87人 | jnhrss.jinan.gov.cn |
| 8 | 青岛 | 2026年市属事业单位招聘 144人 | hrss.qingdao.gov.cn |
| 9 | 成都 | 2026年事业单位招聘第一批 471人 | m.cd.bendibao.com |
| 10 | 北京 | 东城区2026年事业单位招聘 58人 | bjdch.gov.cn |
| 11 | 上海 | 2026年事业单位招聘 2468人 | rsj.sh.gov.cn |
| 12 | 武汉 | 2026年事业单位招聘 3208人 | wuhan.gov.cn |
| 13 | 郑州 | 2025年事业单位联考 2054人 | public.zhengzhou.gov.cn |
| 14 | 厦门 | 2026年事业单位招聘 | xm.bendibao.com |
| 15 | 合肥 | 2025年选调生同步人才引进 160人 | finance.sina.com.cn |
| 16 | 长沙 | 2026年教育局所属事业单位招聘 662人 | gxrcyj.com |
| 17 | 重庆 | 2026年Q1考核招聘高层次人才 310人 | rlsbj.cq.gov.cn |
| 18 | 天津 | 北辰区2026年事业单位招聘 21人 | tjbc.gov.cn |
| 19 | 西安 | 2025年下半年事业单位招聘 650人 | xa.bendibao.com |
| 20 | 东莞 | 发改局下属事业单位2025年招聘 6人 | dgdp.dg.gov.cn |
| 21 | 温州 | 2025年下半年市级事业单位招聘 25人 | wz.bendibao.com |
| 22 | 无锡 | 2026年市属事业单位招聘 39人 | hrss.wuxi.gov.cn |
| 23 | 烟台 | 2026年菁英计划选聘 60人 | yantai.gov.cn |
| 24 | 佛山 | 南海区教育系统招聘教师 224人 | bianzhia.com |
| 25 | 太原 | 卫健委2026年招聘博士研究生 18人 | rcyjw.com |

原绍兴条目（URL 指向山西省人社厅，城市与省份不匹配）替换为太原条目。

## 验证

- flutter analyze: 零新错误
- JSON 解析: 25 条数据全部通过
- URL 可访问性: 全部 25 个 URL 经 WebFetch 验证可访问且包含公告正文
