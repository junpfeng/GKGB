# 修复日志：Dashboard 数据看板空白

## 根因
两层问题叠加：

1. **SQL 查询错误**：`queryWeeklyComparison` 在 `user_answers` 表上直接过滤 `exam_type` 列，
   但该列不存在于 `user_answers`（应通过 JOIN `questions` 表过滤）。
2. **架构脆弱性**：`refreshDashboard()` 使用 `Future.wait` 并行 7 个查询，任何一个失败都导致
   `_cachedData` 为 null，整个看板显示空状态。

## 修复

### Fix 1: queryWeeklyComparison SQL 修正
- `FROM user_answers` → `FROM user_answers ua JOIN questions q ON ua.question_id = q.id`
- `AND exam_type IN (...)` → `AND q.exam_type IN (...)`

### Fix 2: refreshDashboard 容错重构
- 将 `Future.wait` 替换为逐个 `_safeLoad()` 调用
- 每个查询独立 try-catch，失败时返回安全默认值（0/空列表/空 Map）
- 即使部分查询失败，看板仍然显示完整 UI（失败部分显示零值）
- 错误详情通过 `debugPrint('看板 {label} 加载失败: $e')` 输出到控制台

## 修改文件
- `lib/db/database_helper.dart`：`queryWeeklyComparison` 方法
- `lib/services/dashboard_service.dart`：`refreshDashboard()` + 新增 `_safeLoad()` 辅助方法

## 验证
- flutter analyze: 零错误
- flutter test: 54/54 通过
