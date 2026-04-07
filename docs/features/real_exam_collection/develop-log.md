# 真题库收集与整理系统 - 实现日志

## 实现日期
2026-04-07

## 新增文件

| 文件路径 | 说明 |
|---------|------|
| `lib/models/real_exam_paper.dart` | 真题试卷模板模型（fromDb/toDb/fromJson/toJson） |
| `lib/models/real_exam_paper.g.dart` | build_runner 自动生成 |
| `lib/services/real_exam_service.dart` | 真题服务（试卷管理、AI 贡献、示例数据导入） |
| `lib/screens/real_exam_screen.dart` | 真题专区主页（三级联动筛选 + 单题/整卷列表） |
| `lib/screens/real_exam_paper_screen.dart` | 试卷详情页（题目列表 + 开始模考） |
| `lib/screens/contribute_question_screen.dart` | 贡献真题页（文字粘贴→AI解析→编辑预览→入库） |
| `assets/questions/real_exam_sample.json` | 示例真题（国考行测2024，10题+1套试卷） |

## 修改文件

| 文件路径 | 变更内容 |
|---------|---------|
| `lib/models/question.dart` | 新增 region/year/examType/examSession/isRealExam 5个字段，更新 fromDb/toDb |
| `lib/models/question.g.dart` | build_runner 重新生成（含新字段） |
| `lib/db/database_helper.dart` | v3→v4 事务迁移（ALTER questions + CREATE real_exam_papers + ALTER exams + 索引），新增真题查询/统计/筛选/CRUD 方法 |
| `lib/services/question_service.dart` | 新增 loadRealExamQuestions/countRealExamQuestions/getAvailableRegions/Years/ExamTypes |
| `lib/services/exam_service.dart` | 新增 startPaperExam 方法（从真题试卷启动模考，不随机抽题） |
| `lib/screens/practice_screen.dart` | Tab 数从 2 改为 3，新增「真题」Tab |
| `lib/main.dart` | 注册 RealExamService（ChangeNotifierProxyProvider2 注入 QuestionService + LlmManager） |
| `pubspec.yaml` | assets 新增 real_exam_sample.json |

## 关键决策说明

### 数据层
- **v4 事务迁移**：使用 `db.transaction((txn) async { ... })` 包裹所有 ALTER/CREATE/INDEX 操作，失败时整体回滚
- **getDistinctValues 白名单校验**：field 参数仅允许 `region/year/exam_type/exam_session/subject`，防止 SQL 注入
- **questions 表 5 字段全部带 DEFAULT**：存量数据安全，迁移后执行 `UPDATE SET is_real_exam=0 WHERE IS NULL` 保底
- **real_exam_papers.question_ids 存 JSON 数组**：保持有序题序，查询时按序加载

### 服务层
- **RealExamService 构造函数注入 QuestionService + LlmManager**：通过 ChangeNotifierProxyProvider2 注入，LLM 调用统一走 LlmManager
- **ExamService.startPaperExam**：新增方法接收已确定的题目列表，不走 randomQuestions，支持 paper_id 外键关联
- **示例数据导入采用 ID 映射**：JSON 中 question_ids 为序号（1-N），导入后映射为实际 DB ID

### UI 层
- **三级联动筛选**：考试类型→地区→年份，每级选择后动态加载下级选项（通过 getDistinctValues 查询）
- **结果分两类展示**：整卷列表在上、单题列表在下，单题支持分页（每页20条）
- **贡献真题 AI 解析**：LLM prompt 输出 JSON 数组格式，支持 markdown 代码块包裹的 JSON 自动提取
- **编辑预览采用展开/折叠**：默认折叠只显示题目摘要，展开后可逐字段修改

### 待细化项补充设计
- **LLM prompt**：指定输出 JSON 数组格式，包含 subject/category/type/content/options/answer/explanation/difficulty 字段，处理 markdown 代码块包裹
- **示例真题内容**：国考行测2024上半年，言语理解×2 + 数量关系×2 + 判断推理×2 + 资料分析×2 + 常识判断×2 = 10题
- **编辑预览 UI**：表单形式，展开后可修改所有字段（科目、分类、内容、选项、答案、难度、解析），支持删除单题

## 验收状态

| 验收项 | 状态 |
|-------|------|
| questions 表新增字段 | ✅ |
| real_exam_papers 表 | ✅ |
| 事务迁移 | ✅ |
| RealExamService | ✅ |
| 真题筛选页面 | ✅ |
| 贡献真题页面 | ✅ |
| RealExamPaper 模型 | ✅ |
| Question 真题字段 | ✅ |
| Provider 注册 | ✅ |
| 复合索引 | ✅ |
| flutter test 全量通过 | ✅ (37/37) |
| flutter analyze 零错误 | ✅ |

## 遇到的问题及解决

1. **DropdownButtonFormField `value` 参数已废弃**：Flutter 3.x 新版本将 `value` 改为 `initialValue`，修改所有 DropdownButtonFormField 使用 `initialValue`
2. **flutter/dart 命令在 bash shell 中找不到**：Windows 环境需手动添加 `/c/flutter/bin` 到 PATH
3. **RealExamService._questionService 未使用警告**：将 ensureSampleData 中调用 `_questionService.ensureSampleData()` 确保普通题库也已导入，消除 unused_field 警告
