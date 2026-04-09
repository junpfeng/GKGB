# 考试类型差异化服务系统 设计方案

## Context

当前 app 的刷题、模考、学习计划等功能硬编码了"行测/申论/公基"三科和"130题120分钟"等参数，只适用于国考/省考场景。实际上，用户可能备考国考、省考、事业单位、选调生、人才引进、三支一扶等不同类型考试，这些考试的科目设置、题量、时间、面试形式差异很大。需要一套「考试类型配置 + 用户目标选择」机制，让整个 app 根据用户的备考目标自动适配。

## 核心设计思路

**静态注册表 + 用户目标表 + 服务层统一查询**

- `ExamCategoryRegistry`：纯 Dart 代码，定义所有考试类型的科目、题量、时间等配置（随 app 发版更新）
- `UserExamTarget`：DB 表，记录用户选择的备考目标（v1 单目标，schema 预留多目标能力）
- `ExamCategoryService`：中心服务，解析当前活跃目标 → 提供科目列表、考试参数、DB 过滤条件

### 设计原则

1. **轻量引导**: 首次启动仅需 1 步选择考试类型即可进入 app，其余信息可后续完善
2. **优雅降级**: 题库覆盖不完整的考试类型显示明确的空状态 + 通用练习入口
3. **纯数据模型**: 模型层不包含 Flutter UI 类型（IconData/Color），UI 映射在视图层完成
4. **最小侵入**: 下游服务按需查询 ExamCategoryService，不强制改为 ProxyProvider
5. **v1 聚焦**: 单目标模式，多目标管理延后至 v2

---

## 各类考试差异对照

| 考试类型 | 科目 | 题量/时间 | 子类型 | 需要省份 | v1 内容状态 |
|----------|------|-----------|--------|----------|-------------|
| 国考 | 行测 + 申论 | 副省135Q/地市130Q·120min + 5Q/150min | 副省级/地市级 | 否 | `full` 完整支持 |
| 省考 | 行测 + 申论 | 按省份变化 | 联考/独立命题 | 是 | `full` 8省覆盖 |
| 事业单位 | 职测+综合 或 公基 | 按类别不同 | A综合管理/B社科/C自科/D教师/E医疗 | 是 | `partial` A/B/C 类 |
| 选调生 | 行测(简化) + 申论 | 省份差异 | 无 | 是 | `partial` 基础配置 |
| 人才引进 | 综合知识+面试（不固定） | 不固定 | 无 | 是 | `coming_soon` |
| 三支一扶 | 公基 + 综合知识 | 较简单 | 无 | 是 | `partial` 基础配置 |

> **v1 省考省份覆盖**: 浙江/江苏/广东/山东/四川/湖北/河南/北京，其余使用"通用省考"默认值。

---

## Phase 1: 数据模型与基础设施

### 1.1 新建 `ExamCategory` 模型族

**文件**: `lib/models/exam_category.dart`

```dart
/// 考试类型配置（静态定义，非数据库存储）
class ExamCategory {
  final String id;              // 'guokao', 'shengkao', 'shiyebian', 'xuandiao', 'rencaiyinjin', 'sanzhiyifu'
  final String label;           // '国考', '省考', '事业单位', '选调生', '人才引进', '三支一扶'
  final String description;     // 简要说明
  final String scope;           // 'national', 'provincial', 'municipal', 'variable'
  final bool requiresProvince;  // 是否需要选择省份
  final ContentStatus contentStatus; // full / partial / coming_soon
  final List<ExamSubType> subTypes;          // 子类型列表（可为空）
  final List<ExamSubject> defaultSubjects;   // 默认科目配置
  final List<String> interviewCategories;    // 面试题型
  final List<String> dbExamTypeValues;       // 映射到现有 DB 中的 exam_type 字段值
  final Set<Feature> supportedFeatures;      // 该考试类型支持的功能集
}

/// 内容就绪状态
enum ContentStatus { full, partial, comingSoon }

/// 功能开关
enum Feature { practice, mockExam, essay, interview, positionMatch, realExam, studyPlan, hotTopics }

class ExamSubType {
  final String id;              // 'fushenji', 'dishiji', 'typeA', 'typeB'...
  final String label;           // '副省级', '地市级', '综合管理类(A类)'
  final List<ExamSubject> subjects; // 始终已填充（Registry 构建时预解析，无覆盖则复制父类 defaultSubjects）
}

class ExamSubject {
  final String subject;         // '行测', '申论', '职业能力倾向测验', '综合应用能力', '公基'
  final String label;           // 显示名称
  final int defaultQuestionCount;
  final int defaultTimeLimitSeconds;
  final double totalScore;
  final List<SubjectCategory> categories;  // 科目下的练习分类
}

class SubjectCategory {
  final String category;        // DB 中的 category 值
  final String label;           // 显示名称
  final int iconCodePoint;      // 如 Icons.calculate.codePoint → 0xe06b
  final String iconFontFamily;  // 'MaterialIcons'
  final List<int> gradientColors; // 如 [0xFF667eea, 0xFF764ba2]
}
```

