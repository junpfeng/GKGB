# 开发日志：申论小题多名师答案对比

## 新增文件
- `lib/models/essay_sub_question.dart` + `.g.dart` — 申论小题模型
- `lib/models/teacher_answer.dart` + `.g.dart` — 名师答案模型
- `lib/models/user_composite_answer.dart` + `.g.dart` — 用户综合答案模型
- `lib/services/essay_comparison_service.dart` — 对比服务（ChangeNotifier）
- `lib/screens/essay_comparison_screen.dart` — 三级导航 UI
- `assets/data/essay_sub_questions_preset.json` — 预置数据（2024 国考地市级 3 道小题，10 位名师答案）

## 修改文件
- `lib/db/database_helper.dart` — 新增 3 张表（v16→v17 迁移，事务包裹）+ 3 个索引 + CRUD 方法
- `lib/main.dart` — 注册 EssayComparisonService Provider（序号 22）
- `lib/screens/practice_screen.dart` — 新增"申论小题对比"入口卡片
- `pubspec.yaml` — 注册预置数据 asset
- `docs/app-architecture.md` — 同步更新计数和清单

## 关键决策
1. DB 迁移版本：v17（而非 v20），因为 v15-v16 已被政治理论功能占用，v17 是下一个可用版本
2. 三级导航采用单文件状态切换 + PopScope 拦截返回键（Android 物理键适配）
3. Windows 平台 PageView 添加左右箭头按钮辅助翻页
4. AI 分析使用 streamChat 流式输出，StreamSubscription 在 dispose 和 goBack 中取消
5. score_points 字段在 DB 中存储为 JSON 字符串，fromDb 中 jsonDecode 解析
6. 用户综合答案使用 UNIQUE(sub_question_id) + INSERT OR REPLACE 语义
7. 预置数据导入采用版本标记机制（metadata 表），避免重复导入

## 遇到的问题
1. **DB 版本冲突**：idea.md 写 v14→v15，但实际代码已到 v16，使用 v17
2. **flutter/dart 不在 PATH**：Windows bash 需手动 `export PATH="$PATH:/c/flutter/bin"`
3. **未使用字段警告**：Screen 中移除仅赋值未读的 `_selectedYear` 等字段

## 验证结果
- flutter analyze：零新错误（2 个 pre-existing 错误来自 speed_training 功能，4 个 pre-existing info）
- flutter test：54 tests pass（All tests passed!）
