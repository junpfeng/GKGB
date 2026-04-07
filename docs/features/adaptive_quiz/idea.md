# AI 自适应智能出题

## 核心需求
基于 `docs/advanced-features-design.md` 第三章，实现知识点掌握度建模、智能出题策略（薄弱优先+遗忘曲线+难度递进）、AI 动态生成题目、学习效率分析。

## 确认方案

核心思路：新建 knowledge_points 和 mastery_scores 2 张表，AdaptiveQuizService 根据掌握度和遗忘曲线算法选题，题库不足时 LLM 动态生成，在刷题页新增「智能练习」入口。

### 锁定决策

**数据层：**

1. 新增 `knowledge_points` 表：
   ```sql
   CREATE TABLE knowledge_points (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     name TEXT NOT NULL,
     subject TEXT NOT NULL,
     category TEXT NOT NULL,
     parent_id INTEGER DEFAULT 0,
     sort_order INTEGER DEFAULT 0,
     UNIQUE(subject, category, name)
   )
   ```

2. 新增 `mastery_scores` 表：
   ```sql
   CREATE TABLE mastery_scores (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     knowledge_point_id INTEGER NOT NULL,
     score REAL DEFAULT 50,
     total_attempts INTEGER DEFAULT 0,
     correct_attempts INTEGER DEFAULT 0,
     last_practiced_at TEXT,
     next_review_at TEXT,
     updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
     FOREIGN KEY (knowledge_point_id) REFERENCES knowledge_points (id),
     UNIQUE(knowledge_point_id)
   )
   ```

3. DB version 8 → 9，_createDB 和 _onUpgrade 同步
4. 索引：`idx_mastery_scores_review ON mastery_scores(next_review_at)`、`idx_knowledge_points_subject ON knowledge_points(subject, category)`

**服务层：**

5. 新增 `AdaptiveQuizService extends ChangeNotifier`：
   - 注入 LlmManager
   - 知识点初始化：首次启动时根据 questions 表的 subject+category 自动生成知识点
   - `getNextQuestions({int count: 10, String? subject})` → 智能选题算法：
     a. 薄弱优先：mastery_score < 60 的知识点优先
     b. 遗忘曲线：next_review_at <= now 的知识点优先
     c. 难度递进：同知识点从 difficulty 低到高
   - `updateMastery(int knowledgePointId, bool isCorrect)` → 更新掌握度：
     - 正确：score += (100 - score) * 0.1
     - 错误：score -= score * 0.2
     - 更新 next_review_at（艾宾浩斯间隔：1/2/4/7/15/30 天）
   - `generateQuestion(String subject, String category, int difficulty)` → LLM 动态生成题目（题库不足时）
   - `getMasteryOverview({String? subject})` → 各知识点掌握度列表
   - `getLearningEfficiency({int days: 7})` → 近 N 天学习效率曲线数据
   - `getPredictedReadyDate(String subject, double targetScore)` → 预测达标日期

6. 遗忘曲线间隔算法：
   ```
   intervals = [1, 2, 4, 7, 15, 30] (天)
   reviewIndex = min(correct_streak, 5)
   next_review_at = now + intervals[reviewIndex]
   ```

7. AI 生成题目用 chat() + JSON 解析 + 容错，生成后存入 questions 表

**UI 层：**

8. 入口：PracticeScreen 科目列表 Tab 增加「智能练习」卡片（在面试入口下方）

9. 新增 `lib/screens/adaptive_quiz_screen.dart`：
   - 顶部：当前练习科目选择 + 掌握度总览进度条
   - 智能练习模式：自动选题，逐题作答，实时更新掌握度
   - 练习完成后显示掌握度变化摘要

10. 新增 `lib/screens/mastery_overview_screen.dart`：
    - 各科目知识点掌握度列表（进度条 + 分数 + 下次复习日期）
    - 按掌握度排序（薄弱在前）
    - 点击知识点进入该知识点专项练习

11. 新增模型：`KnowledgePoint`、`MasteryScore`

12. Provider 注册：ChangeNotifierProxyProvider<LlmManager, AdaptiveQuizService>

13. 预置知识点数据：根据现有 questions 表的 subject+category 组合自动生成（不需要额外 JSON）

**预防性修正：**

14. 知识点初始化幂等：检查 knowledge_points 表非空则跳过
15. AI 生成题目用 <generated> 标记 + difficulty 校验
16. 掌握度更新原子操作（事务）
17. 选题算法有 fallback：智能选题结果不足时补充随机题

**范围边界：**
- 做：知识点表、掌握度建模、薄弱优先+遗忘曲线+难度递进选题、AI 动态生成、掌握度总览、学习效率分析
- 不做：知识点关联图谱（前置依赖）、最佳学习时段分析

### 验收标准
- [mechanical] knowledge_points 表：`grep -c "knowledge_points" lib/db/database_helper.dart` >= 1
- [mechanical] mastery_scores 表：`grep -c "mastery_scores" lib/db/database_helper.dart` >= 1
- [mechanical] AdaptiveQuizService：`ls lib/services/adaptive_quiz_service.dart`
- [mechanical] 智能练习页：`ls lib/screens/adaptive_quiz_screen.dart`
- [mechanical] 掌握度总览页：`ls lib/screens/mastery_overview_screen.dart`
- [mechanical] Provider 注册：`grep "AdaptiveQuizService" lib/main.dart`
- [mechanical] DB version 9：`grep "version: 9" lib/db/database_helper.dart`
- [test] `flutter test`
- [mechanical] `flutter analyze` 零错误
- [manual] 运行 `flutter run -d windows` 验证智能练习可用
