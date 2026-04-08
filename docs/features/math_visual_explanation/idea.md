# 数量关系可视化解题

## 核心需求
参照抖音"秒懂数理"风格，为数量关系题目提供逐步可视化动画解题。使用 CustomPainter + AnimationController 实现步骤动画播放器，支持方程推导、进度条、数轴等多种可视化模板。题目可视化数据支持 AI 生成和预置导入。

## 调研上下文

### 现有基础
- **MasterQuestionService** (`lib/services/master_question_service.dart`)：已支持母题分类（数量关系/资料分析）、标签关联、按类型查题。可视化解题与母题系统天然关联。
- **QuestionCard** (`lib/widgets/question_card.dart`)：答案揭示区域（约 line 140-209）已有成语释义、母题标签、AI 评分等扩展点，适合在此添加"可视化解题"按钮。
- **DatabaseHelper** (`lib/db/database_helper.dart`)：当前 v14，母题表在 v14 中新增。新表需升级到 v15。
- **LlmManager** (`lib/services/llm/llm_manager.dart`)：支持 `chat()` 和 `streamChat()`，已有 fallback 机制。
- **Provider 注册**：main.dart 中 21 个 Provider，MasterQuestionService 在位置 20。新 Service 可放位置 21。
- **CustomPainter 参考**：`lib/widgets/progress_ring.dart` 的 `_GradientRingPainter` 展示了 Canvas 绑定模式。
- **Animation 参考**：`lib/widgets/voice_input_widget.dart` 使用 `SingleTickerProviderStateMixin` + `AnimationController` 模式。

### 设计文档
已有详细设计方案 `docs/features/math_visual_explanation/design.md`，包含：
- 数据表结构（visual_explanations）
- steps_json 格式定义（10 种 visual_type）
- Service 接口设计
- Widget 文件结构
- 播放器 UI 布局
- 集成方案和分期建议

## 范围边界
- 做：播放器框架 + 方程推导模板 + 进度条模板 + 数轴模板 + AI 生成 + 预置数据导入 + QuestionCard 集成
- 不做：饼图模板（二期）、3D 渲染、视频导出

## 初步理解
这是一个全新模块，涉及三层（model + service + widget）新增，核心技术挑战在于：
1. 通用的步骤播放引擎设计（AnimationController 管理多步骤切换）
2. 多种 Painter 实现（方程/进度条/数轴各有不同绘制逻辑）
3. LLM prompt 工程确保输出格式可解析为 steps_json
4. 与现有 QuestionCard / MasterQuestionService 的集成

设计文档建议分两期，但方案中包含一期和二期内容（饼图在二期）。

## 待确认事项
1. 一期范围确认：方程推导 + 进度条 + 数轴三种模板是否都在一期？
2. 预置数据：10-20 道母题的可视化数据如何准备？手工编写还是 AI 批量生成？
3. AI 生成的触发时机：用户点击时实时生成，还是后台预生成？
4. 是否需要 json_serializable 生成 model 类？
5. 可视化解题入口除了 QuestionCard，是否还需要在母题 Tab 或其他地方添加？

## 确认方案

核心思路：一期聚焦方程推导模板 + 播放器框架，用 CustomPainter + AnimationController 实现逐步动画，AI 按需生成可视化数据并缓存。

### 锁定决策

**数据层：**
- 数据模型：新增 `VisualExplanation`（id, questionId, explanationType, stepsJson, templateId, createdAt）
- 数据库变更：新表 `visual_explanations`，version 14 → 15，显式创建 `question_id` 索引
- 序列化：手写 fromJson/toJson（与 MasterQuestionType 模式一致，stepsJson 作为 TEXT 字段存储，内部 JSON 解析在 Service 层独立处理）

**服务层：**
- 新增服务：`VisualExplanationService extends ChangeNotifier`
- DB 获取：Service 内部使用 `DatabaseHelper.instance`（与项目其他 Service 一致）
- LLM 依赖：构造函数注入 LlmManager（与 HotTopicService 模式一致，因需要 main() 中 await 预置数据导入）
- LLM 调用：通过 `LlmManager.streamChat()` 收集完整 JSON 后解析（满足宪法 Stream 要求，超时 30s），生成过程显示进度反馈，结果缓存到 DB
- JSON 校验：AI 返回后进行 schema 校验（必需字段检查 + visual_type 白名单过滤），校验失败显示 fallback UI（"生成失败，请重试"）
- 外部依赖：无新增 package

