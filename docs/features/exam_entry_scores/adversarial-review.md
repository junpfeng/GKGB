# 对抗性审查：进面分数线分析（exam_entry_scores）

审查对象：`docs/features/exam_entry_scores/idea.md` 的"确认方案"部分
审查基准：`.claude/rules/constitution.md` 架构约束 + 现有代码模式（match_service / database_helper v12）
审查日期：2026-04-08

---

## 严重问题（必须修改）

### [CRITICAL-1] 爬虫请求间隔仅在方案文字层面承诺，无架构级约束

**攻击面**：方案写了"请求间隔 >= 2s，携带 User-Agent"，但 `fetchScores` 是 Service 层的一个普通 async 方法。对比 `MatchService` 的 `importFromUrl`（逐次 `await Future.delayed(const Duration(seconds: 2))`），每次 import 只抓一个 URL，而 `fetchScores` 需要批量爬取多省多年数据。方案没有说明：

- 批量爬取时如何在循环内强制 2s 间隔（如果是 `for` 循环内遗漏 delay 就违宪）
- 是否有全局节流器（throttle/rate limiter），防止多次调用 `fetchScores` 并发触发
- 用户连续点击"爬取"按钮时是否有防重入（`_isLoading` 锁），MatchService 里用了 `_isLoading` / `_isMatching` 双锁，方案未提及

**改进建议**：在 Service 设计中明确增加：(1) 全局 rate limiter 或 Dio Interceptor 强制 >= 2s/request；(2) `_isFetching` 防重入锁 + UI 层 disable 按钮；(3) 单测验证间隔约束。

---

### [CRITICAL-2] DB migration v12->v13 无回滚方案，且 _createDB 和 _onUpgrade 双写一致性未提及

**攻击面**：现有 `database_helper.dart` 模式要求：
1. `_createDB` 中包含新表的 CREATE TABLE（全量建库）
2. `_onUpgrade` 中 `if (oldVersion < 13)` 块执行增量 CREATE TABLE IF NOT EXISTS
3. 索引在 `_createDB` 末尾的索引区和 `_onUpgrade` 块中双写

方案只写了"新增 exam_entry_scores 表，version 12->13"，没有明确：
- `_createDB` 和 `_onUpgrade` 双处同步添加（遗漏任一处就导致全新安装或升级安装缺表）
- 索引的双写
- 回滚策略（SQLite 不支持 DROP COLUMN，但可以 DROP TABLE 回滚）

**改进建议**：在任务拆解中明确要求"_createDB 和 _onUpgrade(oldVersion < 13) 同步添加表和索引"，并注明回滚方式为 `DROP TABLE IF EXISTS exam_entry_scores`。

---

### [CRITICAL-3] 缺少 exam_entry_scores 表的索引设计

**攻击面**：方案的核心查询场景包括：
- `loadScores({province, city, year, examType})` — 四维筛选
- `getHeatRanking({province, year, examType})` — 三维聚合
- `getScoreTrend({positionName/department, province})` — 按岗位名/部门+省份查趋势

宪法要求"SQLite 查询必须建立适当索引，题库查询响应 < 100ms"。方案字段定义了 18 个字段但零索引设计。当数据量达到数万条（4省 x 6年 x 数百岗位），无索引的全表扫描会违反 100ms 约束。

**改进建议**：至少设计以下索引：
- `idx_entry_scores_filter ON exam_entry_scores(exam_type, province, year)` — 覆盖主筛选
- `idx_entry_scores_city ON exam_entry_scores(province, city, year)` — 城市维度
- `idx_entry_scores_trend ON exam_entry_scores(province, position_name, year)` 或 `(province, department, year)` — 趋势查询

---

## 高优问题（强烈建议修改）

### [HIGH-1] ExamEntryScore 与 positions 表字段高度重复，未说明不复用的理由

**攻击面**：`positions` 表已有 position_name, position_code, department, recruit_count, education_req, degree_req, major_req, political_req, work_exp_req, other_req 等完全相同语义的字段。方案决策"独立模块，不与岗位匹配模块耦合"是合理的架构判断，但存在以下风险：

- 两套模型的字段命名是否保持一致（如 positions 用 `position_name`，ExamEntryScore 也用 `positionName`，Dart 侧一致但 DB 列名需对齐）
- 未来如果需要"分数线匹配"功能（用户画像 vs 分数线岗位条件），两套独立表会导致匹配逻辑重复
- 冗余存储的维护负担——同一岗位条件的 schema 变更需要改两处

**改进建议**：在方案中明确记录"不复用 positions 表"的理由（如：数据来源不同、生命周期不同、避免 positions 表膨胀），并约定 DB 列名与 positions 表保持相同命名风格，为未来可能的合并预留兼容性。

---

### [HIGH-2] minEntryScore / maxEntryScore 类型为 double，但未处理空值和异常值

**攻击面**：方案定义 `minEntryScore: double` 和 `maxEntryScore: double` 为非空字段。但爬取场景中：

- 某些岗位可能只公布最低分（无最高分），或只有综合分（无分别）
- 爬取解析失败时可能得到 0.0 或负值
- 不同考试类型分数量纲不同（行测百分制 vs 申论百分制 vs 综合分数 200+ 分）

如果 `minEntryScore` 是 NOT NULL，爬取到缺失值时要么存 0（脏数据污染排行）要么抛异常丢失整条数据。

**改进建议**：(1) `minEntryScore` 和 `maxEntryScore` 改为 nullable（double?），DB 列允许 NULL；(2) 增加 `scoreType` 字段标识分数类型（行测/申论/总分）；(3) 热度排行中过滤 NULL 分数记录。

