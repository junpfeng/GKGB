# 真题库收集与整理系统

## 核心需求
基于 `docs/advanced-features-design.md` 第一章，为现有题库系统增加真题维度：按地区、年份、考试类型筛选真题，支持整套试卷还原模考，以及用户贡献真题（AI 结构化）。

## 调研上下文

### 现有 questions 表结构（DB version=3）
- id, subject, category, type, content, options, answer, explanation, difficulty, created_at
- 缺少 region/year/exam_type/exam_session/is_real_exam 字段

### 现有查询接口
- `DatabaseHelper.queryQuestions(subject, category, type, limit, offset)` — 仅支持 subject/category/type 筛选
- `DatabaseHelper.randomQuestions(subject, category, count)` — 随机抽题
- `QuestionService.loadQuestions()` 直接透传 DB 参数

### 现有 UI 结构
- PracticeScreen 有 2 个 Tab（科目列表 + 错题本），科目列表 7 个硬编码卡片
- ExamScreen 支持快速组卷和自定义组卷（按科目/题数/时限）
- QuestionCard widget 可复用，支持 single/multiple/judge/subjective 四种题型

### 现有模型
- `lib/models/question.dart` — Question 类，fromDb/toDb 双向序列化
- `lib/models/user_answer.dart` — UserAnswer 类
- `lib/models/exam.dart` — Exam 类

### 索引
- `idx_questions_subject_category` 已有

## 范围边界
- 做：DB 扩展、真题筛选 UI、按地区/年份刷题、真题模考还原、用户文字贡献真题（AI 结构化）
- 不做：OCR 拍照上传（需要 ML Kit 依赖，后续迭代）、社区审核机制、贡献积分系统、跨省对比分析（数据量不足时无意义）

## 初步理解
1. **数据层**：questions 表 ALTER 增加 5 个字段 + 新增 `real_exam_papers` 表（整套试卷元数据）
2. **服务层**：扩展 QuestionService 的查询方法，新增真题试卷服务
3. **UI 层**：新增真题专区入口页（地区/年份/考试类型三级筛选），真题模考复用 ExamScreen 流程

## 待确认事项
1. 真题入口放在哪里？（PracticeScreen 新增 Tab？还是独立页面？）
2. 整套试卷还原需要新建 `real_exam_papers` 表吗？还是复用 `exams` 表加字段？
3. 用户贡献真题的 AI 结构化是否在本期实现？
4. 真题数据初始怎么来？（预置 JSON + 后续 AI 生成？）

## 确认方案

核心思路：扩展现有题库系统增加真题维度字段，新增试卷模板表，在 PracticeScreen 新增「真题」Tab 提供三级筛选练习和整卷模考，并支持用户文字贡献真题（LLM 结构化）。

### 锁定决策

**数据层：**

1. `questions` 表 ALTER 新增 5 字段（全部带 DEFAULT，存量数据安全）：
   - `region TEXT DEFAULT ''`
   - `year INTEGER DEFAULT 0`
   - `exam_type TEXT DEFAULT ''`（国考/省考/事业编/选调）
   - `exam_session TEXT DEFAULT ''`（上半年/下半年）
   - `is_real_exam INTEGER DEFAULT 0`
   - 迁移后执行 `UPDATE questions SET is_real_exam = 0 WHERE is_real_exam IS NULL` 保底

2. 新增 `real_exam_papers` 表（试卷模板，静态元数据）：
   ```sql
   CREATE TABLE real_exam_papers (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     name TEXT NOT NULL,
     region TEXT NOT NULL,
     year INTEGER NOT NULL,
     exam_type TEXT NOT NULL,
     exam_session TEXT DEFAULT '',
     subject TEXT NOT NULL,
     time_limit INTEGER NOT NULL,
     total_score REAL DEFAULT 100,
     question_ids TEXT NOT NULL,       -- JSON 数组，有序题目 ID
     score_distribution TEXT,          -- JSON 对象，每题分值（可选）
     created_at TEXT DEFAULT CURRENT_TIMESTAMP
   )
   ```

3. `exams` 表 ALTER 新增 `paper_id INTEGER DEFAULT NULL`（外键指向 real_exam_papers.id，NULL 表示自定义组卷）

4. DB version 3 → 4，`_onUpgrade` v4 迁移使用事务包裹（`db.transaction`），失败则回滚，不静默吞错

5. 新增索引：
   - `idx_questions_real_exam ON questions(is_real_exam, region, year, exam_type)`
   - `idx_real_exam_papers_filter ON real_exam_papers(exam_type, region, year)`

**服务层：**

6. 扩展 `DatabaseHelper`：
   - `queryRealExamQuestions({region, year, examType, examSession, subject, category, limit, offset})` — 参数化查询，严禁 SQL 拼接
   - `getDistinctValues(field, {where})` — 动态获取筛选项（如 SELECT DISTINCT region）
   - `real_exam_papers` CRUD 方法
   - `exams` 表新增 paper_id 相关查询

