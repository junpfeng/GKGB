# 母题标签

## 核心需求
科目练习中，给数量关系和资料分析两个模块添加一个母题标签，用于归纳这两种题型中所有题目的各种基础题目，是万变不离其宗的根源，方便记忆和理解。

## 调研上下文

### 现有结构
- **题目模型** (`Question`): 含 subject, category, type, content, options, answer, difficulty 等字段，无标签字段
- **科目分类**: "数量关系"和"资料分析"是 `category` 字段的值，存于 `questions` 表
- **知识点系统**: `knowledge_points` 表已有层级结构（parent_id），但用于掌握度追踪，非题目分类标签
- **练习流程**: PracticeScreen → QuestionListScreen（含来源筛选：全部/真题/模拟题）→ PracticeSessionScreen
- **数据库版本**: v13
- **类别别名**: `_categoryAliases` 中 "数量关系" 和 "数量分析" 互为别名

### 相似实现参考
- `QuestionListScreen` 已有分段筛选器（来源 SegmentedButton + 考试类型/地区/年份 Chip 过滤）
- `is_real_exam` 字段用于区分真题/模拟题来源

## 范围边界
- 做：为数量关系和资料分析的题目添加母题分类标签，支持筛选查看
- 不做：其他科目的母题标签；AI 自动归类；母题之间的关联关系

## 初步理解
"母题"是一种题目分类维度，将数量关系/资料分析中的题目归纳为若干基础题型（如数量关系的"工程问题"、"行程问题"、"排列组合"等）。用户可以按母题标签筛选练习，帮助理解题目的本质类型。

## 待确认事项
1. 母题标签的数据来源（预置 vs 用户自定义）
2. 母题与题目的关系（一对一 vs 一对多）
3. UI 交互形式
4. 数据存储方案

## 确认方案

核心思路：为数量关系和资料分析添加母题分类体系，支持预置+自定义母题类型，题目可标记为根源母题或变体题，通过独立页签筛选练习。

### 锁定决策

数据层：
- 新增模型 `MasterQuestionType`：母题类型定义
  - `id`: int, 主键
  - `category`: String (数量关系/资料分析)
  - `name`: String (如"工程问题")
  - `description`: String (简要说明，可选)
  - `sortOrder`: int
  - `isPreset`: int (1=预置, 0=用户自定义)
  - `createdAt`: String
- 新增模型 `QuestionMasterTag`：题目与母题类型的关联
  - `id`: int, 主键
  - `questionId`: int (FK → questions)
  - `masterTypeId`: int (FK → master_question_types)
  - `isRoot`: int (1=根源母题, 0=变体题)
  - `createdAt`: String
- 数据库变更：新增 `master_question_types` 表 + `question_master_tags` 表，version 13 → 14
- 索引：`idx_master_types_category` (category)、`idx_question_master_tags_question` (question_id)、`idx_question_master_tags_type` (master_type_id)
- 预置母题类型：
  - 数量关系：工程问题、行程问题、排列组合、概率问题、利润问题、几何问题、容斥原理、数列问题、方程问题、最值问题、浓度问题、牛吃草问题
  - 资料分析：增长率、增长量、比重、倍数、平均数、隔年增长、年均增长、混合增长
- 序列化：手写 fromJson/toJson（字段简单，无需 json_serializable）

服务层：
- 新增 `MasterQuestionService` (ChangeNotifier)
  - `loadTypes(category)` → 加载某分类下的母题类型列表
  - `createType(category, name, description)` → 创建自定义母题类型
  - `updateType(id, name, description)` → 编辑母题类型
  - `deleteType(id)` → 删除自定义类型（预置不可删）
  - `tagQuestion(questionId, masterTypeId, isRoot)` → 给题目打母题标签
  - `untagQuestion(questionId, masterTypeId)` → 移除标签
  - `toggleRoot(questionId, masterTypeId)` → 切换根源母题/变体
  - `getTagsForQuestion(questionId)` → 获取题目的母题标签
  - `getQuestionsByType(masterTypeId, {isRootOnly})` → 按母题类型查题目，根源母题排前
  - `getTypeStats(category)` → 各类型题目数量统计
- LLM 调用：不涉及
- 外部依赖：无新增

UI 层：
- 修改 `QuestionListScreen`：来源 SegmentedButton 从 3 段(全部/真题/模拟题)扩展为 4 段(全部/真题/模拟题/母题)
- 母题页签内容：
  - 展示母题类型卡片网格，每个卡片显示类型名称 + 题目数量 + 根源母题数量
  - 顶部管理按钮（齿轮图标），进入类型管理
  - 点击卡片 → 进入该类型的题目列表（根源母题置顶，带特殊标识）
  - 长按卡片 → 弹出编辑/删除菜单（仅自定义类型可删除）
- 母题类型管理：底部弹窗(showModalBottomSheet)，支持新增/编辑/排序/删除
- 修改 `QuestionCard` / `PracticeSessionScreen`：题目详情中显示母题标签 Chip
- 题目详情页增加"标记母题"操作：长按或菜单中可给当前题目打标签/标记为根源母题
- 状态管理：新增 `MasterQuestionService` 作为 ChangeNotifier，在 main.dart 注册
- 仅在 category 为"数量关系"或"资料分析"时显示母题页签

主要技术决策：
- 独立表而非扩展 questions 表：母题是多对多关系，独立表更灵活
- 手写序列化：模型字段少且简单，避免 build_runner 开销
- SegmentedButton 扩展：与现有筛选体验一致，用户零学习成本
- 母题页签仅限数量关系/资料分析：其他科目不显示此页签

范围边界：
- 做：母题类型 CRUD、题目标签关联、筛选页签、题目详情展示、预置数据
- 不做：AI 自动归类题目到母题、母题之间的关联/推导关系、其他科目的母题、母题学习进度追踪（复用现有 mastery 系统即可）

### 待细化
- 预置母题类型的 description 具体文案（引擎根据公考常识补充）
- 母题类型卡片的视觉样式细节（引擎参考现有 GlassCard 风格）
- "标记母题"操作的具体交互入口位置（引擎根据 QuestionCard 现有布局适配）

### 验收标准
- [mechanical] 新表存在：判定 `grep "master_question_types" lib/db/database_helper.dart`
- [mechanical] 新服务存在：判定 `ls lib/services/master_question_service.dart`
- [mechanical] Provider 已注册：判定 `grep "MasterQuestionService" lib/main.dart`
- [mechanical] 数据库版本升级：判定 `grep "version: 14" lib/db/database_helper.dart`
- [test] 服务层逻辑：`flutter test test/services/master_question_service_test.dart`
- [manual] 母题页签：运行 `flutter run -d windows`，进入数量关系科目练习，验证 SegmentedButton 出现"母题"选项，点击后显示母题类型卡片
- [manual] 标记功能：在题目详情中可以给题目打母题标签、标记为根源母题
- [manual] 管理功能：可以新增/编辑/删除自定义母题类型
