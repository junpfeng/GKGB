# 公告抓取独立工具（Dart CLI + Python 脚本）

## 核心需求
将公告抓取功能做成独立工具，方便随时调度。Dart CLI 复用 App 核心逻辑，Python 脚本作为轻量备选。双工具均支持抓取、查看、导出、统计。配套两个 Claude Code Skill 调度。

## 调研上下文

### 已有基础设施
- `lib/services/crawler_service.dart` (943行) — 完整爬虫服务，依赖 Flutter (ChangeNotifier, debugPrint)
- 67 个站点配置硬编码在 CrawlerService._allSites 常量中
- 依赖：Dio (HTTP), html (解析), sqflite_common_ffi (已有), LlmManager (AI)
- DB 表：crawl_sources, talent_policies, positions, match_results
- UI：PolicyMatchScreen 的"抓取公告"按钮 + _CrawlProgressDialog

### 技术约束
- `bin/` 下的 Dart 文件不能 import Flutter 包（ChangeNotifier, debugPrint 等）
- CLI 环境无 flutter_secure_storage，API Key 需通过环境变量传入
- sqflite_common_ffi 已在 pubspec.yaml 中

## 范围边界
- 做：CrawlerCore 提取、Dart CLI、Python 脚本、共享站点 JSON、双 Skill
- 不做：定时调度、Web API、Docker、反爬对抗

## 确认方案

### 核心思路
提取 CrawlerCore（纯 Dart，无 Flutter 依赖）作为共享核心，CrawlerService 委托给它，Dart CLI 直接调用它。站点配置提取为共享 JSON。Python 脚本独立实现同等功能。

### 锁定决策

**共享配置**：
- tool/crawl_sites.json — 67 站点配置，从 CrawlerService._allSites 提取
- 结构：[{"name":"...","province":"...","city":null,"base_url":"...","list_path":"...","policy_type":"..."},...]

**服务层重构**：
- 新增 lib/services/crawler_core.dart — 纯 Dart 爬虫核心
  - 不依赖 Flutter（无 ChangeNotifier/debugPrint/rootBundle）
  - 用 print 替代 debugPrint
  - 用回调函数 Function(String)? onProgress 替代 notifyListeners
  - 包含：HTTP 抓取、HTML 解析、链接提取、AI 解析（通过 Dio 直调 API）、去重逻辑
  - 接口：
    - CrawlerCore(Dio dio, {required String apiKey, required String baseUrl, String model})
    - Future<CrawlReport> crawlAll({Function(String)? onProgress})
    - Future<CrawlReport> crawlProvince(String province, {Function(String)? onProgress})
    - List<Map<String, dynamic>> loadSites() — 加载站点配置
    - Future<List<Map>> extractLinks(String html, String baseUrl)
    - Future<Map?> processAnnouncement(String url, String province, String? city)
    - 查看：Future<List<Map>> queryPolicies({String? province})
    - 统计：Future<Map<String, int>> getStats()
    - 导出：Future<String> exportJson({String? province}), exportCsv({String? province})
- 重构 CrawlerService：
  - 构造时创建 CrawlerCore 实例
  - crawlAllProvinces/crawlProvince 委托给 CrawlerCore
  - 保留 ChangeNotifier 进度通知
  - 站点配置从 tool/crawl_sites.json 加载（通过 rootBundle）

**Dart CLI（bin/crawler_tool.dart）**：
- 依赖：args 包（新增）
- 初始化：sqflite_common_ffi databaseFactoryFfi
- DB 路径：--db-path 参数或自动检测 App 默认路径
- 环境变量：LLM_API_KEY, LLM_BASE_URL, LLM_MODEL
- 命令：
  - --all — 抓取全部五省
  - --province 江苏,浙江 — 指定省份
  - --list — 列出 67 站点
  - --show [--province X] — 查看已抓取公告
  - --stats — 统计概览
  - --export json|csv [--province X] — 导出数据
  - --help — 帮助

**Python 脚本（tool/crawl.py）**：
- 读取 tool/crawl_sites.json
- 使用 requests + beautifulsoup4 + sqlite3(stdlib)
- LLM 调用：requests 直调 OpenAI 兼容 API
- 同等命令行参数
- tool/requirements.txt：requests, beautifulsoup4

**Skills**：
- .claude/skills/crawl-dart/SKILL.md（/crawl-dart）
  - 触发词：用 Dart 工具抓取公告、dart 爬虫
  - 流程：询问范围 → 检查环境变量 → 执行 dart run bin/crawler_tool.dart → 汇总
  - 支持操作：抓取、查看、导出、统计
- .claude/skills/crawl-py/SKILL.md（/crawl-py）
  - 触发词：用 Python 工具抓取公告、python 爬虫
  - 流程：检查 Python 环境 → pip install → 执行 tool/crawl.py → 汇总
  - 支持操作：同上

**主要技术决策**：
- CrawlerCore 无 Flutter 依赖：用回调替代 ChangeNotifier，用 print 替代 debugPrint
- 站点配置共享 JSON：单一数据源，Dart/Python/App 三端同步
- DB 共享：CLI 工具读写与 App 相同的 SQLite 文件

### 待细化
- App SQLite 数据库默认路径检测逻辑（Windows vs Android）
- Python 脚本 AI 解析 prompt 与 CrawlerCore 保持一致

### 验收标准
- [mechanical] CrawlerCore 存在：判定 `grep "CrawlerCore" lib/services/crawler_core.dart`
- [mechanical] Dart CLI 存在：判定 `test -f bin/crawler_tool.dart`
- [mechanical] Python 脚本存在：判定 `test -f tool/crawl.py`
- [mechanical] 共享配置存在且含 67 站点：判定 `python -c "import json;print(len(json.load(open('tool/crawl_sites.json'))))"`
- [mechanical] CrawlerService 委托：判定 `grep "CrawlerCore" lib/services/crawler_service.dart`
- [mechanical] Skill 目录存在：判定 `test -d .claude/skills/crawl-dart && test -d .claude/skills/crawl-py`
- [test] flutter test 全通过
- [manual] `dart run bin/crawler_tool.dart --list` 输出 67 站点
- [manual] `python tool/crawl.py --list` 输出 67 站点