**UI 层扩展**（放在 widget 或 theme 文件中）:
```dart
extension SubjectCategoryUI on SubjectCategory {
  IconData get icon => IconData(iconCodePoint, fontFamily: iconFontFamily);
  List<Color> get gradient => gradientColors.map(Color.new).toList();
}
```

### 1.2 新建 `ExamCategoryRegistry` 静态注册表

**文件**: `lib/models/exam_category_registry.dart`

包含所有考试类型的完整定义。省考的省份级覆盖数据（不同省份的题量/时间差异）存放在同文件的 `_provincialOverrides` Map 中。

**v1 必须完整定义**: 国考（副省级/地市级）、省考（通用 + 8 省覆盖）、事业编（A/B/C 类）
**v1 简化定义**: 选调生、三支一扶（仅基础科目配置）
**v2 补充**: 人才引进（标记为 `comingSoon`）

**SubType 预解析规则**: Registry 构建每个 `ExamSubType` 时，若该子类型无特有科目配置，则复制父类 `defaultSubjects`，确保 `ExamSubType.subjects` 始终非空，消费者无需实现回退逻辑。

**公基科目处理**: 当前刷题页硬编码了"公基·公共基础知识"。动态化后:
- 国考/省考: `defaultSubjects` 仅含行测+申论，**不含公基**（国考省考不考公基）
- 事业编/三支一扶: `defaultSubjects` 含公基
- 选调生: 按省份，部分含公基
- 确保公基不因动态化而从原本需要它的考试类型中丢失，也不在不需要它的类型中多余显示

**示例数据（国考）**:

```dart
ExamCategory(
  id: 'guokao',
  label: '国考',
  description: '中央机关及其直属机构招考',
  scope: 'national',
  requiresProvince: false,
  contentStatus: ContentStatus.full,
  supportedFeatures: {Feature.practice, Feature.mockExam, Feature.essay, Feature.interview, Feature.realExam, Feature.studyPlan, Feature.hotTopics},
  dbExamTypeValues: ['国考'],
  interviewCategories: ['综合分析', '计划组织', '人际关系', '应急应变', '自我认知', '演讲'],
  defaultSubjects: [
    ExamSubject(
      subject: '行测', label: '行政职业能力测验',
      defaultQuestionCount: 135, defaultTimeLimitSeconds: 7200, totalScore: 100,
      categories: [
        SubjectCategory(category: '言语理解', label: '言语理解', iconCodePoint: 0xe25c, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF667eea, 0xFF764ba2]),
        SubjectCategory(category: '数量关系', label: '数量关系', iconCodePoint: 0xe06b, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFf093fb, 0xFFf5576c]),
        SubjectCategory(category: '判断推理', label: '判断推理', iconCodePoint: 0xe4a2, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF4776E6, 0xFF8E54E9]),
        SubjectCategory(category: '资料分析', label: '资料分析', iconCodePoint: 0xe063, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF0ED2F7, 0xFF09A6C3]),
        SubjectCategory(category: '常识判断', label: '常识判断', iconCodePoint: 0xe3f0, iconFontFamily: 'MaterialIcons', gradientColors: [0xFFF7971E, 0xFFFFD200]),
      ],
    ),
    ExamSubject(
      subject: '申论', label: '申论',
      defaultQuestionCount: 5, defaultTimeLimitSeconds: 9000, totalScore: 100,
      categories: [
        SubjectCategory(category: '申论', label: '申论写作', iconCodePoint: 0xe0b6, iconFontFamily: 'MaterialIcons', gradientColors: [0xFF43E97B, 0xFF38F9D7]),
      ],
    ),
  ],
  subTypes: [
    ExamSubType(id: 'fushenji', label: '副省级', subjects: [/* 同上，题量 135 */]),
    ExamSubType(id: 'dishiji', label: '地市级', subjects: [/* 题量 130，无数量关系中的数字推理 */]),
  ],
)
```

