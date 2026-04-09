# /crawl-py — Python 公告抓取工具

## 描述
用 Python 脚本抓取/查看/导出政府人社网站公告数据。轻量备选方案，功能与 Dart CLI 对等。

## 触发词
- /crawl-py
- 用 Python 工具抓取公告
- python 爬虫
- python 抓取公告

## 前置条件
- Python 3.10+
- 环境变量（抓取时需要）：LLM_API_KEY, LLM_BASE_URL, LLM_MODEL（可选）

## 流程

### 1. 检查 Python 环境并安装依赖
```bash
python --version
pip install -r tool/requirements.txt
```

### 2. 解析用户意图
根据用户描述判断操作类型：
- **抓取全部**: `--all`
- **抓取指定省份**: `--province 江苏,浙江`
- **列出站点**: `--list`
- **查看公告**: `--show [--province 江苏]`
- **统计**: `--stats`
- **导出**: `--export json|csv [--province 江苏]`

### 3. 执行命令
```bash
# 示例：列出站点
python tool/crawl.py --list

# 示例：抓取江苏省
python tool/crawl.py --province 江苏

# 示例：查看统计
python tool/crawl.py --stats

# 示例：导出 CSV
python tool/crawl.py --export csv
```

### 4. 解读输出
- 汇总抓取报告（成功/失败站点数、新增公告数）
- 如有错误，分析原因并给出建议
- 对统计数据做简要解读

## 支持的省份
江苏、浙江、上海、安徽、山东（共 67 个站点）

## 数据库
默认使用 App 的 SQLite 数据库（exam_prep.db），可通过 `--db-path` 指定其他路径。
