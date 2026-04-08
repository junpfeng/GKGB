# 真题题库功能实现日志

## 实现日期
2026-04-08

## 实现概述

基于 `idea.md` 的确认方案，完整实现了 2020-2025 年真题数据导入基础设施，包括 Python 爬虫工具链、代表性示例 JSON 数据、Flutter 批量导入逻辑和测试。

---

## 实现清单

### 新建文件

**Python 爬虫工具链（tools/scraper/）**
- `tools/scraper/requirements.txt` — Python 依赖（requests, beautifulsoup4, selenium, lxml）
- `tools/scraper/config.py` — 配置文件（URL、请求间隔≥2s、UA、覆盖范围）
- `tools/scraper/base_scraper.py` — 基类（robots.txt检查、限速、重试/指数退避）
- `tools/scraper/fenbi_scraper.py` — 粉笔网爬虫框架（API结构TODO已标注）
- `tools/scraper/qzzn_scraper.py` — QZZN论坛爬虫框架（正则提取题目逻辑完整）
- `tools/scraper/gov_scraper.py` — 各省人事考试网爬虫框架（通用链接扫描逻辑）
- `tools/scraper/xiaohongshu_scraper.py` — 小红书爬虫框架（默认关闭，OCR接入点已预留）
- `tools/scraper/normalizer.py` — 数据标准化（字段映射、别名归一化、验证）
- `tools/scraper/dedup.py` — MD5内容去重（同源去重+跨源增量去重）
- `tools/scraper/main.py` — 主入口（调度各爬虫→标准化→去重→分文件输出）
- `tools/scraper/README.md` — 使用说明

**JSON 资源文件（assets/questions/real_exam/）**
- `assets/questions/real_exam/index.json` — 文件索引（Flutter端批量加载用）
- `assets/questions/real_exam/guokao/全国_2020_行测.json` — 国考行测2020（5题）
- `assets/questions/real_exam/guokao/全国_2021_行测.json` — 国考行测2021（4题）
- `assets/questions/real_exam/guokao/全国_2022_行测.json` — 国考行测2022（5题）
- `assets/questions/real_exam/guokao/全国_2023_行测.json` — 国考行测2023（8题）
- `assets/questions/real_exam/guokao/全国_2024_行测.json` — 国考行测2024（10题）
- `assets/questions/real_exam/guokao/全国_2025_申论.json` — 国考申论2025（3题）
- `assets/questions/real_exam/shengkao/江苏_2024_行测.json` — 江苏省考2024（5题）
- `assets/questions/real_exam/shengkao/浙江_2024_行测.json` — 浙江省考2024（4题）
- `assets/questions/real_exam/shengkao/上海_2023_行测.json` — 上海省考2023（4题）
- `assets/questions/real_exam/shengkao/山东_2022_行测.json` — 山东省考2022（3题）
- `assets/questions/real_exam/shiyebian/全国_2022_公基.json` — 事业编公基2022（3题）
- `assets/questions/real_exam/shiyebian/全国_2024_公基.json` — 事业编公基2024（6题）

**测试文件**
- `test/real_exam_import_test.dart` — 导入逻辑测试（17个测试用例）

### 修改文件

- `pubspec.yaml` — 注册 `assets/questions/real_exam/` 三个子目录及 index.json
- `lib/services/real_exam_service.dart` — 扩展批量导入逻辑（`importRealExamDirectory`）
- `lib/db/database_helper.dart` — 新增 `getRealExamContentHashes()` 方法和 `dart:convert` 导入

---

## 关键设计决策

### 1. 资产目录枚举方案
Flutter 不支持运行时列举 assets 目录内容，通过 `assets/questions/real_exam/index.json` 维护文件列表解决。新增 JSON 文件时需同步更新 index.json 和 pubspec.yaml。

### 2. 内容哈希算法
采用 `(content + options).hashCode.toRadixString(16)` 代替 MD5（Dart 标准库无 MD5）。归一化步骤：去除空白→去除标点→转小写→去除选项前缀（`A. `）。Python 侧和 Dart 侧使用相同归一化逻辑。

### 3. 增量导入流程
```
app 启动 → ensureSampleData() → 检查 is_real_exam 数量 > 0 → 已导入则跳过
否则 → 导入旧版 real_exam_sample.json → importRealExamDirectory()
  → 读取 index.json → 遍历文件列表
  → 每题计算哈希 → 与 getRealExamContentHashes() 对比
  → 仅插入新题 → upsertPaperRecord() 更新试卷
```

### 4. 试卷 upsert 策略
同一（examType+region+year+subject）组合的试卷已存在时，追加题目 ID 而非重复创建试卷记录。

### 5. 爬虫框架完整度
核心框架（限速≥2s、robots.txt检查、重试、标准化、去重、输出）完整实现。各网站的具体页面解析逻辑（选择器/API endpoint）已标注 TODO，需实际调研目标网站后补全。

---

## 测试结果

- `flutter analyze`: 零错误零警告
- `flutter test`: 54/54 通过（新增17个，现有37个均通过）

---

## 验收标准达成情况

| 标准 | 状态 |
|------|------|
| 爬虫脚本存在 `ls tools/scraper/*.py` | 通过（9个.py文件） |
| JSON 数据文件存在 `ls assets/questions/real_exam/` | 通过（12个JSON文件+index） |
| Question 含 is_real_exam 查询逻辑 | 通过（现有字段，导入时设置=1） |
| `flutter test test/real_exam_import_test.dart` | 通过（17/17） |

---

## 待细化事项

1. 各爬虫的具体页面解析（fenbi API endpoint、qzzn HTML选择器、各省网站结构）
2. 小红书 OCR 识别接入（paddleocr 或云 OCR API）
3. 事业编各地考试科目差异（目前以公基为主，可按省份扩展）
4. 引入 `crypto` 包替换 hashCode 改用 MD5（与 Python 侧保持完全一致）
