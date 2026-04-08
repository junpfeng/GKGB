# 进面分数线数据预置 — 开发日志

## 实现概要

将进面分数线数据获取从"用户运行时爬取"改为"开发阶段 Python 脚本批量爬取 → 清洗为标准 JSON → 打包为 app assets → 首次进入页面自动导入 SQLite"。

## 新增文件

| 文件 | 说明 |
|------|------|
| `assets/data/exam_entry_scores/index.json` | 数据文件索引 |
| `assets/data/exam_entry_scores/guokao_2024.json` | 2024 国考数据 (8条) |
| `assets/data/exam_entry_scores/guokao_2025.json` | 2025 国考数据 (6条) |
| `assets/data/exam_entry_scores/jiangsu_shengkao_2024.json` | 2024 江苏省考 (5条) |
| `assets/data/exam_entry_scores/jiangsu_shengkao_2025.json` | 2025 江苏省考 (3条) |
| `assets/data/exam_entry_scores/zhejiang_shengkao_2024.json` | 2024 浙江省考 (4条) |
| `assets/data/exam_entry_scores/zhejiang_shengkao_2025.json` | 2025 浙江省考 (2条) |
| `assets/data/exam_entry_scores/shanghai_shengkao_2024.json` | 2024 上海省考 (3条) |
| `assets/data/exam_entry_scores/shandong_shengkao_2024.json` | 2024 山东省考 (4条) |
| `assets/data/exam_entry_scores/shandong_shengkao_2025.json` | 2025 山东省考 (2条) |
| `assets/data/exam_entry_scores/jiangsu_shiyebian_2024.json` | 2024 江苏事业编 (4条) |
| `assets/data/exam_entry_scores/zhejiang_shiyebian_2024.json` | 2024 浙江事业编 (3条) |
| `assets/data/exam_entry_scores/shandong_shiyebian_2024.json` | 2024 山东事业编 (3条) |
| `tools/exam_score_scraper/scraper_base.py` | 爬虫基类（节流≥2s、UA、robots.txt） |
| `tools/exam_score_scraper/guokao_scraper.py` | 国考数据爬取（解析 gwy.com HTML 表格） |
| `tools/exam_score_scraper/shengkao_scraper.py` | 省考数据爬取（HTML + Excel 解析） |
| `tools/exam_score_scraper/shiyebian_scraper.py` | 事业编数据爬取 |
| `tools/exam_score_scraper/data_cleaner.py` | 数据清洗和标准化 |
| `tools/exam_score_scraper/export_json.py` | 导出为 app asset 格式 |
| `tools/exam_score_scraper/requirements.txt` | Python 依赖 |
| `tools/exam_score_scraper/README.md` | 工具使用说明 |

## 修改文件

| 文件 | 变更内容 |
|------|---------|
| `lib/services/exam_entry_score_service.dart` | 移除 fetchScores/importScores/_isFetching/Dio；新增 loadFromAssets/_isDataLoaded/_isImporting；examTypes 扩展为 ['国考','省考','事业编'] |
| `lib/screens/exam_entry_scores_screen.dart` | 移除 AppBar 爬取按钮/\_showFetchDialog/\_doFetch；initState 中调用 loadFromAssets；空状态文案更新 |
| `pubspec.yaml` | 新增 `assets/data/exam_entry_scores/` 资产注册 |

## 关键决策说明

1. **loadFromAssets 调用时机**：在 ExamEntryScoresScreen 的 initState 中通过 addPostFrameCallback 触发（先 _isDataLoaded 检查，已导入则跳过），异步执行不阻塞 UI，保持 main.dart lazy Provider 不变。
2. **examTypes 常量**：更新为 `['国考', '省考', '事业编']`，事业编 A/B/C 类信息统一记录在 otherReq 字段。
3. **数据拆分策略**：国考按年份拆分、省考和事业编按省份+年份拆分，与 real_exam/ 的 index.json 模式保持一致。
4. **Python 爬虫数据源**：经调研确定华图教育（huatu.com）各省站为最佳结构化数据源，山东站支持 Excel 下载，其他省份解析 HTML 表格。国考使用上岸鸭（gwy.com）汇总页。
5. **无 schema 变更**：复用已有 exam_entry_scores 表（v13），无需 version bump。
6. **无新增 ChangeNotifier**：复用 ExamEntryScoreService，main.dart Provider 注册不变。

## 遇到的问题及解决

1. **Dio import 残留**：移除 fetchScores 等方法后，Dio import 变为无用，一并移除，flutter analyze 通过。
2. **isFetching getter 引用**：Screen 中的 AppBar actions 使用了 service.isFetching，移除 actions 块后不再有引用，Service 中也移除了 _isFetching 字段，改为 _isImporting 表示导入状态。

## 验收状态

- [x] 爬取工具存在：`tools/exam_score_scraper/scraper_base.py`
- [x] 运行时爬取已移除：`grep -c "fetchScores" lib/services/exam_entry_score_service.dart` → 0
- [x] 爬取 UI 已移除：`grep -c "_showFetchDialog" lib/screens/exam_entry_scores_screen.dart` → 0
- [x] asset 文件存在：`assets/data/exam_entry_scores/index.json`
- [x] pubspec.yaml 注册：`grep "exam_entry_scores" pubspec.yaml` → ✓
- [x] 事业编支持：`grep "事业编" lib/services/exam_entry_score_service.dart` → ✓
- [x] 首次导入方法存在：`grep "loadFromAssets" lib/services/exam_entry_score_service.dart` → ✓
- [x] 全部测试通过：`flutter test` → 54 tests passed
- [x] 零 analyze 错误：`flutter analyze` → No issues found