7. 扩展 `QuestionService`：
   - `loadRealExamQuestions({region, year, examType, subject, limit, offset})` — 支持分页
   - `getAvailableRegions()` / `getAvailableYears()` / `getAvailableExamTypes()`

8. 新增 `RealExamService extends ChangeNotifier`：
   - 构造函数注入 `QuestionService` + `LlmManager`（通过 ChangeNotifierProxyProvider）
   - `loadPapers({examType, region, year})` → `List<RealExamPaper>`
   - `startPaperExam(int paperId)` → 读取 question_ids 按序加载，启动 ExamService 模考流程
   - `contributeQuestion(String rawText)` → `Stream<String>` LLM 结构化解析
   - `confirmContribution(Question question)` → 入库（is_real_exam=1 + 用户填写的 region/year/exam_type）

9. LLM 调用统一通过构造函数注入的 `LlmManager`，禁止方法级传参

**UI 层：**

10. `PracticeScreen` 新增第 3 个 Tab「真题」

11. 新增 `lib/screens/real_exam_screen.dart`：
    - 真题专区主页，三级联动筛选（考试类型 → 地区 → 年份）
    - 筛选结果分两类展示：单题列表（支持分页，每页 20 条）+ 整卷列表
    - 复用 QuestionCard widget

12. 新增 `lib/screens/real_exam_paper_screen.dart`：
    - 整套试卷详情页（题目列表按原始题序 + "开始模考" 按钮）
    - 模考启动后复用 ExamScreen 的 _ExamingView 流程

13. 新增 `lib/screens/contribute_question_screen.dart`：
    - 文字粘贴区 → "AI 解析" 按钮 → LLM 流式返回 → 解析结果预览（可编辑）→ "确认入库"
    - 入库时用户选择 region/year/exam_type

14. 新增 `lib/models/real_exam_paper.dart`：RealExamPaper 模型，fromDb/toDb

15. Question model 同步扩展：
    - 新增 `region`、`year`、`examType`、`examSession`、`isRealExam` 字段
    - 同步更新 `fromDb()`、`toDb()`、`fromJson()`、`toJson()` 四个方法
    - 运行 `build_runner` 重新生成 `.g.dart`

16. `RealExamService` Provider 在 `main.dart` 注册（ChangeNotifierProxyProvider 注入依赖）

17. 预置示例真题 JSON：`assets/questions/real_exam_sample.json`（国考行测 2024 各科各 1-2 题，约 10 题 + 1 套试卷定义）

**范围边界：**
- 做：DB 扩展（事务迁移）、真题三级筛选 Tab、按地区/年份刷题（分页）、整卷模考还原、文字贡献真题（AI 结构化）、示例数据
- 不做：OCR 拍照、社区审核、贡献积分、跨省对比、修复现有代码中的 N+1 查询和 Timer 泄漏（标记为已知债务）

### 待细化
- 贡献真题的 LLM prompt 具体内容（方向：输入原始文本 → 输出 JSON 格式题目数组，包含 subject/category/type/content/options/answer/explanation）
- 示例真题 JSON 的具体题目内容（方向：国考行测 2024 各科各 1-2 题）
- contribute_question_screen 的编辑预览 UI 细节（方向：表单形式展示解析结果，允许逐字段修改）

### 验收标准
- [mechanical] questions 表新增字段存在：判定 `grep -c "is_real_exam" lib/db/database_helper.dart` >= 1
- [mechanical] real_exam_papers 表存在：判定 `grep -c "real_exam_papers" lib/db/database_helper.dart` >= 1
- [mechanical] 事务迁移：判定 `grep -c "db.transaction\|txn\." lib/db/database_helper.dart` >= 1
- [mechanical] RealExamService 存在：判定 `ls lib/services/real_exam_service.dart`
- [mechanical] 真题筛选页面存在：判定 `ls lib/screens/real_exam_screen.dart`
- [mechanical] 贡献真题页面存在：判定 `ls lib/screens/contribute_question_screen.dart`
- [mechanical] RealExamPaper 模型存在：判定 `ls lib/models/real_exam_paper.dart`
- [mechanical] Question 模型含真题字段：判定 `grep -c "isRealExam\|is_real_exam" lib/models/question.dart` >= 1
- [mechanical] Provider 注册：判定 `grep "RealExamService" lib/main.dart`
- [mechanical] 复合索引：判定 `grep "idx_questions_real_exam" lib/db/database_helper.dart`
- [test] 全量测试通过：`flutter test`
- [mechanical] 零分析错误：`flutter analyze`
- [manual] 运行 `flutter run -d windows` 验证：PracticeScreen 出现第 3 个 Tab「真题」，三级筛选可用，可选择整卷开始模考
