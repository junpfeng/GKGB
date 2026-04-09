# 人才引进公告抓取功能 - 开发日志

## 实现日期
2026-04-09

## 新增文件
| 文件 | 说明 |
|------|------|
| `lib/services/crawler_service.dart` | 公告抓取服务（CrawlerService），含 67 个五省政府人社网站配置、通用爬虫+AI解析逻辑 |
| `docs/features/talent_recruit_notice/develop-log.md` | 本开发日志 |

## 修改文件
| 文件 | 变更内容 |
|------|----------|
| `lib/db/database_helper.dart` | version 19→20；新增 `crawl_sources` 表（站点配置+抓取状态）；新增 CRUD 方法；新增索引 |
| `lib/main.dart` | 注册 CrawlerService 为 ChangeNotifierProxyProvider2（依赖 LlmManager + MatchService） |
| `lib/screens/policy_match_screen.dart` | AppBar 添加"抓取公告"按钮（cloud_download 图标）；新增 `_CrawlProgressDialog` 进度对话框 |
| `test/widget_test.dart` | 添加 CrawlerService Provider 以修复测试 |

## 关键决策说明

### 1. 站点配置方式：硬编码 Dart 常量
将 67 个目标站点配置硬编码在 `CrawlerService._allSites` 常量列表中，同时在首次运行时同步到 `crawl_sources` 表。原因：
- 站点列表相对固定，无需动态增删
- 硬编码便于代码审查和版本控制
- 数据库表用于记录抓取状态（last_crawled_at, status）

### 2. URL 来源：WebSearch 研究确认
所有 67 个站点 URL 通过 WebSearch 工具逐省研究确认，确保为真实政府网站域名：
- 江苏 15 站：省人社厅 + 省考试网 + 13 地级市
- 浙江 13 站：省人社厅 + 省考试网 + 11 地级市
- 上海 3 站：市人社局 + 考试院 + 21世纪人才网
- 安徽 18 站：省人社厅 + 省考试网 + 16 地级市
- 山东 18 站：省人社厅 + 省考试网 + 16 地级市

### 3. 列表页路径：通用公告/通知栏
各站点的 `list_path` 指向公告通知列表页（如 `/xxfb/tzgg/`、`/col/colXXX/`、`/rsj/tzgg/`），是政府网站发布招聘公告的常见入口。不同站点的路径结构各异（江苏用 col/col 体系，安徽用 rsj/tzgg 体系等），在链接提取失败时由 AI 回退处理。

### 4. 抓取策略：启发式 + AI 双重提取
- 先用 HTML 关键词匹配（公告/招聘/引进/人才/事业单位/选调/招录）提取 `<a>` 标签
- 若启发式提取为空，则将页面 HTML 发给 LLM 进行结构分析
- 每个站点最多处理前 10 条公告链接，避免过量请求

### 5. 数据复用：完全复用现有模型和匹配引擎
- 复用 `TalentPolicy` 模型和 `talent_policies` 表存储抓取的公告
- 复用 `MatchService.addPolicyIfNotExists()` 进行去重入库
- 复用 `MatchService.aiParsePolicy()` 进行岗位提取
- 抓取完成后自动刷新 `MatchService` 的公告列表

### 6. 请求间隔：严格遵守宪法 ≥2s
- 站点间隔 ≥2s
- 同一站点内的公告链接间隔 ≥2s

### 7. 公告类型覆盖
- `rencaiyinjin`（人才引进）：各省市人社局主站
- `shiyebian`（事业编招聘）：省人事考试网

## 数据库变更
- 版本：19 → 20
- 新增表：`crawl_sources`（id, name, province, city, base_url, list_path, policy_type, last_crawled_at, status, enabled）
- 新增索引：`idx_crawl_sources_province`（province, city）

## 验收检查
- [x] `grep -r "CrawlerService" lib/services/` → 存在
- [x] `grep "crawl_sources" lib/db/database_helper.dart` → 存在
- [x] `grep "CrawlerService" lib/main.dart` → 存在
- [x] 站点配置 67 个（江苏15+浙江13+上海3+安徽18+山东18）
- [x] `flutter test` → 54 tests passed
- [x] `flutter analyze` → 0 新增错误（仅 2 个预存 info/warning）
