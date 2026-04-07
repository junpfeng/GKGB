# AI 自适应智能出题 - 开发日志

## 实现概览

基于 `idea.md` 中的 17 条锁定决策，完整实现 AI 自适应智能出题功能。

## 实现清单

### 数据层

| # | 决策 | 状态 | 实现文件 |
|---|------|------|---------|
| 1 | knowledge_points 表 | ✅ | `lib/db/database_helper.dart` |
| 2 | mastery_scores 表 | ✅ | `lib/db/database_helper.dart` |
| 3 | DB version 8→9，_createDB 和 _onUpgrade 同步 | ✅ | `lib/db/database_helper.dart` |
| 4 | 索引 idx_mastery_scores_review + idx_knowledge_points_subject | ✅ | `lib/db/database_helper.dart` (_createIndexes + _onUpgrade) |

### 模型层

| 文件 | 说明 |
|------|------|
| `lib/models/knowledge_point.dart` | KnowledgePoint 模型，json_serializable + fromDb/toDb |
| `lib/models/mastery_score.dart` | MasteryScore 模型，含 accuracy getter |

### 服务层

| # | 决策 | 状态 | 说明 |
|---|------|------|------|
| 5 | AdaptiveQuizService extends ChangeNotifier | ✅ | 注入 LlmManager，实现全部方法 |
| 6 | 遗忘曲线间隔 [1,2,4,7,15,30] | ✅ | `_reviewIntervals` + `_calcCorrectStreak` |
| 7 | AI 生成题目 chat() + JSON + 容错 | ✅ | `generateQuestion` + `_parseGeneratedQuestion` |

**核心方法实现：**

- `ensureInitialized()` — 幂等知识点初始化（决策 14）
- `getNextQuestions({count, subject})` — 智能选题：薄弱优先(score<60) → 遗忘曲线(next_review_at<=now) → 难度递进 → fallback 随机（决策 5, 17）
- `updateMastery(knowledgePointId, isCorrect)` — 掌握度更新，事务原子操作（决策 16）
  - 正确：`score += (100 - score) * 0.1`
  - 错误：`score -= score * 0.2`
- `getMasteryOverview({subject})` — 掌握度列表
- `getLearningEfficiency({days})` — 近 N 天学习效率
- `getPredictedReadyDate(subject, targetScore)` — 预测达标日期
- `generateQuestion(subject, category, difficulty)` — AI 生成 + JSON 解析 + 存入 questions 表

### UI 层

| # | 决策 | 状态 | 实现文件 |
|---|------|------|---------|
| 8 | PracticeScreen 增加「智能练习」入口卡片 | ✅ | `lib/screens/practice_screen.dart` |
| 9 | adaptive_quiz_screen.dart | ✅ | 科目选择 + 掌握度总览 + 智能练习 + 完成摘要 |
| 10 | mastery_overview_screen.dart | ✅ | 筛选 + 统计摘要 + 知识点列表（进度条+分数+复习日期） |
| 11 | KnowledgePoint / MasteryScore 模型 | ✅ | `lib/models/` |
| 12 | Provider 注册 ChangeNotifierProxyProvider | ✅ | `lib/main.dart` |
| 13 | 预置知识点根据 questions 表 subject+category 自动生成 | ✅ | `_initKnowledgePoints()` |

### 预防性修正

| # | 决策 | 状态 | 说明 |
|---|------|------|------|
| 14 | 知识点初始化幂等 | ✅ | 检查 knowledge_points 非空则跳过 |
| 15 | AI 生成题目 difficulty 校验 | ✅ | `clamp(1, 5)` |
| 16 | 掌握度更新原子事务 | ✅ | `db.transaction()` |
| 17 | 选题 fallback 随机补齐 | ✅ | 智能结果不足时 `_getRandomQuestions` 补齐 |

## 验收结果

```
flutter analyze → No issues found!
flutter test → All 37 tests passed!
```

## 新增/修改文件清单

**新增：**
- `lib/models/knowledge_point.dart` + `.g.dart`
- `lib/models/mastery_score.dart` + `.g.dart`
- `lib/services/adaptive_quiz_service.dart`
- `lib/screens/adaptive_quiz_screen.dart`
- `lib/screens/mastery_overview_screen.dart`

**修改：**
- `lib/db/database_helper.dart` — version 9, 2 张新表 + 2 个索引
- `lib/main.dart` — AdaptiveQuizService Provider 注册
- `lib/screens/practice_screen.dart` — 智能练习入口卡片

## 范围边界

- ✅ 做：知识点表、掌握度建模、薄弱优先+遗忘曲线+难度递进选题、AI 动态生成、掌握度总览、学习效率分析
- ❌ 不做：知识点关联图谱（前置依赖）、最佳学习时段分析
