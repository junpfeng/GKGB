# 红蓝对抗审查报告：essay_comparison

## 审查类型：完整对抗（全新模块）

## 红队发现（17 项）

| # | 问题 | Severity | 蓝队判定 |
|---|------|----------|---------|
| 1 | `user_composite_answers` 缺 UNIQUE 约束 | HIGH | 接受，加 UNIQUE(sub_question_id) |
| 2 | 3 张新表无索引规划 | HIGH | 接受，加 3 个索引 |
| 3 | FK PRAGMA 未启用（全工程级） | HIGH | 不接受，不在本功能范围 |
| 4 | `importPresetData` 调用时机不明 | HIGH | 接受，明确页面进入时触发 |
| 5 | Stream 生命周期泄漏 | HIGH | 接受，要求 dispose cancel |
| 6 | Provider 序号描述歧义 | LOW | 低优先级，实现时自然处理 |
| 7 | score_points JSON 序列化不一致 | HIGH | 接受，明确 fromDb jsonDecode |
| 8 | id PRIMARY KEY 未显式列出 | LOW | 低优先级，约定成俗 |
| 9 | v15 迁移缺事务包裹 | HIGH | 接受，要求 db.transaction |
| 10 | Android 返回键三级导航穿透 | HIGH | 接受，使用 PopScope |
| 11 | AI prompt 隐私风险 | LOW | 接受为待细化 |
| 12 | DatabaseHelper 单例 vs DI | LOW | 不接受，现有工程模式 |
| 13 | loadExams 返回类型语义模糊 | LOW | 接受为待细化 |
| 14 | Windows PageView 操作体验 | LOW | 接受为待细化 |
| 15 | teacher_type 枚举无校验 | LOW | 低优先级，导入时处理 |
| 16 | notifyListeners 调用时机未规定 | HIGH | 接受为待细化 |
| 17 | 预置数据量增长性能 | LOW | 低优先级，v1 数据量小 |

## 修复汇总

已修改 idea.md 锁定决策：
1. `user_composite_answers` 加 `UNIQUE(sub_question_id)`
2. 新增 3 个索引定义
3. v15 迁移要求 `db.transaction` 包裹
4. `importPresetData` 明确页面进入时触发
5. `TeacherAnswer.scorePoints` 明确 `fromDb` 中 `jsonDecode`
6. `saveCompositeAnswer` 使用 `INSERT OR REPLACE`
7. 使用 `PopScope` 拦截返回事件
8. Screen 层 `StreamSubscription` 在 `dispose()` 中 `cancel()`

已追加待细化：
- `loadExams` 返回去重试卷维度数据
- `notifyListeners()` 调用时机
- Windows PageView 翻页适配
- AI prompt 不含用户综合答案

## 收敛

第 1 轮：8 HIGH 发现，全部处理（7 修复 + 1 拒绝为工程级问题）
第 2 轮：0 新 CRITICAL/HIGH → 通过
