# 申论小题多名师答案对比 设计方案

## 1. 背景

考生在备考申论小题（概括、分析、对策、应用文）时，需要参考多位名师的答案来理解不同答题角度和得分点。目前只能在小红书逐个搜索，效率低且答案不全。类似微信小程序"囊中对比"，但答案更全、免费。

**目标名师**：袁东、飞扬、千寻、唐棣、kiwi 等
**目标机构**：粉笔、华图、中公、四海、超格、上岸村 等

**现有基础**：`EssayService` 已实现 AI 批改功能，但无多名师答案对比能力。

## 2. 数据模型

### 2.1 新表：`essay_sub_questions`（申论小题）

```sql
CREATE TABLE essay_sub_questions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  year INTEGER NOT NULL,
  region TEXT NOT NULL,
  exam_type TEXT NOT NULL,           -- 国考/省考/事业编
  exam_session TEXT DEFAULT '',      -- 副省级/地市级（国考区分）
  question_number INTEGER NOT NULL,  -- 第几题
  question_text TEXT NOT NULL,       -- 题目原文
  question_type TEXT DEFAULT '',     -- 概括/分析/对策/应用文/大作文
  material_summary TEXT DEFAULT '',  -- 给定材料摘要
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(year, region, exam_type, exam_session, question_number)
);
```

### 2.2 新表：`teacher_answers`（名师答案）

```sql
CREATE TABLE teacher_answers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sub_question_id INTEGER NOT NULL,
  teacher_name TEXT NOT NULL,          -- 名师/机构名称
  teacher_type TEXT DEFAULT 'teacher', -- 'teacher' 或 'institution'
  answer_text TEXT NOT NULL,           -- 参考答案全文
  score_points TEXT DEFAULT '',        -- JSON：提取的得分要点列表
  word_count INTEGER DEFAULT 0,
  source_note TEXT DEFAULT '',         -- 答案来源备注
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sub_question_id) REFERENCES essay_sub_questions (id),
  UNIQUE(sub_question_id, teacher_name)
);
```

### 2.3 新表：`user_composite_answers`（用户综合答案）

```sql
CREATE TABLE user_composite_answers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sub_question_id INTEGER NOT NULL,
  content TEXT NOT NULL,
  notes TEXT DEFAULT '',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sub_question_id) REFERENCES essay_sub_questions (id)
);
```

### 2.4 新模型文件

- `lib/models/essay_sub_question.dart`
- `lib/models/teacher_answer.dart`
- `lib/models/user_composite_answer.dart`

使用 `json_serializable`，提供 `fromDb()` / `toDb()` / `copyWith()` 方法。

### 2.5 预置数据

`assets/data/essay_sub_questions_preset.json`

## 3. Service 设计

**新文件：`lib/services/essay_comparison_service.dart`**

```dart
class EssayComparisonService extends ChangeNotifier {
  // 启动时导入预置数据（幂等）
  Future<void> importPresetData();

  // 按年份/省份/考试类型筛选试卷
  Future<List<EssaySubQuestion>> loadExams({int? year, String? region, String? examType});

  // 获取某套试卷的所有小题
  Future<List<EssaySubQuestion>> loadSubQuestions({
    required int year, required String region, required String examType,
  });

  // 获取某道小题的所有名师答案
  Future<List<TeacherAnswer>> loadTeacherAnswers(int subQuestionId);

  // 保存/更新用户综合答案
  Future<void> saveCompositeAnswer(int subQuestionId, String content, {String? notes});

  // AI 分析：提取各答案共同得分要点、差异点、建议综合策略
  Future<String> analyzeWithAI(int subQuestionId);

  // 名师/机构统计（覆盖题目数等）
  Future<Map<String, int>> getTeacherStats();
}
```

依赖：`DatabaseHelper`、`LlmManager`

## 4. UI 设计

**新文件：`lib/screens/essay_comparison_screen.dart`**

### 4.1 三级导航结构

```
试卷选择（筛选栏：年份/省份/考试类型）
  └─ 小题列表（显示题号 + 题型徽章 + 答案数量）
       └─ 答案对比页（核心页面）
```

### 4.2 答案对比页布局

- **顶部**：题目原文（可折叠）
- **中部**：横滑 PageView，每页一个名师答案卡片
  - 卡片内容：名称、答案文本、字数、来源标注
  - 切换按钮：卡片模式 ↔ 列表模式（纵向滚动查看所有答案）
- **底部**：用户综合答案编辑区 + "AI 分析"按钮
  - AI 分析结果：共同得分要点高亮、各答案差异对比、综合建议

## 5. 集成

### 5.1 DB 迁移

在 `database_helper.dart` 的 `onUpgrade` 中新增 3 张表。使用独立的版本号条件（如 `if (oldVersion < 15)`），与其他功能的表创建互不干扰。

### 5.2 Provider 注册

```dart
// main.dart
final essayComparisonService = EssayComparisonService(db, llmManager);
await essayComparisonService.importPresetData();

// MultiProvider
ChangeNotifierProvider.value(value: essayComparisonService),
```

### 5.3 入口点

`PracticeScreen` 中申论分类下新增"小题对比"入口，与现有"申论训练"并列。

### 5.4 修改文件清单

| 文件 | 变更 |
|------|------|
| `lib/db/database_helper.dart` | 新增 3 张表 |
| `lib/main.dart` | 注册 EssayComparisonService |
| `lib/screens/practice_screen.dart` | 申论分类新增入口 |
| `pubspec.yaml` | 注册 asset 文件 |

## 6. 复杂度与风险

**复杂度：中高**

**核心风险是内容收集**：代码开发量中等，但每道题需收集 6-10 位名师答案，工作量大。

**建议**：
- v1 先覆盖 2024-2025 国考 + 2-3 个热门省考，每题 5-6 位名师
- 后续通过社区贡献或爬虫辅助扩充
- 内容收集应与其他功能的开发并行启动
