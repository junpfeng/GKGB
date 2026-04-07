# 诊断策略查找表

根据 bug 描述关键词匹配诊断动作。多条策略可同时命中。

| 关键词 | 诊断动作 | 工具 | 命中 | 有效 |
|--------|----------|------|------|------|
| **LLM / AI / 模型 / 回答 / 生成 / 对话** | ① 检查 LlmManager 配置和 fallback 逻辑 ② 检查 API Key 存储和读取 ③ grep 调用链确认走 LlmManager 而非直接调用 Provider | Grep + Read | 0 | 0 |
| **数据库 / 存储 / 丢失 / 数据 / SQLite** | ① 读取 database_helper.dart 检查 schema 版本和迁移 ② 检查相关表的索引和字段 ③ 搜索 rawQuery/rawInsert 确认 SQL 正确性 | Read + Grep | 0 | 0 |
| **状态 / Provider / 刷新 / 不更新 / 卡住** | ① grep ChangeNotifier 注册（main.dart MultiProvider）② 检查 notifyListeners() 调用点 ③ 检查 context.read/watch 使用方式 | Grep + Read | 0 | 0 |
| **题库 / 刷题 / 答题 / 做题 / 练习** | ① 读取 question_service.dart ② 检查题库数据加载逻辑 ③ 检查答题记录存储 | Read + Grep | 0 | 0 |
| **匹配 / 岗位 / 公告 / 人才 / 招聘** | ① 检查 match_engine / crawler_service（待建，见 product-design.md §3.2）② 检查 policy_match_screen.dart ③ 检查 user_profile 数据完整性 | Read + Grep | 0 | 0 |
| **导航 / 路由 / 跳转 / 页面切换 / 返回** | ① 读取 app.dart 路由配置 ② 读取 home_screen.dart 底部导航逻辑 ③ grep Navigator.push/pop 调用 | Read + Grep | 0 | 0 |
| **崩溃 / 闪退 / Exception / 报错 / 红屏** | ① flutter analyze 全量检查 ② flutter test 执行 ③ grep 未处理异常（try/catch 缺失） | Bash + Grep | 0 | 0 |
| **卡顿 / 慢 / 性能 / 发热 / 内存** | ① 检查 ListView 是否用 builder ② 检查 SQLite 查询是否有索引 ③ 检查 LLM 调用是否用 Stream 模式 ④ 检查 const 构造函数使用 | Grep + Read | 0 | 0 |
| **平台 / Windows / Android / 手机 / 桌面** | ① grep Platform.isAndroid/isWindows 使用位置 ② 检查平台特有代码是否在 services 层 ③ 检查 pubspec.yaml 平台依赖 | Grep + Read | 0 | 0 |
| **UI / 界面 / 显示 / 布局 / 样式 / 主题** | ① 读取相关 screen 文件 ② 检查 Material Design 3 主题配置（app.dart）③ 检查 const 构造函数 ④ 检查 super.key 参数 | Read + Grep | 0 | 0 |
| **无明显关键词** | ① flutter analyze ② flutter test ③ git log --oneline -10 查看最近变更 | Bash + Grep | 0 | 0 |

## 演化规则

- `命中次数 ≥5` 且 `有效次数/命中次数 < 20%` → 标记为低效
- 低效策略在下次 evolve.py 执行时被替换或删除
- 最多 25 条策略；满时替换有效率最低的
- 每次 evolve.py 最多变更 3 条策略
- 新增策略追加到"无明显关键词"行之前