**UI 层：**
- 新增页面：`VisualExplanationScreen`（StatefulWidget + TickerProviderStateMixin，持有 AnimationController，负责动画生命周期管理和 dispose）
- 状态管理：`VisualExplanationService` 作为 ChangeNotifier 仅管理数据（CRUD、AI 生成），不持有 AnimationController。Provider 注册位置 21
- 组件：`VisualPlayerWidget`（播放控制）、`EquationPainter`（方程推导 CustomPainter，shouldRepaint 仅在 currentStep 或动画进度变化时返回 true）
- 入口：`QuestionCard` 答案揭示区域，所有数量关系题始终显示"可视化解题"按钮（不判断数据是否存在），点击后先查 DB 缓存，命中直接播放，未命中触发 AI 生成
- Service 维护 `Set<int> _cachedQuestionIds`：importPresetData() 完成后通过 `SELECT question_id FROM visual_explanations` 一次性填充；generateExplanation() 成功后同步 add + notifyListeners()；hasExplanation() 为纯内存查询不触发 DB

**主要技术决策：**
- 一期仅方程推导模板：覆盖约 60% 母题，快速验证
- AI streamChat 生成 + DB 缓存：用户点击时 streamChat 收集完整 JSON，解析校验后存 DB 复用
- 预置数据：AI 批量生成 10-20 道母题数据，审核后放入 assets/，导入使用 INSERT OR IGNORE 保证幂等
- 展示方式：Navigator.push 新页面，播放器空间充足
- 平台文本：一期仅使用中文文本 + 基本数学运算符（+, -, =, /, *），避免特殊数学符号

**技术细节：**
- 数据结构：`steps_json` 为 JSON 数组，每步含 step/narration/visual_type/params/highlight
- visual_type 一期支持：equation_setup, equation_substitute, equation_solve, highlight_result
- 接口签名：`getExplanation(int questionId) → Future<VisualExplanation?>`、`generateExplanation(int questionId) → Future<VisualExplanation>`、`hasExplanation(int questionId) → bool`（同步，基于内存缓存集合）
- 播放器职责划分：Screen 持有 AnimationController + 管理动画生命周期；VisualPlayerWidget 接收动画值 + 渲染控制栏；EquationPainter 接收 step 数据 + 动画进度进行绘制
- Provider 注册：main() 中预实例化 + await importPresetData() + `ChangeNotifierProvider.value`（与 HotTopicService 模式一致，因需要启动时完成预置数据导入和 _cachedQuestionIds 初始化），位置 21（MasterQuestionService 之后）

**范围边界：**
- 做：播放器框架、方程推导模板、AI 生成 + 缓存、JSON 校验 + fallback、预置数据导入、QuestionCard 按钮入口
- 不做：进度条/数轴/饼图模板（二期）、3D 渲染、视频导出、母题 Tab 入口
- 不做保护：EquationPainter 遇到非 equation_* 类型的 visual_type 时降级为纯文本叙述显示，不崩溃

### 待细化
- LLM prompt 模板具体内容（方向：提供 visual_type 枚举 + params 格式示例，要求 3-8 步，要求返回纯 JSON 不带 markdown 包裹）
- EquationPainter 具体绘制逻辑（方向：TextPainter 居中 + 高亮变量颜色 + 步骤间箭头连接）
- 预置数据的具体题目选择（方向：从已有母题中选高频类型）
- 一期 UNIQUE(question_id) 约束：每题一条记录，二期若需同题多模板再改为 UNIQUE(question_id, explanation_type)

### 验收标准
- [mechanical] VisualExplanation model 存在：判定 `grep -r "class VisualExplanation" lib/models/`
- [mechanical] VisualExplanationService 存在：判定 `grep -r "class VisualExplanationService" lib/services/`
- [mechanical] VisualExplanationScreen 存在：判定 `grep -r "class VisualExplanationScreen" lib/screens/`
- [mechanical] DB v15 迁移存在：判定 `grep "version.*15\|visual_explanations" lib/db/database_helper.dart`
- [mechanical] Provider 已注册：判定 `grep "VisualExplanationService" lib/main.dart`
- [mechanical] QuestionCard 入口存在：判定 `grep "可视化解题" lib/widgets/question_card.dart`
- [test] 全量测试通过：`flutter test`
- [manual] 数量关系题答案揭示后显示"可视化解题"按钮，点击进入播放器页面，可逐步播放方程推导动画
