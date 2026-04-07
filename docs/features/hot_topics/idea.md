# 时政热点与申论素材库

## 核心需求
基于 `docs/advanced-features-design.md` 第四章，提供时政热点浏览（AI 摘要+考点提炼）、申论素材库（按主题/类型分类）、申论写作训练（AI 批改）。

## 调研上下文
- DB version = 7，已有 fl_chart / flutter_markdown / LlmManager
- 5 Tab 已满，需在已有页面增加入口
- QuestionService.gradeEssay() 已有申论批改能力（可复用 prompt 模式）
- Dio 已安装（可做 RSS 拉取）

## 范围边界
- 做：时政热点浏览（预置数据 + 手动添加）、AI 摘要/考点提炼、申论素材库（6 主题 × 4 类型）、申论写作训练（全文 + AI 批改）、3 张新表
- 不做：RSS 自动抓取（需 webfeed 包 + 定时任务，后续迭代）、分段训练（开头/分论点/结尾拆分）、范文对比、智能推荐

## 确认方案

核心思路：3 张新表（hot_topics / essay_materials / essay_submissions），HotTopicService 管理热点和素材 CRUD + AI 加工，EssayService 管理写作训练 + AI 批改，在个人页增加「时政热点」+「申论训练」入口。

### 锁定决策

**数据层：**

1. 新增 `hot_topics` 表：
   ```sql
   CREATE TABLE hot_topics (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     title TEXT NOT NULL,
     summary TEXT DEFAULT '',
     source TEXT DEFAULT '',
     source_url TEXT DEFAULT '',
     publish_date TEXT,
     relevance_score INTEGER DEFAULT 5,
     exam_points TEXT DEFAULT '',
     essay_angles TEXT DEFAULT '',
     category TEXT DEFAULT '',
     created_at TEXT DEFAULT CURRENT_TIMESTAMP
   )
   ```

2. 新增 `essay_materials` 表：
   ```sql
   CREATE TABLE essay_materials (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     theme TEXT NOT NULL,
     material_type TEXT NOT NULL,
     content TEXT NOT NULL,
     source TEXT DEFAULT '',
     is_favorited INTEGER DEFAULT 0,
     created_at TEXT DEFAULT CURRENT_TIMESTAMP
   )
   ```

3. 新增 `essay_submissions` 表：
   ```sql
   CREATE TABLE essay_submissions (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     topic TEXT NOT NULL,
     content TEXT NOT NULL,
     word_count INTEGER DEFAULT 0,
     time_spent INTEGER DEFAULT 0,
     ai_score REAL DEFAULT 0,
     ai_comment TEXT DEFAULT '',
     created_at TEXT DEFAULT CURRENT_TIMESTAMP
   )
   ```

4. DB version 7 → 8，_createDB 和 _onUpgrade 同步
5. 索引：`idx_hot_topics_date ON hot_topics(publish_date)`、`idx_essay_materials_theme ON essay_materials(theme, material_type)`、`idx_essay_submissions_date ON essay_submissions(created_at)`

**服务层：**

6. 新增 `HotTopicService extends ChangeNotifier`：
   - 注入 LlmManager
   - `loadTopics({category, limit, offset})` → 热点列表（分页）
   - `addTopic(title, content)` → 手动添加后 AI 自动生成摘要/考点/申论角度
   - `aiAnalyzeTopic(int topicId)` → streamChat 流式生成考点分析
   - `loadMaterials({theme, type, limit, offset})` → 素材列表
   - `toggleMaterialFavorite(int id)`
   - `loadFavoriteMaterials()` → 收藏素材

7. 新增 `EssayService extends ChangeNotifier`：
   - 注入 LlmManager
   - `startEssay(String topic, {int timeLimitMinutes: 60})` → 开始写作
   - `submitEssay(String content, int timeSpent)` → 调用 LLM 批改，返回 Stream<String>
   - `loadHistory({limit, offset})` → 写作历史
   - `getSubmission(int id)` → 单篇详情

8. AI 批改 prompt：复用 gradeEssay 模式，输入题目+作文 → 输出评分(0-100)+逐段点评+改进建议

**UI 层：**

9. 入口：ProfileScreen 菜单新增「时政热点」和「申论训练」两项

10. 新增 `lib/screens/hot_topics_screen.dart`：
    - 热点列表（卡片式，显示标题/摘要/关联度/日期）
    - 分类筛选（经济/社会/生态/文化/科技/乡村振兴）
    - 点击热点展开详情（考点提炼 + 申论角度）
    - FAB 手动添加热点

11. 新增 `lib/screens/essay_material_screen.dart`：
    - 按主题 Tab 分组（6 个主题）
    - 每个主题下按类型分组（名言金句/典型案例/政策表述/数据支撑）
    - 支持收藏

12. 新增 `lib/screens/essay_training_screen.dart`：
    - 申论写作训练主页：选择主题 → 限时写作（倒计时）→ 提交 → AI 流式批改
    - 底部历史列表

13. 新增模型：`HotTopic`、`EssayMaterial`、`EssaySubmission`

14. Provider 注册：HotTopicService + EssayService（均注入 LlmManager）

15. 预置数据 JSON：
    - `assets/data/hot_topics_sample.json`（10 条 2024-2025 时政热点）
    - `assets/data/essay_materials_sample.json`（6 主题 × 4 类型 × 2 条 = 48 条素材）

**红蓝预防性修正：**

16. AI 分析用 streamChat（考点/批改均流式展示）
17. 热点列表分页（limit+offset），ListView.builder 懒加载
18. essay_submissions.content 可能很长，列表页只查 topic/score/date，详情页单独查
19. 手动添加热点时 AI 生成摘要/考点用 chat() + timeout(30s) + 容错
20. 预置数据幂等导入（表非空跳过）

**范围边界：**
- 做：热点浏览/手动添加/AI 分析、素材库浏览/收藏、全文申论写作+AI 批改、预置数据
- 不做：RSS 自动抓取、分段训练、范文对比、智能推荐

### 待细化
- 预置热点和素材的具体内容
- AI 考点分析 prompt 细节
- 申论写作的主题预置列表

### 验收标准
- [mechanical] hot_topics 表：`grep -c "hot_topics" lib/db/database_helper.dart` >= 1
- [mechanical] essay_materials 表：`grep -c "essay_materials" lib/db/database_helper.dart` >= 1
- [mechanical] essay_submissions 表：`grep -c "essay_submissions" lib/db/database_helper.dart` >= 1
- [mechanical] HotTopicService：`ls lib/services/hot_topic_service.dart`
- [mechanical] EssayService：`ls lib/services/essay_service.dart`
- [mechanical] 3 个页面：`ls lib/screens/hot_topics_screen.dart lib/screens/essay_material_screen.dart lib/screens/essay_training_screen.dart`
- [mechanical] Provider 注册：`grep "HotTopicService\|EssayService" lib/main.dart`
- [mechanical] DB version 8：`grep "version: 8" lib/db/database_helper.dart`
- [mechanical] 入口在 ProfileScreen：`grep -c "热点\|申论\|hot_topic\|essay" lib/screens/profile_screen.dart` >= 1
- [test] `flutter test`
- [mechanical] `flutter analyze` 零错误
- [manual] 运行 `flutter run -d windows` 验证功能可用