**示例数据（事业编 A 类）**:

```dart
ExamCategory(
  id: 'shiyebian',
  label: '事业单位',
  description: '事业单位公开招聘',
  scope: 'provincial',
  requiresProvince: true,
  contentStatus: ContentStatus.partial,
  supportedFeatures: {Feature.practice, Feature.mockExam, Feature.interview, Feature.studyPlan},
  dbExamTypeValues: ['事业编', '事业单位'],
  interviewCategories: ['综合分析', '计划组织', '人际关系', '应急应变'],
  defaultSubjects: [/* A类默认 */],
  subTypes: [
    ExamSubType(
      id: 'typeA', label: '综合管理类(A类)',
      subjects: [
        ExamSubject(
          subject: '职测', label: '职业能力倾向测验',
          defaultQuestionCount: 150, defaultTimeLimitSeconds: 5400, totalScore: 150,
          categories: [
            SubjectCategory(category: '常识判断', label: '常识判断', ...),
            SubjectCategory(category: '言语运用', label: '言语理解与表达', ...),
            SubjectCategory(category: '数量分析', label: '数量关系', ...),
            SubjectCategory(category: '判断推理', label: '判断推理', ...),
            SubjectCategory(category: '资料分析', label: '资料分析', ...),
          ],
        ),
        ExamSubject(
          subject: '综合', label: '综合应用能力',
          defaultQuestionCount: 3, defaultTimeLimitSeconds: 9000, totalScore: 150,
          categories: [
            SubjectCategory(category: '综合应用', label: '综合应用能力', ...),
          ],
        ),
      ],
    ),
    ExamSubType(id: 'typeB', label: '社会科学专技类(B类)', subjects: [/* ... */]),
    ExamSubType(id: 'typeC', label: '自然科学专技类(C类)', subjects: [/* ... */]),
  ],
)
```

### 1.3 新建 `UserExamTarget` 模型

**文件**: `lib/models/user_exam_target.dart`

```dart
@JsonSerializable()
class UserExamTarget {
  final int? id;
  final String examCategoryId;   // 对应 ExamCategory.id
  final String subTypeId;        // 对应 ExamSubType.id，无则为 ''
  final String province;         // 省份，无则为 ''
  final int isPrimary;           // 1=主目标（v1 始终为 1）
  final String? targetExamDate;  // 目标考试日期（可选，后续完善）
  final String? createdAt;
  final String? updatedAt;
}
```

### 1.4 数据库迁移 v11

**文件**: `lib/db/database_helper.dart`

- 版本 10 → 11（将 `_initDB()` 中 `openDatabase(..., version: 10)` 改为 `version: 11`）
- 新增 `user_exam_targets` 表
- 在 `_onUpgrade` 的 `if (oldVersion < 11)` 块中执行
- **不修改现有表结构**

```sql
CREATE TABLE IF NOT EXISTS user_exam_targets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  exam_category_id TEXT NOT NULL,
  sub_type_id TEXT DEFAULT '',
  province TEXT DEFAULT '',
  is_primary INTEGER DEFAULT 0,
  target_exam_date TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(exam_category_id, sub_type_id, province)
);
```

> 不建单列索引 — 表最多几行，索引无收益。UNIQUE 约束防止重复目标。

**注意**: 同时在 `_createDB()` 方法中添加此建表语句（新装用户直接创建 v11 schema，不经过 onUpgrade）。

### 1.5 新建 `ExamCategoryService`

