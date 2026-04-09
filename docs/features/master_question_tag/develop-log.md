# 母题标签功能 - 开发日志

## 新增文件

| 文件 | 说明 |
|------|------|
| `lib/models/master_question_type.dart` | 母题类型模型（手写序列化） |
| `lib/models/question_master_tag.dart` | 题目-母题关联模型（手写序列化） |
| `lib/services/master_question_service.dart` | 母题标签服务（ChangeNotifier） |

## 修改文件

| 文件 | 变更内容 |
|------|----------|
| `lib/db/database_helper.dart` | 新增 `master_question_types` 和 `question_master_tags` 两张表；version 13→14；预置 20 个母题类型（数量关系 12 + 资料分析 8）；新增 3 个索引 |
| `lib/main.dart` | 注册 `MasterQuestionService` 为第 20 个 ChangeNotifier Provider |
| `lib/screens/practice_screen.dart` | ① `_SourceFilter` 枚举新增 `masterType`；② `QuestionListScreen` SegmentedButton 扩展为 4 段（仅数量关系/资料分析显示"母题"页签）；③ 新增母题类型卡片网格视图；④ 新增 `_MasterTypeManagementSheet` 管理底部弹窗（新增/编辑/删除）；⑤ 新增 `MasterTagDialog` 标记弹窗；⑥ `QuestionDetailScreen` 和 `PracticeSessionScreen` AppBar 增加母题标记按钮 |
| `lib/widgets/question_card.dart` | 新增 `_MasterTagChips` 组件，在题目卡片中展示母题标签 Chip |

## 关键决策说明

1. **手写序列化 vs json_serializable**：模型字段简单（5-7 个字段），遵循 idea.md 锁定决策，使用手写 `fromDb/toDb` 方法
2. **ConflictAlgorithm.replace**：`tagQuestion` 使用 `REPLACE` 策略，UNIQUE(question_id, master_type_id) 约束下可直接更新
3. **分类别名处理**：`MasterQuestionService` 内置 `_masterCategories` 映射表，将"数量分析"规范化为"数量关系"，确保别名分类也能正确显示母题页签和查询标签数据
4. **预置母题 description 补充**：根据公考常识为每个预置母题类型编写了简要说明文案
5. **标记母题交互位置**：在 `QuestionDetailScreen` 和 `PracticeSessionScreen` 的 AppBar 中添加 `Icons.category` 图标按钮，点击弹出标记底部弹窗
6. **母题标签 Chip 显示**：在 `QuestionCard` 中，仅对支持母题标签的分类（数量关系/资料分析）显示 `_MasterTagChips`，无标签时不占空间

## 数据库变更

- **版本**：13 → 14
- **新增表**：`master_question_types`（母题类型定义）、`question_master_tags`（题目-母题关联）
- **新增索引**：`idx_master_types_category`、`idx_question_master_tags_question`、`idx_question_master_tags_type`
- **预置数据**：20 条母题类型（数量关系 12 + 资料分析 8），通过 batch insert 写入

## 验证结果

- `flutter analyze`：零错误、零警告（4 个 info 级 `use_build_context_synchronously` 与现有代码一致）
- `flutter test`：全部 54 个测试通过
