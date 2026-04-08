# 进面分数线分析 - 开发日志

## 实现日期

2026-04-08

## 新增文件

| 文件 | 说明 |
|------|------|
| `lib/models/exam_entry_score.dart` | ExamEntryScore 数据模型（json_serializable + fromDb/toDb） |
| `lib/models/exam_entry_score.g.dart` | build_runner 自动生成的序列化代码 |
| `lib/services/exam_entry_score_service.dart` | ExamEntryScoreService（ChangeNotifier），含筛选/分页/热度排行/趋势/爬取 |
| `lib/screens/exam_entry_scores_screen.dart` | 进面分数线页面（筛选栏 + 列表/热度排行双 Tab + 详情弹窗 + 趋势图） |

## 修改文件

| 文件 | 变更 |
|------|------|
| `lib/db/database_helper.dart` | version 12→13；`_createDB` 新增 `exam_entry_scores` 表；`_onUpgrade` 新增 `oldVersion < 13` 迁移；`_createIndexes` 新增 3 个索引；新增 CRUD 方法（upsert/batch/query/ranking/trend/cities/years/count） |
| `lib/main.dart` | 注册 `ChangeNotifierProvider<ExamEntryScoreService>` |
| `lib/screens/dashboard_screen.dart` | 新增进面分数线入口卡片（渐变样式，点击跳转 ExamEntryScoresScreen） |

## 关键决策说明

### 数据库设计
- 独立 `exam_entry_scores` 表，不复用 `positions` 表（数据来源不同、生命周期不同）
- UNIQUE 约束 `(province, city, year, exam_type, position_code, department)` 防重复
- INSERT OR REPLACE 作为 upsert 策略，`updated_at` 追踪更新时间
- 3 个索引覆盖主筛选、城市维度、趋势查询

### 服务层
- 筛选条件联动：省份变更 → 刷新城市/年份列表 → 重新查询
- `_isFetching` 防重入锁，防止重复爬取
- 爬取间隔 ≥2s（Dio + Future.delayed），携带 User-Agent，遵守宪法安全约束
- 爬取解析为框架代码，实际 HTML 解析逻辑需根据目标网站结构补充
- 提供 `importScores` 方法支持手动导入

### UI 层
- 双 Tab 设计：分数线列表 + 热度排行
- 列表使用 ListView.builder + ScrollController 滚动分页（每次 50 条）
- 热度排行：fl_chart 柱状图（TOP 15）+ 完整排行列表
- 详情弹窗：DraggableScrollableSheet，含分数区间、岗位条件、历年趋势折线图
- 筛选栏：PopupMenuButton 实现的下拉筛选 Chip，支持清除

### 导航入口
- 在 DashboardScreen 中新增渐变入口卡片，位于考试日历下方
- 未增加底部导航 Tab（已有 5 个 Tab，避免过于拥挤）

## 待细化项补充设计

### 爬取目标网站
- 国考：国家公务员局 `scs.gov.cn`
- 省考：各省人事考试网（江苏 jshrss.gov.cn、浙江 zjks.gov.cn、上海 shacs.gov.cn、山东 hrss.shandong.gov.cn）
- 具体 URL 和 HTML 解析规则为框架代码，需根据实际页面结构实现 `_parseScoreData`

### 详情页 UI 布局
- 参考 match_reason_card 风格：底部弹窗 + 拖拽手柄
- 分数区间横向三栏展示（最低/最高/进面人数）
- 岗位条件纵向表格布局
- 历年趋势：双折线图（最低分蓝色 + 最高分粉色）

### 错误处理
- 爬取失败：SnackBar 提示 + "重试"按钮
- 数据加载失败：_error 字段存储错误信息，UI 展示空状态

## 遇到的问题及解决

1. **DropdownButtonFormField `value` 参数弃用**：Flutter 3.33+ 将 `value` 改为 `initialValue`，analyze 报 deprecated_member_use，已修正
2. **flutter 不在 PATH 中**：Windows 环境 flutter 安装在 `/c/flutter/bin/`，需使用完整路径调用

## 验收状态

- [x] ExamEntryScore model 存在
- [x] DB version 13
- [x] Service 注册 Provider
- [x] 新页面存在
- [x] `flutter analyze` 零错误
- [x] `flutter test` 54 项全部通过