**文件**: `lib/services/exam_category_service.dart`

```dart
class ExamCategoryService extends ChangeNotifier {
  // 状态
  UserExamTarget? _primaryTarget;
  ExamCategory? _activeCategory;
  ExamSubType? _activeSubType;
  bool _isExploreMode = false;   // 探索模式（未选择具体目标）

  // 关键 getter
  bool get hasTarget => _primaryTarget != null && _activeCategory != null;
  bool get isExploreMode => _isExploreMode;
  ExamCategory? get activeCategory;
  ExamSubType? get activeSubType;
  List<ExamSubject> get activeSubjects;      // 解析后的科目列表
  List<String> get activeExamTypeValues;     // 用于 DB WHERE 过滤
  bool get hasEssay;                         // activeSubjects 中是否有申论/综合应用能力
  bool isFeatureSupported(Feature feature);  // 检查功能是否可用

  // CRUD (v1 单目标)
  Future<void> loadTargets();
  Future<void> setTarget(UserExamTarget target);     // 设置/替换当前目标
  Future<void> enterExploreMode();                   // 进入探索模式（默认国考配置，写入特殊标记到 DB）
  Future<void> removeTarget();
  Future<void> updateTargetDetails({String? province, String? subTypeId, String? targetExamDate}); // 后续完善信息

  // 供其他服务查询
  Map<String, dynamic> getExamConfig(String subject);  // {questionCount, timeLimit, totalScore}
  List<String> getSubjectsForPlan();                    // ['行测', '申论'] etc
}
```

**探索模式持久化**: `enterExploreMode()` 写入一条特殊 `UserExamTarget` 记录（`examCategoryId = '__explore__'`），`loadTargets()` 读到该标记时设置 `_isExploreMode = true` 并加载国考默认配置。这样 app 重启后不会重复显示引导页，且无需引入新存储机制。

**错误恢复**: `loadTargets()` 中若 Registry 无法匹配已保存的 `examCategoryId`（如 app 更新移除了某类型），自动清除该条目并进入探索模式。

### 1.6 Provider 注册

**文件**: `lib/main.dart`

在 provider 列表最前面注册 `ExamCategoryService`（`ChangeNotifierProvider`，无上游依赖），启动时调用 `loadTargets()`。

**下游服务不改为 ProxyProvider**，按需读取 ExamCategoryService:
- **Screen 层**: 通过 `Consumer<ExamCategoryService>` / `context.watch` 响应式重建
- **Service 层**: 在 main.dart 构造 Service 时，将 `ExamCategoryService` 实例作为构造函数参数注入（与现有 `ExamService(questionService)` 模式一致）。Service 持有引用但不监听变更 — 每次方法调用时读取当前值即可。不使用单例模式（`ExamCategoryService` 仍通过 `ChangeNotifierProvider` 管理生命周期，保持与现有架构一致）

**异步初始化时序**: `loadTargets()` 是异步操作。在 `main()` 中 `await` 完成后再构建 widget 树（与现有 `DatabaseHelper.instance.database` 初始化模式一致），避免 Consumer 在 `loadTargets()` 完成前读到空状态导致闪屏。

### 1.7 DB 查询方法增强

**文件**: `lib/db/database_helper.dart`

为以下方法增加可选 `List<String>? examTypes` 参数:

- `queryQuestions()` — 增加过滤条件
- `countQuestions()` — 同上
- `randomQuestions()` — 同上
- Dashboard 相关聚合查询（周对比、正确率、趋势等）

**SQL 参数化**: sqflite 不支持 `IN (?)` 直接传 List，需展开为占位符:

```dart
// 构建 WHERE 子句的辅助方法
String _buildExamTypeFilter(List<String> examTypes) {
  final placeholders = List.filled(examTypes.length, '?').join(', ');
  return '(exam_type IN ($placeholders) OR exam_type = \'\')';
}
```

> `OR exam_type = ''` 确保未标记类型的历史题目和通用题目始终可见，解决老用户升级后数据归属问题。

---

## Phase 2: 引导页与目标选择

### 2.1 简化版考试目标选择页

**文件**: `lib/screens/exam_target_screen.dart`

**首次启动仅 1 步必选**:

