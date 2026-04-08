# 成语整理功能 开发日志

## 新增文件
- `lib/models/idiom.dart` — 成语数据模型
- `lib/models/idiom_example.dart` — 成语例句数据模型
- `lib/services/idiom_service.dart` — 成语整理服务（提取、爬取、查询）
- `lib/screens/idiom_list_screen.dart` — 成语整理独立页面

## 修改文件
- `lib/db/database_helper.dart` — v11→v12 迁移，新增 idioms/idiom_examples/idiom_question_links 三表及 CRUD
- `lib/main.dart` — 注册 IdiomService Provider
- `lib/widgets/question_card.dart` — 添加 _IdiomDefinitionSection 折叠释义区
- `lib/screens/practice_screen.dart` — 言语理解分类下添加成语整理入口卡片

## 关键决策
- 使用 junction table (idiom_question_links) 而非 JSON 数组存储多对多关系，查询更高效
- 选词填空识别：category IN ('言语理解', '言语运用') + content.contains('___')，Dart 侧过滤避免 SQLite LIKE 对 _ 通配符的干扰
- QuestionCard 保持 StatelessWidget，新增的 _IdiomDefinitionSection 作为独立 StatefulWidget
- 使用 COUNT(*) as cnt + result.first['cnt'] 模式，与项目现有风格一致（不依赖 Sqflite.firstIntValue）
