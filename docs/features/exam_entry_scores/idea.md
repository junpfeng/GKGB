# 进面分数线分析（exam_entry_scores）

## 核心需求
找出江浙沪和山东，省考、国考各个地级市各个岗位 2020-2025年间的进面名单，包含职位信息、专业信息、个人条件等要求，最低进面分数、最高进面分数等，用于分析各个岗位的热度。

## 调研上下文

### 已有相关模型
- `ExamCategory`（exam_category.dart）：考试类型配置（国考/省考等），含 scope、subTypes、defaultSubjects，静态定义非 DB
- `RealExamPaper`（real_exam_paper.dart）：真题试卷模板，有 region、year、examType 字段，json_serializable
- `TalentPolicy` + `positions` 表：人才引进公告及岗位表，结构最相似——有 province/city、education_req、major_req 等条件字段
- `MatchResult`：岗位匹配结果，有 matchScore、matchedItems 等

### 已有 DB 结构（v12）
- `positions` 表已有岗位条件字段（education_req、degree_req、major_req、age_req、political_req 等）
- `exam_calendar` 表有考试日程信息
- 但没有"进面分数线"相关表

### 架构模式
- Model 层：json_serializable + fromDb/toDb 双模式
- Service 层：ChangeNotifier 风格，通过 Provider 注入
- DB 层：DatabaseHelper 单例，version 递增迁移

## 范围边界
- 做：进面分数线数据的存储、展示、筛选、热度分析
- 不做：待确认

## 初步理解
用户希望建立一个"公考进面分数线数据库"，涵盖：
1. **数据维度**：省份（江浙沪+山东）、考试类型（国考/省考）、年份（2020-2025）、地级市、具体岗位
2. **岗位信息**：职位名称、部门、招录人数、专业要求、学历要求、其他条件
3. **分数信息**：最低进面分数、最高进面分数（可能还有平均分）
4. **分析目标**：通过分数线数据分析岗位竞争热度，帮助用户选岗决策

## 待确认事项
1. 数据来源方式
2. 功能边界与交互设计
3. 热度分析维度
4. 与现有模块的关系

## 确认方案

核心思路：从公开网站爬取江浙沪+山东的国考/省考进面分数线数据（2020-2025），本地存储后提供多维度筛选查询和热度分析。

### 锁定决策

数据层：
- 新增 Model：ExamEntryScore（json_serializable + fromDb/toDb）
  字段：
  - id: int?（主键）
  - province: String（省份：江苏/浙江/上海/山东）
  - city: String（地级市）
  - year: int（2020-2025）
  - examType: String（国考/省考）
  - department: String（招录单位）
  - positionName: String（岗位名称）
  - positionCode: String?（岗位代码）
  - recruitCount: int?（招录人数，爬取缺失时为 null）
  - majorReq: String?（专业要求）
  - educationReq: String?（学历要求）
  - degreeReq: String?（学位要求）
  - politicalReq: String?（政治面貌）
  - workExpReq: String?（工作经验）
  - otherReq: String?（其他条件）
  - minEntryScore: double?（最低进面分数，nullable 防止爬取缺失时脏数据）
  - maxEntryScore: double?（最高进面分数，nullable）
  - entryCount: int?（进面人数）
  - sourceUrl: String?（数据来源链接，校验 http/https 开头）
  - fetchedAt: String?（抓取时间，ISO 8601 格式）
- 数据库变更：
  - 新增 exam_entry_scores 表，version 12→13
  - _createDB 和 _onUpgrade(oldVersion < 13) 双处同步添加表和索引
  - UNIQUE 约束：UNIQUE(province, city, year, exam_type, position_code, department) 防重复爬取
  - 使用 INSERT OR REPLACE 作为 upsert 策略，增加 updated_at 字段追踪更新
  - 索引设计：
    - idx_entry_scores_filter ON (exam_type, province, year) — 主筛选
    - idx_entry_scores_city ON (province, city, year) — 城市维度
    - idx_entry_scores_trend ON (province, position_name, year) — 趋势查询
- 不复用 positions 表的理由：数据来源不同（爬取 vs 公告导入）、生命周期不同（历史分数线 vs 当期招录）、避免 positions 表膨胀；DB 列名与 positions 保持相同命名风格

服务层：
- 新增 ExamEntryScoreService（extends ChangeNotifier）
  状态字段：
  - _isLoading: bool（本地数据加载中）
  - _isFetching: bool（网络爬取中，防重入锁）
  - _error: String?（错误信息，供 UI 展示）
  - _scores: List<ExamEntryScore>
  核心方法：
  - fetchScores({province, examType, year}) → 从网络爬取（_isFetching 防重入锁 + UI disable 按钮）
  - loadScores({province, city, year, examType, int offset=0, int limit=50}) → 本地分页查询
  - getHeatRanking({province, year, examType, int topN=50}) → 热度排行 TOP N
  - getScoreTrend({positionName/department, province}) → 年度趋势数据
  - 每个方法开始/结束时切换 loading 状态 + notifyListeners()，try/finally 模式
- 爬取策略：
  - Dio Interceptor 级别强制节流 ≥2s/request（全局 rate limiter）
  - _isFetching 防重入锁，爬取进行中拒绝新请求
  - 遵守 robots.txt，携带 User-Agent
  - 爬取失败 toast 提示 + 支持重试
- 目标数据源：各省人事考试网、国家公务员局公开公示数据
- LLM 调用：不涉及

UI 层：
- 新增页面：ExamEntryScoresScreen
  - 顶部：筛选栏（考试类型+省份 → 年份+城市）
  - 主体：岗位分数线列表（ListView.builder 懒加载 + 分页，岗位名、单位、分数区间、招录数）
  - 点击进入详情页/底部弹窗：完整条件 + 历年分数趋势图
  - Tab/切换：列表视图 / 热度排行视图
- 热度分析（使用已有 fl_chart）：
  - 热度排行：按平均进面分数排序的柱状图
  - 年度趋势：同一岗位类型多年分数线折线图
- 状态管理：新增 ChangeNotifierProvider<ExamEntryScoreService>，在 main.dart 注册
- 入口：home_screen 导航中添加入口

主要技术决策：
- 数据获取选择网络爬取，遵循宪法安全约束（robots.txt、≥2s间隔、User-Agent）
- 独立模块，不与岗位匹配模块耦合
- 使用 fl_chart 做可视化（项目已有依赖）

范围边界：
- 做：数据爬取+存储、多维筛选查询、热度排行、年度趋势图
- 不做：与用户画像联动、岗位推荐、报录比分析（无报名人数数据）

### 待细化
- 具体爬取目标网站 URL 和解析规则：由实现引擎根据实际网站结构确定
- 详情页/弹窗的具体 UI 布局：由实现引擎参考 match_reason_card 风格设计
- 爬取失败的重试与错误提示策略：方向为 toast 提示 + 支持重试

### 验收标准
- [mechanical] ExamEntryScore model 存在：判定 `grep -r "class ExamEntryScore" lib/models/`
- [mechanical] DB version bump 到 13：判定 `grep "version: 13" lib/db/database_helper.dart`
- [mechanical] Service 注册 Provider：判定 `grep "ExamEntryScoreService" lib/main.dart`
- [mechanical] 新页面存在：判定 `ls lib/screens/exam_entry_scores_screen.dart`
- [test] 基本功能测试：`flutter test test/exam_entry_score_test.dart`
- [manual] 筛选与展示：运行 `flutter run -d windows` 验证 `进入分数线页面，选择省份+考试类型，能展示列表和热度图`
