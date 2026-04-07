# 错题深度分析与知识图谱 - 开发日志

## 实现日期
2026-04-07

## 实现清单

### 数据层
| # | 决策 | 实现文件 | 状态 |
|---|------|---------|------|
| 1 | user_answers 新增 error_type TEXT DEFAULT '' | lib/models/user_answer.dart, lib/db/database_helper.dart | done |
| 2 | DB version 6→7，_createDB + _onUpgrade 同步 | lib/db/database_helper.dart (version: 7) | done |
| 3 | 索引 idx_user_answers_error_type | lib/db/database_helper.dart | done |
| 13 | WrongAnalysisService 只注入 LlmManager，不注入 QuestionService | lib/services/wrong_analysis_service.dart | done |
| 18 | UserAnswer 模型同步增加 errorType + fromDb/toDb | lib/models/user_answer.dart | done |
| 19 | 复合索引 idx_user_answers_correct_question | lib/db/database_helper.dart | done |

### 服务层
| # | 决策 | 实现文件 | 状态 |
|---|------|---------|------|
| 4 | WrongAnalysisService extends ChangeNotifier | lib/services/wrong_analysis_service.dart | done |
| 5 | DatabaseHelper 新增 CRUD（updateAnswerErrorType, queryErrorTypeDistribution, queryTopWrongCategories, queryCategoryAccuracy, queryRecentWrongAnswers, queryLatestWrongAnswerId） | lib/db/database_helper.dart | done |
| 7 | LLM prompt 输出 JSON + regex 降级 | lib/services/wrong_analysis_service.dart | done |
| 14 | streamChat() + join + timeout(15s) | lib/services/wrong_analysis_service.dart:56 | done |
| 15 | 用户答案用 `<user_answer>` 标签包裹 | lib/services/wrong_analysis_service.dart:37 | done |
| 17 | getCategoryAccuracy 用 LEFT JOIN | lib/db/database_helper.dart:queryCategoryAccuracy | done |

### UI 层
| # | 决策 | 实现文件 | 状态 |
|---|------|---------|------|
| 8 | 错题本 Tab 顶部入口卡片 | lib/screens/practice_screen.dart:_buildAnalysisEntryCard | done |
| 9 | wrong_analysis_screen（饼图 + TOP10 + AI 诊断报告） | lib/screens/wrong_analysis_screen.dart | done |
| 10 | knowledge_map_screen（科目→分类树状图谱，颜色渐变） | lib/screens/knowledge_map_screen.dart | done |
| 11 | ErrorAnalysis 纯数据类 | lib/models/error_analysis.dart | done |
| 16 | 饼图空数据友好提示 | lib/screens/wrong_analysis_screen.dart:_buildErrorPieChart | done |

### 编排 & 注册
| # | 决策 | 实现文件 | 状态 |
|---|------|---------|------|
| 6→13 | 错因分析由 Screen 层编排（答错后调用 analyzeAndSave） | lib/screens/practice_screen.dart:_confirmAnswer, QuestionDetailScreen | done |
| 12→20 | ChangeNotifierProxyProvider<LlmManager, WrongAnalysisService> | lib/main.dart | done |

## 验证结果
- `flutter analyze`: No issues found
- `flutter test`: All 37 tests passed
- build_runner: 代码生成成功（user_answer.g.dart 已更新）

## 新增/修改文件列表
- **新增** lib/models/error_analysis.dart
- **新增** lib/services/wrong_analysis_service.dart
- **新增** lib/screens/wrong_analysis_screen.dart
- **新增** lib/screens/knowledge_map_screen.dart
- **修改** lib/models/user_answer.dart (errorType 字段)
- **修改** lib/models/user_answer.g.dart (build_runner 自动生成)
- **修改** lib/db/database_helper.dart (v7 迁移 + CRUD + 索引)
- **修改** lib/screens/practice_screen.dart (分析入口 + 答错编排)
- **修改** lib/main.dart (WrongAnalysisService Provider 注册)

## 红蓝对抗修正落地情况（决策 13-20）
- [x] 13: WrongAnalysisService 只注入 LlmManager，直接用 DatabaseHelper.instance
- [x] 14: streamChat() + join + timeout(15s)
- [x] 15: `<user_answer>` 标签包裹用户答案
- [x] 16: 饼图空数据显示友好提示
- [x] 17: queryCategoryAccuracy 使用 LEFT JOIN
- [x] 18: UserAnswer.errorType + fromDb/toDb 同步更新
- [x] 19: 复合索引 (is_correct, question_id)
- [x] 20: ChangeNotifierProxyProvider<LlmManager, WrongAnalysisService>（单依赖）
