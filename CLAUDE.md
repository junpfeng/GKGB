# 考公考编智能助手 (exam_prep_app)

跨平台考公考编辅助应用，支持 Windows 桌面端和 Android 手机端。Flutter 单代码库，混合存储（本地 SQLite + 云端同步）。

**技术栈**: Flutter 3.x (Dart), SQLite (sqflite), Dio, Provider, Material Design 3

## 构建命令

```bash
# 前置条件: Flutter 3.x, Dart 3.x, Android SDK 36, VS 2026 (Windows 桌面), JDK 17
# 环境变量: JAVA_HOME, ANDROID_SDK_ROOT, Flutter in PATH

# 依赖安装
flutter pub get

# 代码分析
flutter analyze

# Windows 桌面构建
flutter build windows

# Android APK 构建
flutter build apk

# 开发运行 (Windows)
flutter run -d windows

# 开发运行 (Android 模拟器/设备)
flutter run -d <device_id>

# 代码生成 (JSON 序列化等)
dart run build_runner build --delete-conflicting-outputs

# 测试
flutter test
```

## 目录结构

```
GKGB/
├── lib/
│   ├── main.dart                # 入口 + Provider 注入
│   ├── app.dart                 # MaterialApp 配置（主题、路由）
│   ├── models/                  # 数据模型（json_serializable）[待建]
│   ├── db/                      # 数据库层
│   │   └── database_helper.dart # SQLite 建表与升级
│   ├── services/                # 业务服务
│   │   ├── llm/                 # 多大模型抽象层
│   │   │   ├── llm_provider.dart    # 统一接口
│   │   │   └── llm_manager.dart     # 模型管理 + fallback
│   │   └── question_service.dart    # 题目服务
│   ├── screens/                 # 页面
│   │   ├── home_screen.dart         # 首页（底部导航）
│   │   ├── practice_screen.dart     # 刷题
│   │   ├── exam_screen.dart         # 模拟考试
│   │   ├── stats_screen.dart        # 统计
│   │   ├── policy_match_screen.dart # 公告匹配
│   │   └── profile_screen.dart      # 个人信息
│   └── widgets/                 # 通用组件 [待建]
├── assets/                      # 静态资源（题库 JSON 等）[待建]
├── docs/
│   ├── product-design.md        # 产品设计文档
│   └── skill-adaptation-plan.md # Skill 适配计划
├── android/                     # Android 工程（flutter create 生成）
├── windows/                     # Windows 工程（flutter create 生成）
├── test/                        # 测试
└── pubspec.yaml                 # 依赖配置
```

> **注意**：完整的目标目录结构见 [`docs/product-design.md`](docs/product-design.md) 第 3.2 节，上表仅反映当前已实现的文件。

## 核心模块

| 模块 | 说明 |
|------|------|
| 题库刷题 | 行测/申论/公基分科练习，错题本，收藏 |
| 模拟考试 | 按真实考试时间题量模拟，自动评分 |
| 人才引进匹配 | 两级匹配（公告粗筛→岗位精准），筛选理由卡片 |
| 学习路线 | 目标岗位→摸底测试→分阶段每日计划→动态调整 |
| 多模型 AI | 统一 LLM 接口，支持 Claude/DeepSeek/千问/Ollama |

## 开发规范

- 遵循本工程宪法 → [`.claude/rules/constitution.md`](.claude/rules/constitution.md)
- **状态管理**: 使用 Provider，复杂状态拆分为多个 ChangeNotifier
- **数据模型**: 使用 json_serializable + json_annotation，模型类放 `models/`
- **网络请求**: 统一通过 Dio，基础配置在 `api_service.dart`
- **数据库**: 表结构变更通过 `database_helper.dart` 的版本迁移，禁止手动删库
- **LLM 调用**: 所有 AI 场景通过 `LlmManager.chat()` 调用，不直接耦合具体模型
- **API Key 安全**: 用户 API Key 通过 `flutter_secure_storage` 或等效加密方案存储，禁止明文存储或日志输出

## 常见操作

### 添加新页面
1. 在 `lib/screens/` 创建 `xxx_screen.dart`
2. 在 `home_screen.dart` 的导航中添加入口
3. 如需新数据模型，在 `models/` 创建并运行 `build_runner`

### 添加新 LLM Provider
1. 在 `lib/services/llm/` 创建 `xxx_provider.dart`，实现 `LlmProvider` 接口
2. 在 `LlmManager` 中注册
3. 在设置页添加对应配置项

### 数据库表结构变更
1. 修改 `database_helper.dart` 的 `_createDB` 方法
2. 增加 `version` 号，在 `onUpgrade` 中处理迁移逻辑
3. 测试升级路径

### 添加新依赖
```bash
flutter pub add <package_name>        # 运行时依赖
flutter pub add --dev <package_name>  # 开发依赖
```

## .claude 目录

| 路径 | 说明 |
|------|------|
| `.claude/rules/constitution.md` | 工程宪法（本工程最高优先级规则） |
| `.claude/rules/evolution.md` | 文档持续演进规则 |
| `.claude/skills/app-feature/SKILL.md` | 新功能开发 Skill（`/app-feature`） |
| `.claude/skills/app-bug-explore/SKILL.md` | Bug 诊断修复 Skill（`/app-bug-explore`） |
| `.claude/INDEX.md` | .claude 目录索引 |
