# 时政热点与申论素材库 — 实现日志

## 实现概览

基于 `docs/features/hot_topics/idea.md` 锁定决策（共 20 条），完整实现时政热点浏览、申论素材库、申论写作训练功能。

## 变更清单

### 新增文件

| 文件 | 说明 |
|------|------|
| `lib/models/hot_topic.dart` | HotTopic 模型（json_serializable） |
| `lib/models/essay_material.dart` | EssayMaterial 模型 |
| `lib/models/essay_submission.dart` | EssaySubmission 模型 |
| `lib/models/hot_topic.g.dart` | 自动生成序列化代码 |
| `lib/models/essay_material.g.dart` | 自动生成序列化代码 |
| `lib/models/essay_submission.g.dart` | 自动生成序列化代码 |
| `lib/services/hot_topic_service.dart` | 热点+素材管理服务（注入 LlmManager） |
| `lib/services/essay_service.dart` | 申论写作训练服务（注入 LlmManager） |
| `lib/screens/hot_topics_screen.dart` | 时政热点浏览页 + 详情页 |
| `lib/screens/essay_material_screen.dart` | 申论素材库页面 |
| `lib/screens/essay_training_screen.dart` | 申论写作训练页面 |
| `assets/data/hot_topics_sample.json` | 10 条预置时政热点 |
| `assets/data/essay_materials_sample.json` | 48 条预置申论素材 |

### 修改文件

| 文件 | 变更说明 |
|------|----------|
| `lib/db/database_helper.dart` | version 7→8，新增 3 表 + 3 索引 + CRUD 方法 |
| `lib/main.dart` | 导入 HotTopicService/EssayService，注册 Provider，启动时幂等导入预置数据 |
| `lib/screens/profile_screen.dart` | 新增「时政热点」「申论训练」「申论素材库」三个菜单入口 |
| `pubspec.yaml` | 注册 2 个新 asset 文件 |

## 锁定决策对照

| # | 决策 | 实现情况 |
|---|------|----------|
| 1 | hot_topics 表 | ✅ _createDB + v8 迁移 |
| 2 | essay_materials 表 | ✅ _createDB + v8 迁移 |
| 3 | essay_submissions 表 | ✅ _createDB + v8 迁移 |
| 4 | DB version 7→8 | ✅ version: 8 |
| 5 | 3 个索引 | ✅ idx_hot_topics_date / idx_essay_materials_theme / idx_essay_submissions_date |
| 6 | HotTopicService | ✅ 注入 LlmManager，含 loadTopics/addTopic/aiAnalyzeTopic/loadMaterials/toggleMaterialFavorite/loadFavoriteMaterials |
| 7 | EssayService | ✅ 注入 LlmManager，含 startEssay/submitEssay/loadHistory/getSubmission |
| 8 | AI 批改 prompt | ✅ 复用 gradeEssay 模式，输出评分+逐段点评+改进建议 |
| 9 | 入口在 ProfileScreen | ✅ 「时政热点」「申论训练」「申论素材库」 |
| 10 | hot_topics_screen | ✅ 卡片列表+分类筛选+详情页+FAB 添加 |
| 11 | essay_material_screen | ✅ Tab 分组+类型分组+收藏 |
| 12 | essay_training_screen | ✅ 选题→限时写作→提交→AI 流式批改+历史列表 |
| 13 | 3 个模型 | ✅ HotTopic / EssayMaterial / EssaySubmission |
| 14 | Provider 注册 | ✅ HotTopicService + EssayService |
| 15 | 预置数据 JSON | ✅ 10 条热点 + 48 条素材（6主题×4类型×2条） |
| 16 | AI 分析用 streamChat | ✅ aiAnalyzeTopic + submitEssay 均用 streamChat |
| 17 | 热点列表分页 | ✅ limit+offset + ListView.builder |
| 18 | submissions 列表轻量查询 | ✅ queryEssaySubmissions 只查 id/topic/word_count/time_spent/ai_score/created_at |
| 19 | 手动添加热点 AI 生成 | ✅ chat() + timeout(30s) + 容错 |
| 20 | 预置数据幂等导入 | ✅ 表非空跳过 |

## 验证结果

- `flutter analyze`: No issues found!
- `flutter test`: All 37 tests passed!
- DB version: 8 ✅