展示 7 张卡片（6 个考试类型 + 1 个"先看看再说"探索模式），每张卡片包含:
- 图标 + 考试类型名称 + 简要说明
- v1 内容状态标签（`partial` 显示"部分题库"、`comingSoon` 显示"即将上线"）
- `comingSoon` 卡片不可选择（降低透明度 + 禁用手势），点击弹 toast: "题库建设中，敬请期待"
- 底部提示: "随时可在「我的」中更改"

选择后的行为:
- **选择具体类型**: 写入 DB → 跳转主页
- **选择"先看看"**: 进入探索模式（默认国考配置）→ 跳转主页，顶部显示引导 Banner

**省份/子类型/日期不在引导页选择**，而是:
- 若考试类型有子类型（国考副省/地市、事业编ABCDE）→ 进入主页后，首次打开刷题页时弹出底部选择 Sheet
- 省份 → 在 ProfileScreen 的备考目标卡片中完善
- 考试日期 → 在用户首次打开看板或学习计划时提示设置

### 2.2 条件路由

**文件**: `lib/app.dart`

```dart
home: Consumer<ExamCategoryService>(
  builder: (ctx, service, _) {
    if (!service.hasTarget && !service.isExploreMode) {
      return const ExamTargetScreen();
    }
    return const HomeScreen();
  },
)
```

### 2.3 ProfileScreen 增加备考目标管理

**文件**: `lib/screens/profile_screen.dart`

- 顶部新增"备考目标"卡片，显示当前目标（如"国考 · 副省级"）或"探索模式"
- 点击进入目标详情编辑页: 可更改考试类型、补充省份、子类型、目标日期
- 探索模式下卡片醒目提示: "设置你的备考目标，获得个性化体验 →"

### 2.4 老用户升级引导

从 v10 升级到 v11 的用户:
- `user_exam_targets` 表为空 → `hasTarget == false` → 显示引导页
- 引导页增加说明: "选择备考目标后，你的历史学习记录将全部保留"
- 历史数据通过 `OR exam_type = ''` 查询条件自动包含（见 1.7）
- 不做回溯标记，避免错误归类

---

## Phase 3: 现有功能适配

### 通用规则

**空状态处理**: 每个适配页面在 `activeSubjects` 对应题库为零时，显示:
- "暂无{examType}专项题目，题库建设中"
- "先用通用题目练习" 按钮（清除 examType 过滤，显示全部题目）

**功能显隐**: 通过 `ExamCategory.supportedFeatures` 控制入口可见性。不支持的功能不显示入口（非灰色禁用）。

**切换目标时 UI 刷新**:
1. `ExamCategoryService.setTarget()` 先同步更新所有内存状态（`_activeCategory`、`_activeSubType`），再单次 `notifyListeners()`
2. `HomeScreen` 通过 `Consumer<ExamCategoryService>` 监听变更 → 重置 `IndexedStack` 当前索引为 0（回到刷题页）
3. `DashboardService` 缓存清除: `DashboardScreen` 监听 `ExamCategoryService` 变更（通过 `Consumer` 或 `context.watch`），在检测到目标变更后调用 `DashboardService.refreshDashboard(force: true)` 强制刷新。不由 `ExamCategoryService` 直接调用 `DashboardService`（避免违反分层: 基础设施服务不应依赖业务服务）
4. 显示 SnackBar: "已切换到{新目标}，内容已更新"

### 3.1 刷题页动态科目

**文件**: `lib/screens/practice_screen.dart`

- 删除硬编码的 `_subjects` 列表
- 从 `ExamCategoryService.activeSubjects` 动态构建科目网格
- 通过 `SubjectCategoryUI` 扩展获取 icon 和 gradient，保持现有 UI 风格
- 事业编用户看到"职测"/"综合"而非"行测"/"申论"
- 若某科目无题目 → 该卡片显示"暂无题目"标签 + 降低透明度

### 3.2 模考页动态参数

**文件**: `lib/screens/exam_screen.dart`

- 快速开始卡片从 `activeSubjects` 生成，每个科目一张卡
- 题量和时间从 `ExamCategoryService.getExamConfig(subject)` 获取
- 不再硬编码"130题·120分钟"