---

### [HIGH-3] 爬取数据无去重机制，重复爬取同一省份+年份会产生重复记录

**攻击面**：`fetchScores({province, examType, year})` 方法没有说明去重策略。用户可能多次点击爬取同一组合的数据。如果每次都 INSERT，会导致：

- 列表页出现重复条目
- 热度排行和趋势分析数据被污染（同一岗位权重翻倍）
- 数据量不必要膨胀

**改进建议**：(1) 表增加 UNIQUE 约束，如 `UNIQUE(province, city, year, exam_type, position_code)` 或等效业务主键；(2) 爬取时使用 `INSERT OR REPLACE` 或先查后更新；(3) 增加 `updatedAt` 字段追踪数据更新时间。

---

### [HIGH-4] ListView 未明确使用 builder 模式，热度排行柱状图可能一次性加载全部数据

**攻击面**：宪法要求"列表页使用 ListView.builder 懒加载，禁止一次性加载全部数据"。方案 UI 层描述了"岗位分数线列表"和"热度排行视图"，但：

- 未明确列表使用 `ListView.builder`
- `loadScores` 方法返回值未提及分页（无 offset/limit 参数）
- 热度排行如果查全省所有岗位的平均分做排序，数据量可能很大
- `getHeatRanking` 和 `getScoreTrend` 的返回数据量未设上限

**改进建议**：(1) `loadScores` 增加分页参数 `{int offset = 0, int limit = 50}`；(2) UI 明确使用 `ListView.builder`；(3) 热度排行限制 TOP N（如 TOP 50）。

---

### [HIGH-5] notifyListeners 调用时机未规划，缺少 loading/error 状态管理

**攻击面**：对比 `MatchService` 模式，它在每个异步操作前后都有 `_isLoading = true/false; notifyListeners()` 的 try/finally 模式。方案的 `ExamEntryScoreService` 列出了四个核心方法但未提及：

- 每个方法的 loading 状态切换和 notifyListeners 调用点
- 错误状态（`_error` 字段）的管理——爬取失败时 UI 如何感知
- `fetchScores` 是长时间网络操作，如果不在开始时 notify loading，UI 无反馈

**改进建议**：在 Service 设计中明确状态字段：`_isLoading`、`_isFetching`（区分本地加载和网络爬取）、`_error`，并在方法签名注释中标注 notifyListeners 调用点。

---

## 低优问题（建议改进）

### [LOW-1] fetchedAt 字段类型为 String?，不利于按时间查询和排序

**攻击面**：`fetchedAt: String?` 存储抓取时间。如果存为自由格式字符串，跨记录的时间比较和"只保留最新抓取"逻辑难以实现。

**改进建议**：使用 ISO 8601 格式（`DateTime.now().toIso8601String()`），并在方案中注明格式约定，与现有表的 `created_at TEXT DEFAULT CURRENT_TIMESTAMP` 保持一致。可以直接用 `DEFAULT CURRENT_TIMESTAMP`。

---

### [LOW-2] 平台一致性：Windows 和 Android 爬虫行为差异未讨论

**攻击面**：
- Windows 端通过 Dio 直接请求没有问题
- Android 端可能受限于网络安全配置（AndroidManifest.xml 的 `android:usesCleartextTraffic`）
- 某些目标网站可能对移动端 User-Agent 返回不同内容或拦截
- 后台爬取时 Android 的后台任务限制可能导致长时间爬取被系统 kill

**改进建议**：明确 Android 端的网络安全配置要求；考虑爬取任务的超时和断点续传；User-Agent 根据平台差异化设置。

---

### [LOW-3] 验收标准缺少数据完整性和边界条件的测试项

**攻击面**：当前验收标准全部是 mechanical 或 manual 检查，缺少：

- 去重逻辑的测试（重复 INSERT 同一岗位不产生重复记录）
- 空值/异常值处理的测试（分数为 null、为 0、为负值）
- 大数据量分页的测试
- 爬取失败 graceful degradation 的测试

**改进建议**：增加至少 2-3 个 `[test]` 类型验收标准覆盖去重、空值处理、分页查询。

---

### [LOW-4] sourceUrl 字段存在但未说明如何防止存储恶意 URL 或过长内容

**攻击面**：爬取来源 URL 直接存入 DB，如果后续 UI 层将其作为可点击链接，存在 XSS 或意外跳转风险（虽然 Flutter 原生 UI 不像 WebView 那样易受 XSS，但 `url_launcher` 打开恶意链接仍有风险）。

**改进建议**：对 sourceUrl 做基本校验（必须以 http/https 开头，长度限制），在 UI 展示时使用 `url_launcher` 的安全模式。

---

## 确认无问题的部分

- **分层架构遵从**：Model（json_serializable + fromDb/toDb）-> Service（ChangeNotifier）-> Screen 的三层结构与现有模式一致，未出现反向依赖。
- **Provider 注册**：方案明确提到在 main.dart 注册 ChangeNotifierProvider，与现有 18 个 Provider 的注册模式一致。
- **LLM 不涉及**：明确标注本功能不涉及 LLM 调用，避免了不必要的 LlmManager 依赖。
- **与现有模块解耦**：明确不与岗位匹配模块耦合，避免了双向依赖风险。
- **fl_chart 复用**：使用项目已有的 fl_chart 依赖做可视化，无需新增依赖。
- **home_screen 入口**：与现有页面入口添加模式一致。
- **API Key 安全**：本功能不涉及 API Key 存取，无此类风险。
