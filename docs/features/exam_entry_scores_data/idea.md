# 进面分数线数据预置（exam_entry_scores_data）

## 核心需求
进面分数线所需要的数据，在开发阶段全部拉取和分析好，存入数据库。移除运行时爬取功能，改为 assets 预置数据 + 首次启动导入。

## 调研上下文

### 已有实现（exam_entry_scores 功能）
- **Model**: `lib/models/exam_entry_score.dart` — 21 字段，json_serializable + fromDb/toDb
- **DB**: `exam_entry_scores` 表（v13），含 3 个索引，完整 CRUD（upsert/batch/query/ranking/trend/cities/years/count）
- **Service**: `lib/services/exam_entry_score_service.dart` — 296 行，含联动筛选、分页查询、热度排行、趋势分析、运行时爬取（框架代码，_parseScoreData 未实现）
- **Screen**: `lib/screens/exam_entry_scores_screen.dart` — 980 行，双 Tab（列表+热度排行）、筛选栏、详情弹窗、趋势图
- **入口**: DashboardScreen 卡片导航

### 现有 asset 加载模式
项目已有成熟的 "JSON asset → rootBundle.loadString → 解析 → 写入 SQLite" 模式：
- `question_service.dart`: 7 个题库 JSON 文件
- `real_exam_service.dart`: index.json + 分目录批量导入
- `calendar_service.dart`, `hot_topic_service.dart` 等均使用此模式

### 需要变更的部分
1. **Service 层**: 移除 fetchScores()、_getDataSourceUrls()、_parseScoreData()、Dio import；新增 loadFromAssets() 首次导入逻辑
2. **Screen 层**: 移除爬取按钮 + 爬取对话框 + _doFetch 方法；空状态文案调整
3. **新增**: Python 爬取脚本 + JSON 数据文件 + pubspec.yaml asset 注册

## 范围边界
- 做：Python 爬取脚本、数据预处理、JSON asset 打包、首次启动导入、移除运行时爬取 UI
- 不做：运行时动态爬取、数据自动更新、爬取进度展示

## 初步理解
将数据获取从"用户运行时爬取"改为"开发阶段 Python 脚本批量爬取 → 清洗为标准 JSON → 打包为 app assets → 首次启动自动导入 SQLite"。复用所有已有查询/展示基础设施，仅改变数据来源。

## 待确认事项
见下方方案确认

## 确认方案

核心思路：Python 脚本开发阶段爬取国考/省考/事业编进面分数线 → 清洗为标准 JSON → 按省份年份拆分打包为 app assets → 首次启动静默导入 SQLite → 移除运行时爬取 UI。

### 锁定决策

数据层：
- 复用已有 ExamEntryScore model，不新增字段
- 复用已有 exam_entry_scores 表（v13），无 schema 变更
- 新增 JSON asset 文件：`assets/data/exam_entry_scores/index.json` + `{province}_{examType}_{year}.json`
- ExamEntryScoreService 新增 `examTypes` 常量扩展：`['国考', '省考', '事业编']`
- examType 字段值：事业编统一用 `'事业编'`，不再细分 A/B/C 类（类别信息记录在 otherReq 中）

服务层：
- ExamEntryScoreService 变更：
  - 移除：`fetchScores()`、`_getDataSourceUrls()`、`_parseScoreData()`、`importScores()`、`_isFetching` 状态、Dio import
  - 新增：`loadFromAssets()` — 首次启动从 assets 导入全量数据到 SQLite
  - 新增：`_isDataLoaded()` — 检查 SQLite 是否已有数据（避免重复导入）
  - 导入逻辑：读 index.json → 遍历文件列表 → rootBundle.loadString → 解析 → batchUpsertEntryScores
  - 导入时机：Screen initState 中首次触发（先 _isDataLoaded 检查，已导入则跳过），异步执行不阻塞 UI，保持 main.dart lazy Provider 注册不变
- 无 LLM 调用
- 无新增 package

UI 层：
- ExamEntryScoresScreen 变更：
  - 移除：AppBar 爬取按钮（cloud_download icon）、_showFetchDialog()、_doFetch()
  - 修改：空状态文案从"请先选择筛选条件或爬取数据"改为"请选择筛选条件查看数据"
  - 筛选栏 examTypes 增加 '事业编' 选项
- 无新增页面、无新增 ChangeNotifier

爬取工具（开发阶段使用，不打包进 app）：
- 目录：`tools/exam_score_scraper/`
- 语言：Python 3.x + requests + beautifulsoup4 + pandas
- 结构：
  - `scraper_base.py` — 基类（节流 ≥2s、User-Agent、robots.txt 检查）
  - `guokao_scraper.py` — 国考数据爬取
  - `shengkao_scraper.py` — 省考数据爬取（按省份分子类）
  - `shiyebian_scraper.py` — 事业编数据爬取（省级统考+地市级）
  - `data_cleaner.py` — 数据清洗和标准化
  - `export_json.py` — 导出为 app asset 格式
  - `requirements.txt` — Python 依赖
  - `README.md` — 使用说明
- 数据源：混合策略，官方优先（各省人事考试网、国家公务员局），第三方补充
- 输出：`assets/data/exam_entry_scores/` 目录下的标准 JSON 文件

主要技术决策：
- 复用已有基础设施：不新增 model/表/Provider，仅改变数据来源
- 按省份+考试类型+年份拆分 JSON：与 real_exam/ 的 index.json 模式一致
- 首次启动导入：不延迟到页面进入，确保数据随时可查
- Python 爬取工具独立于 Flutter 工程：放在 tools/ 目录，不影响 app 构建

范围边界：
- 做：Python 爬取脚本、数据清洗、JSON asset 打包、首次启动导入、移除运行时爬取 UI/逻辑、examTypes 扩展事业编
- 不做：运行时动态爬取、数据自动更新、爬取进度 UI、事业编 A/B/C 类细分筛选

### 待细化
- 具体爬取目标网站 URL 和 HTML 解析规则：由实现引擎根据实际网站结构确定
- 事业编各地市数据源清单：实现时调研确定
- index.json 的具体结构：由实现引擎参考 real_exam/index.json 设计

### 验收标准
- [mechanical] 爬取工具存在：判定 `ls tools/exam_score_scraper/scraper_base.py`
- [mechanical] 运行时爬取已移除：判定 `grep -c "fetchScores" lib/services/exam_entry_score_service.dart` 返回 0
- [mechanical] 爬取 UI 已移除：判定 `grep -c "_showFetchDialog" lib/screens/exam_entry_scores_screen.dart` 返回 0
- [mechanical] asset 文件存在：判定 `ls assets/data/exam_entry_scores/index.json`
- [mechanical] pubspec.yaml 注册：判定 `grep "exam_entry_scores" pubspec.yaml`
- [mechanical] 事业编支持：判定 `grep "事业编" lib/services/exam_entry_score_service.dart`
- [mechanical] 首次导入方法存在：判定 `grep "loadFromAssets" lib/services/exam_entry_score_service.dart`
- [test] 全部测试通过：`flutter test`
- [mechanical] 零 analyze 错误：`flutter analyze`
- [manual] 首次启动后进入分数线页面，数据已自动加载，无爬取按钮，筛选包含事业编选项