### 3.3 真题页默认过滤

**文件**: `lib/screens/real_exam_screen.dart`

- `loadPapers()` 默认传入 `activeExamTypeValues` 作为 examType 过滤
- 用户仍可手动切换查看其他类型

### 3.4 学习计划上下文增强 + 冲突处理

**文件**: `lib/services/study_plan_service.dart`

- `generatePlan()` 的 subjects 参数从 `ExamCategoryService.getSubjectsForPlan()` 获取
- AI prompt 注入考试类型上下文: "用户备考{examType}{subType}，目标省份{province}"

**目标切换时的学习计划冲突处理**:
1. 切换目标前，检查是否有 `status = 'active'` 的学习计划
2. 比较当前计划的 `subjects` 与新目标的 `activeSubjects`
3. 若科目集合不同 → 弹出确认对话框:
   - "当前有进行中的{旧目标}学习计划，切换目标后该计划将暂停。确定切换？"
   - 选项: "切换并暂停" / "取消"
4. 暂停的计划 `status` 设为 `paused`（现有 study_plans.status 字段已为 TEXT 类型，新增 'paused' 枚举值，与现有 'active'/'completed' 并列，无需 DB schema 变更）
5. `StudyPlanScreen` 中 paused 状态的计划显示为"已暂停"标签 + "恢复"按钮
6. 恢复逻辑: 将计划 status 改回 'active'，从暂停日期重新计算剩余任务
7. 若科目集合相同（如国考→省考，都是行测+申论）→ 静默切换，计划继续

### 3.5 面试题目动态分类

**文件**: `lib/services/interview_service.dart`

- 面试题分类从 `activeCategory.interviewCategories` 获取
- 不同考试类型可能有不同面试形式
- 若 `supportedFeatures` 不含 `interview`，面试入口不显示

### 3.6 考试日历智能过滤

**文件**: `lib/services/calendar_service.dart`

- 新增 `loadByExamType(examTypes, province)` 方法
- 日历页默认显示与用户目标匹配的考试事件
- 顶部增加"我的备考"/"全部考试"切换

### 3.7 AI 助手上下文感知

**文件**: `lib/services/assistant_service.dart`

- 在 main.dart 构造 AssistantService 时，将 ExamCategoryService 实例作为构造函数参数注入（与 1.6 节策略一致）
- system prompt 增加备考目标上下文
- 使 AI 对话自动适配用户的考试类型

### 3.8 统计页按类型聚合

**文件**: `lib/screens/stats_screen.dart`

- 按当前活跃考试类型过滤统计数据
- 科目名称动态显示

### 3.9 看板数据按类型过滤

**文件**: `lib/services/dashboard_service.dart`, `lib/screens/dashboard_screen.dart`

- `DashboardService` 方法调用时读取 `ExamCategoryService` 的 `activeExamTypeValues`
- `radarData` 轴从 `activeSubjects` 的 categories 动态生成
- `weekComparison`、`scoreTrend` 查询增加 examType 过滤
- `heatmapData` 保持全局（学习热度不按类型区分）
- 看板顶部增加**目标倒计时组件**: 若已设置 `targetExamDate`，显示"距{考试名}还有 D-X 天"
- 首次打开看板时若未设置考试日期 → 轻提示设置（非阻断弹窗）

### 3.10 申论训练条件显隐

**文件**: `lib/screens/profile_screen.dart` (入口), `lib/screens/essay_training_screen.dart`

- 当 `activeSubjects` 中无申论/综合应用能力科目时，隐藏申论训练入口
- 事业编 A 类的"综合应用能力"也纳入申论训练范畴（写作类科目）

### 3.11 错题分析与知识图谱按类型过滤

**文件**: `lib/services/wrong_analysis_service.dart`, `lib/screens/knowledge_map_screen.dart`

- `getErrorTypeDistribution()`、`getTopWrongCategories()` 增加可选 `examTypes` 过滤
- 知识图谱仅显示 `activeSubjects` 相关的科目分类

### 3.12 摸底测试动态科目

**文件**: `lib/services/baseline_service.dart`

