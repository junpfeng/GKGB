# 真题分类整理与入口适配

## 核心需求
将所有的真题分门别类的整理到app相应的入口处，app的各个入口也要做出相应的调整。

## 调研上下文

### 现有入口
- PracticeScreen 有 3 个 Tab：科目练习 | 错题本 | 真题
- 真题 Tab 内是 RealExamScreen，有三级联动筛选（考试类型→地区→年份）
- ExamScreen（模拟考试）只有随机组卷，无真题模考入口
- 科目练习 Tab 不区分真题和普通题

### 数据现状
- 4794+ 道真题已在本地 assets 和 SQLite 中
- 覆盖国考(2020-2025)、江苏/山东/上海/浙江省考(2020-2025)
- 每题有 subject/category/exam_type/region/year/is_real_exam 字段

### 关键代码
- QuestionService: loadRealExamQuestions(), countRealExamQuestions()
- RealExamService: loadPapers(), ensureSampleData()
- ExamService: startPaperExam()
- DatabaseHelper: queryRealExamQuestions(), getDistinctValues()

## 范围边界
- 做：3 个页面 UI 改造 + 2 个 service 方法扩展
- 不做：新增爬虫、数据模型变更、数据库 schema 变更、LLM 调用、新页面

## 初步理解
在现有三处页面（科目练习、真题Tab、模拟考试）增加真题入口，让用户从不同维度都能便捷触达真题。

## 待确认事项
无（已全部确认）

## 确认方案

### 锁定决策

数据层：
  - 无新增模型，无数据库变更
  - 复用现有 Question、RealExamPaper 模型和查询方法
  - 复用 QuestionService.loadRealExamQuestions()、countRealExamQuestions() 等

服务层：
  - 无新增 service
  - 扩展 QuestionService：新增 countRealExamByCategory(subject, category) 方法
    返回某科目某分类下的真题数量
  - 扩展 RealExamService：新增 loadPapersGrouped() 方法
    按(examType, region, year)分组返回试卷列表供模考页使用

UI 层：
  修改 3 个现有页面，无新增页面：
  
  1. PracticeScreen「科目练习」Tab：
     - 每个知识点分类卡片（言语理解/数量关系等）右上角显示真题数量角标
     - QuestionListScreen 增加「仅看真题」筛选开关（FilterChip）
     - 开启后只展示 is_real_exam=1 的题目，附带年份标签
  
  2. RealExamScreen「真题」Tab（保持现有三级筛选不变）：
     - 优化：顶部增加快捷统计卡片，展示各考试类型的真题总数
     - 优化：筛选结果中的题目卡片增加知识点分类标签
  
  3. ExamScreen「模拟考试」页：
     - 新增「真题模考」区域（Section），展示在现有"快速模考"区域下方
     - 按考试类型分组展示可用试卷（国考/江苏/山东/上海/浙江）
     - 每个试卷卡片显示：名称、年份、题量、时间
     - 点击直接调用 ExamService.startPaperExam() 开始整套模考

主要技术决策：
  - 不新建页面：所有改动在现有 3 个 screen 内完成
  - 真题筛选用 FilterChip：轻量组件，一个开关即可切换
  - 模考区域用 ListView.builder：试卷列表懒加载
  - 复用现有 Provider：QuestionService 和 RealExamService 已是 ChangeNotifier

技术细节：
  - QuestionService 新方法签名：
    Future<int> countRealExamByCategory({String? subject, String? category})
    Future<List<Question>> loadQuestions({..., bool? realExamOnly})
  - RealExamService 新方法签名：
    Future<Map<String, List<RealExamPaper>>> loadPapersGroupedByExamType()
  - PracticeScreen 改动：_SubjectList 中每个 SubjectCategory 卡片
    加载时查询真题数量并显示角标
  - ExamScreen 改动：_ExamHomeView 底部新增 _RealExamSection widget
  - RealExamScreen 改动：顶部插入 _QuickStatsBar widget

范围边界：
  - 做：3 个页面 UI 改造 + 2 个 service 方法扩展
  - 不做：新增爬虫/数据获取、数据模型变更、数据库 schema 变更、LLM 调用、新页面

### 待细化
  - 真题角标的具体视觉样式（颜色/位置）
  - 模考区域的试卷卡片排序规则（按年份降序）

### 验收标准
  - [mechanical] QuestionService 含 realExamOnly 参数：判定 grep "realExamOnly" lib/services/question_service.dart
  - [mechanical] ExamScreen 含真题模考入口：判定 grep "真题模考" lib/screens/exam_screen.dart
  - [mechanical] PracticeScreen 含真题角标：判定 grep "realExamCount\|真题" lib/screens/practice_screen.dart
  - [test] 全量测试通过：flutter test
  - [manual] 运行 flutter run -d windows：
    - 科目练习 Tab 各分类卡片显示真题数量
    - 点进某分类后可开启「仅看真题」筛选
    - 模拟考试页有「真题模考」区域，可选择整套试卷开始模考
    - 真题 Tab 顶部显示各类型统计数字
