---
paths:
  - "**"
---

# 考公考编智能助手 工程宪法

以下规则在本工程范围内具有最高优先级。

## 禁止操作

- 禁止直接修改 `android/` 和 `windows/` 下的 Flutter 自动生成文件（`generated_*`），平台配置除外
- 禁止在代码中硬编码 API Key、Token 等敏感信息，必须由用户在设置页输入并加密存储
- 禁止在日志中输出用户 API Key 或个人隐私数据（学历、身份证号等）
- 禁止绕过 `LlmManager` 直接调用具体模型 Provider

## 代码风格

- 文件名：小写下划线（`study_plan_screen.dart`）
- 类名：大驼峰（`StudyPlanScreen`）
- 变量/方法名：小驼峰（`matchScore`、`generatePlan()`）
- 私有成员：下划线前缀（`_database`、`_currentIndex`）
- 注释用中文，命名用英文
- Widget 构造函数必须包含 `{super.key}` 参数
- 使用 `const` 构造函数优化重建性能

## 架构约束

- **分层依赖方向**: screens → services → db/models，禁止反向依赖
- **状态管理**: 使用 Provider，Screen 层通过 `context.read/watch` 访问状态，禁止全局变量
- **数据模型**: 所有需要序列化的模型使用 `json_serializable`，手写 `fromJson/toJson` 仅用于简单场景
- **LLM 抽象**: 业务层只依赖 `LlmProvider` 接口和 `LlmManager`，不直接 import 具体 Provider 实现
- **平台适配**: 平台差异代码通过 `Platform.isAndroid` / `Platform.isWindows` 判断，集中在 services 层处理

## 数据安全

- 用户个人信息（画像数据）仅存储在本地 SQLite，上传云端前必须经过用户明确授权
- API Key 使用 `flutter_secure_storage` 或等效加密方案存储，禁止 SQLite 明文存储
- 公告抓取遵守 robots.txt 协议，设置合理请求间隔（≥2s），携带 User-Agent 标识
- 爬取的公告数据仅用于本地匹配分析，禁止二次分发

## 性能约束

- SQLite 查询必须建立适当索引，题库查询响应 < 100ms
- LLM 调用使用 Stream 模式展示，避免长时间无响应
- 列表页使用 `ListView.builder` 懒加载，禁止一次性加载全部数据
- 图片资源使用 `cached_network_image` 或等效缓存方案