- `startBaseline()` 的 `subjects` 参数从 `ExamCategoryService.getSubjectsForPlan()` 获取
- 不再使用硬编码科目列表

### 3.13 贡献题目默认科目

**文件**: `lib/screens/contribute_question_screen.dart`（如存在）

- 默认科目从 `activeSubjects[0].subject` 获取，而非硬编码 '行测'

### 3.14 摸底测试页硬编码移除

**文件**: `lib/screens/baseline_test_screen.dart`

- 删除硬编码的科目列表（当前第48行 `_selectedSubjects = {'行测', '申论'}` 和第53-63行的科目定义）
- 从 `ExamCategoryService.activeSubjects` 动态获取可选科目
- 默认选中全部活跃科目

### 3.15 学习计划页硬编码移除

**文件**: `lib/screens/study_plan_screen.dart`

- 删除硬编码的 `selectedSubjects = {'行测', '申论'}`（第61行）和 `['行测', '申论', '公基']`（第77行）
- 从 `ExamCategoryService.activeSubjects` 动态获取

### 3.16 考试日历页硬编码移除

**文件**: `lib/screens/exam_calendar_screen.dart`

- 删除硬编码的 `_examTypes = ['国考', '省考', '事业编', '选调']`
- 筛选选项从 `ExamCategoryRegistry.allCategories.map((c) => c.label)` 动态生成
- 默认选中与当前目标匹配的类型

---

## Phase 4: UI 增强

### 4.1 全局考试类型指示器

**文件**: `lib/widgets/exam_type_badge.dart`（新建）, `lib/screens/home_screen.dart`

- `HomeScreen` 的 `IndexedStack` 上方增加一条持久化彩色指示条（24-32px 高）
- 显示当前目标: "国考 · 副省级" 或 "探索模式"
- 右侧"更改"文字按钮 → 点击导航到 ProfileScreen 的备考目标编辑
- 探索模式下指示条背景更醒目（如橙色），文案: "设置备考目标 →"

> v1 不支持多目标快速切换。仅显示当前目标 + 更改入口。

---

## 关键文件清单

| 操作 | 文件 |
|------|------|
| **新建** | `lib/models/exam_category.dart` — ExamCategory/ExamSubject/ExamSubType/SubjectCategory 模型（纯数据，无 UI 类型） |
| **新建** | `lib/models/exam_category_registry.dart` — 全部考试类型的静态配置注册表（含完整数据示例） |
| **新建** | `lib/models/user_exam_target.dart` — 用户备考目标模型 |
| **新建** | `lib/services/exam_category_service.dart` — 考试类型中心服务 |
| **新建** | `lib/screens/exam_target_screen.dart` — 简化考试目标选择引导页 |
| **新建** | `lib/widgets/exam_type_badge.dart` — 全局考试类型指示器 |
| **修改** | `lib/db/database_helper.dart` — v10→v11 迁移（新增 user_exam_targets 表，version 改为 11）+ 查询方法增加 examTypes 参数 |
| **修改** | `lib/main.dart` — 注册 ExamCategoryService |
| **修改** | `lib/app.dart` — 条件路由（无目标且非探索→引导页） |
| **修改** | `lib/screens/practice_screen.dart` — 动态科目列表 |
| **修改** | `lib/screens/exam_screen.dart` — 动态考试参数 |
| **修改** | `lib/screens/real_exam_screen.dart` — 默认 examType 过滤 |
| **修改** | `lib/screens/profile_screen.dart` — 备考目标管理入口 |
| **修改** | `lib/screens/home_screen.dart` — 指示器 + 切换刷新 |
| **修改** | `lib/services/dashboard_service.dart` — 按类型过滤 + 缓存清除 |
| **修改** | `lib/screens/dashboard_screen.dart` — 动态雷达轴 + 倒计时 |
| **修改** | `lib/services/study_plan_service.dart` — 科目参数 + AI 上下文 + 冲突处理 |
| **修改** | `lib/services/interview_service.dart` — 动态面试分类 |
| **修改** | `lib/services/calendar_service.dart` — 按考试类型过滤 |
| **修改** | `lib/services/assistant_service.dart` — 注入考试类型上下文 |
| **修改** | `lib/services/wrong_analysis_service.dart` — 按类型过滤 |
| **修改** | `lib/services/baseline_service.dart` — 动态科目 |
| **修改** | `lib/screens/stats_screen.dart` — 按考试类型过滤统计数据 |
| **修改** | `lib/screens/knowledge_map_screen.dart` — 按活跃科目过滤知识图谱 |
| **修改** | `lib/screens/exam_calendar_screen.dart` — 移除硬编码考试类型，动态生成筛选项 |
| **修改** | `lib/screens/baseline_test_screen.dart` — 移除硬编码科目列表 |
| **修改** | `lib/screens/study_plan_screen.dart` — 移除硬编码科目列表 |

