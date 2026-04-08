# 真题分类整理与入口适配 开发日志

## 实现日期
2026-04-08

## 实现内容

### 1. 数据层扩展

**lib/db/database_helper.dart**
- `queryQuestions()` 新增 `bool? realExamOnly` 参数，当为 true 时加入 `is_real_exam = 1` 条件
- 新增 `countRealExamByCategory({String? subject, String? category})` 方法，统计指定科目/分类下的真题数量

**lib/services/question_service.dart**
- `loadQuestions()` 新增 `bool? realExamOnly` 参数，透传至 DatabaseHelper
- 新增 `countRealExamByCategory({String? subject, String? category})` 方法，委托 DatabaseHelper 查询

**lib/services/real_exam_service.dart**
- 新增 `loadPapersGroupedByExamType()` 方法，查询全部试卷后按 examType 分组，组内按年份降序排列

### 2. PracticeScreen「科目练习」Tab 改造

**lib/screens/practice_screen.dart**
- `_SubjectList` 改为 `StatefulWidget`，在 `didChangeDependencies` 中异步预加载所有分类的真题数量并缓存在 `_realExamCounts` Map
- 每个科目分类卡片右侧增加真题数量角标（仅当数量 > 0 时显示），颜色与卡片渐变一致
- `QuestionListScreen` 顶部增加 `FilterChip`「仅看真题」，选中时重新加载 `realExamOnly=true` 的题目列表
- 真题题目卡片下方增加年份 + 考试类型小标签（当 `isRealExam == 1` 且有对应字段时显示）

### 3. RealExamScreen「真题」Tab 优化

**lib/screens/real_exam_screen.dart**
- 新增 `_quickStats` 字段缓存各考试类型题目数量
- 新增 `_loadQuickStats()` 方法，异步并行获取各 examType 的题目总数
- `build()` 顶部插入 `_buildQuickStatsBar()` widget：横向滚动的统计卡片，点击可快捷筛选对应考试类型
- 筛选结果的题目卡片：新增知识点分类标签（`q.category`），使用绿色 `#38B2AC` 与其他标签区分
- `_buildTag()` 增加可选 `color` 参数，允许不同标签使用不同颜色

### 4. ExamScreen「模拟考试」增加真题模考

**lib/screens/exam_screen.dart**
- 新增 `RealExamService`、`RealExamPaper` 的 import
- `_ExamHomeView` ListView 中快速模考区域和历史成绩之间插入 `const _RealExamSection()`
- 新增 `_RealExamSection` StatefulWidget：
  - `didChangeDependencies` 中调用 `realExamService.loadPapersGroupedByExamType()` 加载试卷
  - 按考试类型分组展示，每组展示最多 5 套试卷
  - 标题「真题模考」，副标题「选择一套完整真题开始模拟考试」
- 新增 `_PaperExamCard` widget：展示试卷名称、年份、题量、时长、科目；点击触发 `_startPaperExam()`
- `_startPaperExam()` 加载题目后调用 `ExamService.startPaperExam()` 开始整套模考

### 5. 测试修复

**test/widget_test.dart**
- 新增 `RealExamService` import 及实例，添加到 `MultiProvider` providers 列表
  （`ExamScreen` 新增了对 `RealExamService` 的 Provider 依赖）

## 验收结果

| 标准 | 结果 |
|------|------|
| `QuestionService` 含 `realExamOnly` 参数 | 通过 |
| `ExamScreen` 含「真题模考」文字 | 通过 |
| `PracticeScreen` 含 `realExamCount` / 真题字样 | 通过 |
| `flutter test` 全量通过 | 54 个测试全通过 |
| `flutter analyze` 零错误 | 通过 |

## 遇到的问题

1. **分析器警告 `unnecessary_underscores`**：`separatorBuilder: (_, __) =>` 的双下划线参数在新版 Dart 中会触发 info 级别提示，改为 `(context, i) =>` 消除。
2. **测试中 `ProviderNotFoundException`**：`_RealExamSection` 在 `didChangeDependencies` 中读取 `RealExamService`，但 widget_test.dart 的 `MultiProvider` 缺少该 Provider，补充后 54 个测试全部通过。
3. **Windows sqlite3.dll 占用**：首次运行 `flutter test` 报 `PathExistsException` 无法覆写 sqlite3.dll，删除后重试即可（已有构建产物与测试运行冲突的 Windows 特有问题，非代码问题）。
