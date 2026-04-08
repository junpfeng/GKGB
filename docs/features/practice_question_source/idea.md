# 科目练习题目来源分类

## 核心需求
科目练习的每种题型，也要区分是真题还是模拟题，真题还要按照类型、地区、年份进行划分。

## 调研上下文

### 现有数据模型
- `Question` 模型已有字段：`isRealExam`(0/1)、`region`、`year`、`examType`、`examSession`
- `questions` 数据库表已包含上述所有字段，无需 schema 变更
- `RealExamPaper` 模型用于管理完整试卷，包含 questionIds 有序列表

### 现有 UI 结构
- `PracticeScreen` 有三个 Tab：科目练习、错题本、真题
- "科目练习" Tab 按科目→题型分类展示，点击后直接进入 QuestionListScreen
- "真题" Tab 已有按考试类型/地区/年份筛选真题试卷的功能
- 当前科目练习中未区分题目来源（真题 vs 模拟题）

### 现有服务层
- `QuestionService.loadQuestions()` 支持 subject/category/type 过滤，但无 isRealExam 过滤
- `QuestionService.loadRealExamQuestions()` 支持 region/year/examType 过滤
- `ExamCategoryService` 管理用户选择的考试类型，提供动态科目列表

## 范围边界
- 做：在科目练习的题型入口处增加真题/模拟题区分，真题支持按类型、地区、年份筛选
- 不做：不改动现有"真题"Tab 的试卷浏览功能，不新增数据库表

## 初步理解
用户当前进入科目练习→选择题型后看到的是混合的题目列表。需要在这个流程中增加一层"来源选择"（真题/模拟题），选择真题后还需要能按考试类型、地区、年份进一步筛选，让练习更有针对性。

## 待确认事项
1. UI 交互方式：点击题型后先选来源，还是在题目列表页顶部加筛选器？
2. 真题的三级筛选（类型/地区/年份）是级联的还是独立的？
3. 模拟题是否需要额外的分类维度？

## 确认方案

**核心思路**：在题目列表页顶部增加来源切换（全部/真题/模拟题），选择真题时展开类型/地区/年份筛选器。

### 锁定决策

**数据层：**
- 数据模型：无新增，Question 已有 `isRealExam`、`region`、`year`、`examType` 字段
- 数据库变更：无，questions 表已包含所有所需字段
- 序列化：无变更

**服务层：**
- 修改 `QuestionService.loadQuestions()`：新增 `isRealExam`（int?）、`examType`（String?）、`region`（String?）、`year`（int?）可选参数，拼接 WHERE 条件
- 新增 `QuestionService.getAvailableRegions({String? examType})`：查询 questions 表中真题的去重地区列表
- 新增 `QuestionService.getAvailableYears({String? examType, String? region})`：查询真题的去重年份列表（降序）
- 新增 `QuestionService.getAvailableExamTypes()`：查询真题的去重考试类型列表
- LLM 调用：不涉及
- 外部依赖：无新增

**UI 层：**
- 修改页面：`QuestionListScreen`（或当前科目练习点击题型后进入的页面）
- 顶部增加 `SegmentedButton` 三态切换：全部 / 真题 / 模拟题
- 选择"真题"时，下方展开一行筛选 Chip：考试类型 | 地区 | 年份（三个独立 FilterChip/DropdownButton）
- 筛选变化时重新加载题目列表
- 状态管理：在现有页面 State 中管理筛选状态（`_sourceFilter`、`_examTypeFilter`、`_regionFilter`、`_yearFilter`），无需新 ChangeNotifier
- 组件：无新增独立 widget

**主要技术决策：**
- 筛选在 QuestionListScreen 内部管理，不新建页面
- 三个筛选条件独立组合，不级联
- 模拟题无额外分类维度
- 筛选器数据（可用地区/年份/类型）从 DB 动态查询，而非硬编码

**技术细节：**
- `_sourceFilter` 枚举：`all` / `realExam` / `simulated`
- 切换来源时重置类型/地区/年份筛选
- 筛选 Chip 展示动态查询结果，带"全部"选项
- SQL 查询示例：`WHERE is_real_exam = 1 AND exam_type = ? AND region = ? AND year = ?`（参数为 null 时不加对应条件）

**范围边界：**
- 做：QuestionListScreen 增加来源切换和真题筛选
- 不做：不改动"真题"Tab 试卷浏览、不新增数据库表、不改动模拟题分类

### 待细化
- 筛选 Chip 的具体视觉样式（颜色/圆角），由实现引擎参照现有 UI 风格决定
- 无可用真题时的空状态提示文案

### 验收标准
- [mechanical] QuestionService 新增筛选参数：判定 `grep -n "isRealExam" lib/services/question_service.dart`
- [mechanical] QuestionListScreen 包含 SegmentedButton：判定 `grep -n "SegmentedButton" lib/screens/question_list_screen.dart`
- [test] 全量测试通过：`flutter test`
- [mechanical] 静态分析通过：`flutter analyze`
- [manual] 运行 `flutter run -d windows`，进入科目练习 → 任一题型，验证可切换全部/真题/模拟题，选真题后可按类型/地区/年份筛选