## 迁移策略

1. **DB 迁移仅新增表**，不修改现有表 → 零数据丢失风险
2. **升级后首次启动**：`hasTarget == false` 且非探索模式 → 显示引导页 → 用户选择目标或探索模式
3. **历史数据兼容**: 查询条件使用 `WHERE exam_type IN (?) OR exam_type = ''`，无类型标签的历史数据始终可见
4. **现有 exam_type 字段值**（'国考'/'省考'/'事业编'/'选调'）通过 `ExamCategory.dbExamTypeValues` 映射（含别名如 '事业单位'），无需数据迁移
5. **现有题目/答题记录**全部保留，选择目标后自动按类型过滤展示

## 验证方案

### 单元测试

- `ExamCategoryRegistry`: 所有已注册类型返回有效配置（subjects 非空、dbExamTypeValues 非空、SubType.subjects 已预解析）
- `ExamCategoryService`: setTarget / removeTarget / enterExploreMode / loadTargets 状态变更正确
- `ExamCategoryService`: Registry 中不存在的 examCategoryId → 自动清除 + 进入探索模式
- `UserExamTarget`: fromJson / toJson / fromDb / toDb 序列化正确

### Widget 测试

- `PracticeScreen`: mock ExamCategoryService 返回事业编 A 类科目 → 验证显示"职测"/"综合"而非"行测"/"申论"
- `ExamTargetScreen`: 7 张卡片正确渲染（6 类型 + 探索），点击写入 DB

### 集成测试矩阵（手动）

| 场景 | 验证点 |
|------|--------|
| **首次启动选国考副省级** | 引导页1步 → 进入主页 → 刷题显示行测5类+申论 → 模考130题120分钟 |
| **首次启动选"先看看"** | 进入探索模式 → 顶部 Banner 引导设置目标 → 默认国考配置 |
| **切换到事业编 A 类** | 刷题显示"职测"/"综合" → 模考参数变化 → 申论训练入口隐藏 → 看板雷达轴更新 |
| **省考+浙江** | 真题页默认过滤为浙江省考 → 日历显示浙江考试事件 |
| **从 v10 升级** | 现有数据完整保留 → 显示引导页 → 选择后历史数据可见 |
| **学习计划冲突** | 有行测+申论计划 → 切换到事业编 → 弹出确认暂停 → 切回后可恢复 |
| **空题库处理** | 选择三支一扶 → 若无题目显示空状态 + "用通用题目练习"按钮 |

### DB 迁移测试

- 从 v10 升级到 v11 → 现有数据完整保留 → `user_exam_targets` 表创建成功
- UNIQUE 约束: 插入重复 `(examCategoryId, subTypeId, province)` → 报错

---

## 范围边界

### v1 包含
- 单目标选择（含探索模式）
- 6 类考试的基础配置（3 类完整、2 类简化、1 类 coming_soon）
- 8 省省考覆盖 + 通用默认
- 所有现有功能的动态适配
- 空状态处理
- 全局目标指示器

### v2 延后
- 多目标管理（添加多个目标、切换主目标、日历合并显示）
- 完整 34 省省考覆盖
- 人才引进完整支持
- 事业编 D/E 类（教师/医疗）专业科目
- 注册表远程更新（JSON 热更新）
- 底部导航栏按考试类型动态调整
- 响应式布局（桌面端导航栏 vs 手机底部导航）
- 备考进度激励系统（连续学习天数、备考就绪度评分）
