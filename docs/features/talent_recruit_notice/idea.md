# 全量拉取江浙沪皖鲁人才引进公告

## 核心需求
全量拉取江浙沪皖鲁五个省份的人才引进计划公告到本地数据，并整理到岗位匹配功能中。

## 调研上下文

### 现有基础设施

**数据模型**（已有，无需新建）：
- `TalentPolicy` — 人才引进公告（title, province, city, policyType, publishDate, deadline, content, sourceUrl, attachmentUrls）
- `Position` — 岗位信息（positionName, department, educationReq, majorReq, ageReq, politicalReq, workExpReq, certificateReq, genderReq, hukouReq 等）
- `MatchResult` — 匹配结果（matchScore, matchedItems, riskItems, unmatchedItems, advice, isTarget）

**数据库表**（已有）：
- `talent_policies` — 招聘公告表
- `positions` — 岗位表（FK → talent_policies）
- `match_results` — 匹配结果表（FK → positions）

**服务层**（已有，`MatchService` ~929行）：
- 预置数据加载：`loadPresetPolicies()` — 从 `assets/data/rencaiyinjin_policies_preset.json` 加载，按 title+province+city 去重
- 在线搜索：`searchPoliciesOnline()` — Bing 搜索 + AI 解析
- URL 导入：`importFromUrl()` — 网页抓取 + AI 解析
- 剪贴板导入：`importFromClipboard()`
- AI 解析：`aiParsePolicy()` — 公告文本 → 结构化岗位
- 两级匹配引擎：`runMatching()` — 公告粗筛 → 岗位精确匹配（学历25分+专业30分+年龄15分+政治面貌10分+性别10分+工作经验10分 = 100分）

**UI 层**（已有）：
- `PolicyMatchScreen` — 公告管理 + 匹配结果 双 Tab 页面

**预置数据**（已有，~41KB）：
- `assets/data/rencaiyinjin_policies_preset.json` — 包含部分浙江省城市的公告数据

### 五省份范围
- 江 = 江苏（南京、苏州、无锡、常州、镇江、扬州、南通、泰州、盐城、徐州、淮安、连云港、宿迁）
- 浙 = 浙江（杭州、宁波、温州、嘉兴、湖州、绍兴、金华、衢州、舟山、台州、丽水）
- 沪 = 上海
- 皖 = 安徽（合肥、芜湖、蚌埠、淮南、马鞍山、淮北、铜陵、安庆、黄山、阜阳、宿州、滁州、六安、亳州、池州、宣城）
- 鲁 = 山东（济南、青岛、烟台、潍坊、淄博、济宁、临沂、泰安、威海、日照、德州、聊城、滨州、菏泽、东营、枣庄）

## 范围边界
- 做：扩充预置公告数据覆盖五省主要城市，整合到现有匹配流程
- 不做：待确认

## 初步理解
核心是扩充预置数据 JSON，使五省份各主要城市都有代表性的人才引进/事业编招聘公告及岗位数据，利用已有的 `loadPresetPolicies()` 机制自动加载到本地 SQLite，配合已有匹配引擎工作。

## 待确认事项
1. 数据来源方式：扩充静态预置 JSON vs 构建实时爬虫系统
2. 覆盖深度：每个城市多少条公告？
3. 公告类型范围：仅人才引进 or 包含事业编招聘、选调生等？
4. 是否需要按省份筛选/管理的 UI 增强？

## 确认方案

### 核心思路
新建 CrawlerService，内置江浙沪皖鲁五省 70+ 政府人社网站配置，通过通用爬虫 + AI 智能解析实现任意政府网站的公告抓取，存入现有匹配系统。

### 锁定决策

**数据层**：
- 数据模型：复用现有 TalentPolicy、Position、MatchResult，无需新增模型
- 数据库变更：新增 crawl_sources 表（目标站点配置及抓取状态）、version bump
- 序列化：crawl_sources 使用 fromDb/toDb 手写（简单场景）

**服务层**：
- 新增服务：CrawlerService（ChangeNotifier）
  - crawlAllProvinces() — 全量抓取五省
  - crawlProvince(String province) — 抓取指定省份
  - cancelCrawl() — 取消抓取
  - 内置 70+ 省市级目标站点配置
  - 通用抓取流程：列表页 → 公告链接提取 → 详情页 → AI 解析 → 入库
  - 智能链接提取：HTML 关键词匹配（公告/招聘/引进）+ AI 回退
  - 请求间隔 ≥2s，遵守 robots.txt
