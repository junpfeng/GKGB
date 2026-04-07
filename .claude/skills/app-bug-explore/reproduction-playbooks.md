# Flutter 复现策略

## 复现原则

1. **静态分析优先**：先 `flutter analyze`，零成本发现编译/类型错误
2. **自动化测试次之**：`flutter test` 复现可测试的逻辑 bug
3. **手动运行验证**：`flutter run` 实际操作复现 UI/交互 bug
4. **日志辅助**：`flutter logs` 实时查看设备日志

## 复现操作表

| Bug 类型 | 复现策略 |
|----------|---------|
| **数据库/存储问题** | ① flutter analyze 检查 SQL 语法 ② 读取 database_helper.dart 检查 schema 版本 ③ 检查 onUpgrade 迁移逻辑是否覆盖所有版本 ④ flutter test 执行数据库相关测试 |
| **Provider/状态问题** | ① grep notifyListeners 确认触发点 ② 检查 MultiProvider 注册顺序 ③ 检查 context.read vs context.watch 使用场景 ④ 编写 widget test 复现状态变更 |
| **LLM 调用问题** | ① 检查 LlmManager 配置（默认模型、fallback 链）② 检查 API Key 读取逻辑 ③ 检查 stream 模式错误处理 ④ 检查网络超时配置（Dio timeout） |
| **导航/路由问题** | ① 读取 app.dart 和 home_screen.dart 路由定义 ② grep Navigator 调用确认参数 ③ 检查 BottomNavigationBar index 管理 ④ flutter run 手动操作复现 |
| **UI/布局问题** | ① flutter analyze 检查 widget 构建 ② 读取相关 screen 文件检查 widget 树 ③ 检查 MediaQuery/LayoutBuilder 平台适配 ④ flutter run 分别在 Windows 和 Android 验证 |
| **性能问题** | ① grep ListView 确认用 builder 模式 ② 检查 SQLite 查询有索引 ③ 检查 LLM 调用用 Stream ④ 检查 Image 缓存策略 ⑤ flutter run --profile 性能分析 |
| **崩溃/Exception** | ① flutter analyze 全量扫描 ② flutter test 全量执行 ③ grep 未捕获异常路径 ④ 检查 null safety 边界 |
| **平台兼容问题** | ① grep Platform.isAndroid/isWindows ② 检查平台特有路径（path_provider）③ 分别在 Windows 和 Android 运行验证 |
| **JSON 序列化问题** | ① 检查 model 类的 @JsonSerializable 注解 ② 运行 dart run build_runner build ③ 检查生成的 .g.dart 文件 |

## 编写测试脚本的原则

1. **先搜索再写**：grep 确认类名/方法名存在后再编写测试
2. **最小复现**：每个测试只验证一个行为
3. **模板参考**：使用 `dart-templates.md` 中的测试模板
4. **独立运行**：测试不依赖外部状态（Mock 数据库、Mock 网络）
