# 公告抓取独立工具 — 实现日志

## 实现日期
2026-04-09

## 基于方案
`docs/features/crawler_cli/idea.md` → 确认方案

## 实现清单

### 1. 共享站点配置
- **文件**: `tool/crawl_sites.json` + `assets/config/crawl_sites.json`（内容一致）
- 从 `CrawlerService._allSites` 提取全部 **67 个站点**
- JSON 数组，每项含 `name/province/city/base_url/list_path/policy_type`
- 五省分布：江苏 15、浙江 13、上海 3、安徽 18、山东 18

### 2. CrawlerCore（纯 Dart）
- **文件**: `lib/services/crawler_core.dart`
- 不依赖任何 `package:flutter/` 包
- `CrawlSiteConfig` 类：支持 `fromJson/toJson`，含 `listUrl` getter
- `CrawlReport` 类：抓取报告（totalSources/successSources/failedSources/newPolicies/newPositions/errors）
- `CrawlerCore` 类：
  - 构造：`CrawlerCore(Dio, Database, {apiKey, baseUrl, model, sites})`
  - 站点加载：`loadSitesFromFile(path)` / `setSites(list)`
  - 抓取：`crawlAll()` / `crawlProvince(province)` — 均支持 `onProgress` 回调
  - 进度：`print()` 替代 `debugPrint()`，回调 `Function(String)?` 替代 `ChangeNotifier`
  - AI 调用：通过 Dio 直调 OpenAI 兼容 API（`_callLlm`），不依赖 `LlmManager`
  - DB 操作：通过传入的 `Database` 实例直接查询/写入
  - 查看/统计/导出：`queryPolicies()` / `getStats()` / `exportJson()` / `exportCsv()`
- AI prompt 与原 `CrawlerService` 保持一致

### 3. CrawlerService 重构
- **文件**: `lib/services/crawler_service.dart`
- 删除硬编码 `_allSites` 常量（509 行）和 `CrawlSiteConfig` / `CrawlReport` 类定义
- 通过 `export 'crawler_core.dart'` 重新导出 `CrawlSiteConfig` / `CrawlReport`，保持外部 import 兼容
- 内部创建 `CrawlerCore` 实例委托抓取逻辑
- 保留 `ChangeNotifier` 行为（`isCrawling/progress/currentStatus/policiesFound`）
- 站点配置通过 `rootBundle.loadString('assets/config/crawl_sites.json')` 加载
- 静态方法 `provinces/getSitesByProvince/totalSiteCount` 通过 `loadStaticSites()` 初始化
- 新增 `LlmManager.getActiveProviderConfig()` 方法获取 API 配置传给 CrawlerCore
- 新增 `OpenAiCompatibleProvider` 上的 `currentApiKey/currentModel/currentBaseUrl` 公共访问器

### 4. Dart CLI
- **文件**: `bin/crawler_tool.dart`
- 依赖：`args` 包（已添加到 pubspec.yaml dependencies）
- 初始化：`sqflite_common_ffi` → `databaseFactoryFfi`
- DB 路径检测：
  - Windows: `%APPDATA%/com.example/exam_prep_app/databases/exam_prep.db`
  - 回退到当前目录 `exam_prep.db`
  - 支持 `--db-path` 手动指定
- 环境变量：`LLM_API_KEY`、`LLM_BASE_URL`、`LLM_MODEL`
- 命令：`--all`、`--province`、`--list`、`--show`、`--stats`、`--export json|csv`、`--help`
- 自动创建 `talent_policies` 和 `crawl_sources` 表（`_ensureTables`）

### 5. Python 脚本
- **文件**: `tool/crawl.py` + `tool/requirements.txt`
- 依赖：`requests>=2.31.0`、`beautifulsoup4>=4.12.0`
- 同等命令行参数（`argparse`）
- 使用 `sqlite3` 标准库操作同一数据库
- LLM 通过 `requests` 直调 OpenAI 兼容 API
- AI prompt 与 CrawlerCore 完全一致
- 链接提取逻辑（关键词列表、URL 规范化）与 Dart 版保持同步

### 6. Skills
- **文件**: `.claude/skills/crawl-dart/SKILL.md`（触发：`/crawl-dart`）
- **文件**: `.claude/skills/crawl-py/SKILL.md`（触发：`/crawl-py`）
- 流程：解析用户意图 → 检查环境 → 构建命令参数 → Bash 执行 → 解读输出

### 7. pubspec.yaml 变更
- 新增 `args: ^2.6.0`（runtime dependency，CLI 使用）
- 新增 `sqflite_common: ^2.5.4+5`（显式声明，消除 depend_on_referenced_packages）
- 新增 asset 注册：`assets/config/crawl_sites.json`

## 待细化部分补充设计

### App SQLite 数据库默认路径检测逻辑
- **Windows**: 优先检查 `%APPDATA%/com.example/exam_prep_app/databases/exam_prep.db`，回退到当前目录
- **Linux/macOS**: 优先检查 `~/.local/share/exam_prep_app/exam_prep.db`，回退到当前目录
- 均支持 `--db-path` 手动覆盖

### Python 脚本 AI 解析 prompt 一致性
- 链接提取 prompt：完全复刻 CrawlerCore 的 `aiExtractLinks` prompt
- 公告信息解析 prompt：完全复刻 CrawlerCore 的 `_processAnnouncementLink` 中的 info_prompt
- JSON 提取逻辑（`find('[')` / `find('{')` + `rfind(']')` / `rfind('}')`）保持一致

## 验证结果
- `flutter analyze`: 0 error, 0 new warning（仅 1 个 pre-existing warning）
- `flutter test`: 54/54 全部通过
- `tool/crawl_sites.json`: 67 个站点
- Skills 已注册：`/crawl-dart`、`/crawl-py` 在 Claude Code 中可见

## 文件变更汇总

| 操作 | 文件 |
|------|------|
| 新增 | `lib/services/crawler_core.dart` |
| 新增 | `bin/crawler_tool.dart` |
| 新增 | `tool/crawl.py` |
| 新增 | `tool/requirements.txt` |
| 新增 | `tool/crawl_sites.json` |
| 新增 | `assets/config/crawl_sites.json` |
| 新增 | `.claude/skills/crawl-dart/SKILL.md` |
| 新增 | `.claude/skills/crawl-py/SKILL.md` |
| 重构 | `lib/services/crawler_service.dart` |
| 修改 | `lib/services/llm/llm_manager.dart`（新增 `getActiveProviderConfig`） |
| 修改 | `lib/services/llm/openai_compatible_provider.dart`（新增公共访问器） |
| 修改 | `pubspec.yaml`（新增依赖 + asset） |
