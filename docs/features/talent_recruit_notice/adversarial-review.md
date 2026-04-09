# 方案对抗审查：talent_recruit_notice

## 审查类型
轻量审查（已有模块扩展，1 轮 checklist）

## 审查时间
2026-04-09

## Checklist

| # | 检查项 | 结果 | 说明 |
|---|--------|------|------|
| 1 | 分层依赖 | OK | CrawlerService(service层) → DatabaseHelper(db层) + LlmManager(service层)；PolicyMatchScreen(screen层) → CrawlerService(service层)。无反向依赖 |
| 2 | Provider 正确性 | OK | CrawlerService 依赖 LlmManager + MatchService，需用 ProxyProvider 或延迟注入。notifyListeners 用于进度更新 |
| 3 | SQLite 迁移 | OK | 新增 crawl_sources 表，version 19 → 20，onUpgrade 中 CREATE TABLE IF NOT EXISTS |
| 4 | API Key 安全 | OK | CrawlerService 不直接处理 API Key，通过 LlmManager 间接使用 |
| 5 | LLM 抽象 | OK | 仅调用 LlmManager.chat()，不 import 具体 Provider |
| 6 | 平台适配 | OK | Dio HTTP 请求在 Windows/Android 均可用，无平台特异代码 |

## 结论
0 CRITICAL / 0 HIGH — 通过，进入实现阶段。
