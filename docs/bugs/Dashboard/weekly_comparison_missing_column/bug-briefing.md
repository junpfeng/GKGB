# Bug: Dashboard 数据看板空白

## 现象
数据看板显示"暂无学习数据"空状态，即使应该展示带零值的完整看板。

## 根因
`queryWeeklyComparison` 在 `user_answers` 表上直接添加 `AND exam_type IN (...)` 过滤条件，
但 `user_answers` 表没有 `exam_type` 列。当 `ExamCategoryService` 有活跃考试类型时，
SQL 查询抛出异常，导致 `refreshDashboard()` 整体失败。

## 修复策略
将 `queryWeeklyComparison` 中的 `exam_type` 过滤改为 JOIN `questions` 表后通过 `q.exam_type` 过滤，
与 `querySubjectRadarData` 的实现模式一致。
