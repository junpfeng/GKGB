# 科目练习题目来源分类 - 实现日志

## 实现日期
2026-04-08

## 变更文件

### 数据层 (DatabaseHelper)
- **lib/db/database_helper.dart**
  - `queryQuestions()` 新增 `isRealExam`(int?)、`examType`(String?)、`region`(String?)、`year`(int?) 可选参数，拼接 WHERE 条件
  - `getDistinctValues()` 的字段白名单新增 `category`，支持按科目分类筛选可用选项

### 服务层 (QuestionService)
- **lib/services/question_service.dart**
  - `loadQuestions()` 新增 `isRealExam`、`examType`、`region`、`year` 可选参数，透传至 DatabaseHelper
  - `getAvailableRegions()` 新增 `subject`、`category` 参数
  - `getAvailableYears()` 新增 `subject`、`category` 参数
  - `getAvailableExamTypes()` 新增 `subject`、`category` 参数

### UI 层 (QuestionListScreen)
- **lib/screens/practice_screen.dart**
  - 新增 `_SourceFilter` 枚举（all / realExam / simulated）
  - 顶部原 FilterChip「仅看真题」替换为 `SegmentedButton` 三态切换：全部 / 真题 / 模拟题
  - 选「真题」时下方展开筛选行，包含三个独立 DropdownButton：考试类型、地区、年份
  - 筛选下拉从数据库动态查询可选项，各含「全部」兜底选项
  - 切换来源时自动重置子筛选
  - 空状态提示根据当前筛选模式显示不同文案和图标

## 设计决策

### 待细化项补充
- **筛选 Chip 视觉样式**: 采用带圆角边框的 Container 包裹 DropdownButton，选中时边框和背景变为主题色（#667eea）半透明，与现有 FilterChip 风格一致
- **无可用真题空状态**: 显示 `verified_outlined` 图标 + "该分类暂无符合条件的真题"；模拟题空状态显示 "该分类暂无模拟题"

### 技术要点
- `isRealExam` 使用 int? 类型（1=真题, 0=模拟题, null=全部），与数据库 `is_real_exam` 字段一致
- 保留了原有的 `realExamOnly` bool 参数以保持向后兼容，新增 `isRealExam` 参数提供更精确的三态控制
- 筛选选项查询复用 `getDistinctValues()` 方法，自动过滤空值和附加 `is_real_exam = 1` 条件
- SegmentedButton 使用 `VisualDensity.compact` 减少高度占用

## 验证结果
- `flutter analyze`: No issues found
- `flutter test`: All 54 tests passed