- LLM 调用：通过 LlmManager.chat() 解析公告详情页为结构化岗位数据
- 外部依赖：无新增（Dio + html 已有）

**UI 层**：
- 修改 PolicyMatchScreen：AppBar 添加"抓取公告"按钮
- 抓取进度弹窗：显示当前省份/城市、已抓取数量、进度条
- 无需新增页面或 ChangeNotifier

**主要技术决策**：
- 通用爬虫 vs 站点定制：选择通用爬虫（AI 驱动），原因：70+ 站点逐个定制不可行
- 抓取触发：开发阶段全量预抓取 + 用户手动触发，原因：兼顾初始数据和时效性
- 去重策略：复用现有 title+province+city 去重键

**技术细节**：

目标站点范围（70+ 站点）：
- 江苏（15站）：省人社厅 + 省人事考试网 + 13 地级市人社局
- 浙江（13站）：省人社厅 + 省人事考试网 + 11 地级市人社局
- 上海（3站）：市人社局 + 市考试院 + 21 世纪人才网
- 安徽（18站）：省人社厅 + 省人事考试网 + 16 地级市人社局
- 山东（18站）：省人社厅 + 省人事考试网 + 16 地级市人社局

抓取流程：
1. 遍历 crawl_sources 获取目标站点列表
2. 对每个站点：fetch 列表页 HTML
3. HTML 解析提取公告链接（<a> 含关键词：公告/招聘/引进/人才）
4. 若启发式解析失败 → AI 分析页面结构提取链接
5. 对每个公告链接：
   a. 去重检查（URL 或 title+province+city）
   b. Fetch 详情页 HTML → 提取正文文本
   c. AI 解析：标题/省份/城市/类型/截止日期/岗位列表
   d. 插入 talent_policies + positions 表
6. 记录抓取结果到 crawl_sources（last_crawled_at, status）
7. 请求间隔 ≥2s

crawl_sources 表结构：
- id INTEGER PRIMARY KEY
- name TEXT — 站点名称
- province TEXT — 省份
- city TEXT — 城市（省级站点为 null）
- base_url TEXT — 站点基础 URL
- list_path TEXT — 公告列表页路径
- policy_type TEXT — 公告类型
- last_crawled_at TEXT — 上次抓取时间
- status TEXT — success/failed/pending
- enabled INTEGER DEFAULT 1

CrawlerService 接口：
- Future<CrawlReport> crawlAllProvinces()
- Future<CrawlReport> crawlProvince(String province)
- Future<void> cancelCrawl()
- bool get isCrawling / String get currentStatus / double get progress / int get policiesFound

CrawlReport：totalSources, successSources, failedSources, newPolicies, newPositions, errors

错误处理：
- 站点不可达：记录失败，跳过继续
- HTML 无法解析：AI 回退，仍失败则跳过
- AI 解析失败：保存原始文本，跳过岗位提取

**范围边界**：
- 做：五省全部省市级人社局/考试网公告抓取、AI 解析入库、匹配引擎整合、抓取进度 UI
- 不做：定时自动抓取（WorkManager/系统托盘）、公告推送通知、PDF/Excel 附件解析、反爬对抗

### 待细化
- 各站点具体 URL 路径：实现引擎通过 WebSearch 研究确认真实可用的政府网站 URL
- 站点特殊处理：部分站点可能需要特殊 headers 或 cookie 处理
- AI prompt 优化：公告解析 prompt 模板在实现中调优

### 验收标准
- [mechanical] CrawlerService 存在：判定 `grep -r "CrawlerService" lib/services/`
- [mechanical] crawl_sources 表存在：判定 `grep "crawl_sources" lib/db/database_helper.dart`
- [mechanical] Provider 注册：判定 `grep "CrawlerService" lib/main.dart`
- [mechanical] 五省站点配置齐全：判定 `grep -c "base_url" lib/services/crawler_service.dart` ≥ 60
- [test] 全部测试通过：`flutter test`
- [manual] 运行 `flutter run -d windows`，进入岗位匹配页，点击"抓取公告"，验证真实公告被抓取并展示在列表中
