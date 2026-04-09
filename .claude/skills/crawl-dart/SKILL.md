# /crawl-dart — Dart CLI 公告抓取工具

## 描述
用 Dart CLI 工具抓取/查看/导出政府人社网站公告数据。支持全量抓取、按省份抓取、查看公告、统计概览、导出 JSON/CSV。

## 触发词
- /crawl-dart
- 用 Dart 工具抓取公告
- dart 爬虫
- dart 抓取公告

## 前置条件
- Dart SDK（C:/flutter/bin/dart）
- 环境变量（抓取时需要）：LLM_API_KEY, LLM_BASE_URL, LLM_MODEL（可选）

## 流程

### 1. 解析用户意图
根据用户描述判断操作类型：
- **抓取全部**: `--all`
- **抓取指定省份**: `--province 江苏,浙江`
- **列出站点**: `--list`
- **查看公告**: `--show [--province X]`
- **统计**: `--stats`
- **导出**: `--export json|csv [--province X]`

### 2. 检查环境
```bash
# 检查 Dart 是否可用
C:/flutter/bin/dart --version

# 如果是抓取操作，检查环境变量
echo $LLM_API_KEY
echo $LLM_BASE_URL
```

### 3. 执行命令
```bash
# 示例：列出站点
C:/flutter/bin/dart run bin/crawler_tool.dart --list

# 示例：抓取江苏省
C:/flutter/bin/dart run bin/crawler_tool.dart --province 江苏

# 示例：查看统计
C:/flutter/bin/dart run bin/crawler_tool.dart --stats

# 示例：导出 JSON
C:/flutter/bin/dart run bin/crawler_tool.dart --export json
```

### 4. 解读输出
- 汇总抓取报告（成功/失败站点数、新增公告数）
- 如有错误，分析原因并给出建议
- 对统计数据做简要解读

## 支持的省份
江苏、浙江、上海、安徽、山东（共 67 个站点）

## 数据库
默认使用 App 的 SQLite 数据库（exam_prep.db），可通过 `--db-path` 指定其他路径。
