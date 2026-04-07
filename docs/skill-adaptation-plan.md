# Plan: 为 GKGB 创建 app-feature 和 app-bug-explore Skills（待实施）

## Context

GKGB（考公考编智能助手）是 Flutter/Dart 单仓库项目，目前没有自己的开发/调试工作流 skill。工作空间已有的 `new-feature` 和 `bug-explore` 是为游戏工程（Unity+Go 多仓库）设计的，大量概念（MCP、GM 命令、Proto 协议、跨端编译）不适用。需要将这两个 skill 的**工作流骨架**保留，但把技术细节全面适配为 Flutter 生态。

> **状态**：本计划尚未实施，以下路径均为待创建。

## 创建文件清单

### Skill 1: app-feature（改编自 new-feature）

**路径**: `GKGB/.claude/skills/app-feature/SKILL.md`（~450 行，单文件）

保留的工作流骨架：
- Step 0: 基线收集 + 断点恢复
- Step 1: 项目上下文建立（单仓库，搜 lib/ 各层）
- Step 2: 需求文档 idea.md
- Step 3: 互动确认方案（核心交互，max 8 轮）
- Step 3.5: 技术可行性快检
- Step 3.7: 红蓝对抗审查
- Step 4: 全自动实现（单引擎 `claude -p`）
- Step 5: 验收验证 + 合并分支

关键适配点：
| 原概念 | Flutter 替代 |
|--------|-------------|
| 3 仓库 git 操作 | 单仓库 `git checkout -b feature/xxx` |
| Go `make build` + Unity 编译 | `flutter analyze` + `flutter test` + `flutter build windows` |
| MCP 运行时验证 | `flutter test`（widget/integration） |
| Proto 协议检查 | json_serializable + build_runner |
| dev-workflow vs auto-work 引擎选择 | 单引擎：`claude -p` 子进程 |
| `docs/version/{VER}/{FEAT}/` | `docs/features/{FEAT}/`（扁平结构） |
| DDRP 跨仓库依赖发现 | 移除（单仓库不需要） |
| 验收 `[runtime]` MCP 类型 | `[test]` flutter test 类型 |
| 验收 `[visual]` 截图类型 | `[manual]` 手动 flutter run 验证 |

新增 Flutter 特有关注点：
- Provider ChangeNotifier 注册检查（main.dart）
- SQLite schema 迁移（database_helper.dart version bump）
- build_runner 代码生成
- 双平台构建验证（Windows + Android）
- constitution.md 合规（LlmManager 抽象层、API Key 安全）

### Skill 2: app-bug-explore（改编自 bug-explore）

**路径**: `GKGB/.claude/skills/app-bug-explore/`

文件结构：
| 文件 | 行数 | 说明 |
|------|------|------|
| `SKILL.md` | ~300 | 主流程（4 Phase + 演化） |
| `diagnostic-strategies.md` | ~70 | 关键词→诊断动作查找表 |
| `reproduction-playbooks.md` | ~60 | Flutter 复现策略 |
| `dart-templates.md` | ~50 | Dart 测试/调试模板 |
| `metrics-schema.md` | ~80 | 指标体系 + 演化规则 |
| `record-metrics.py` | ~80 | 指标记录 CLI |
| `evolve.py` | ~120 | 策略演化自动化 |
| `select-variant.py` | ~40 | A/B 变体选择 |

关键适配点：
| 原概念 | Flutter 替代 |
|--------|-------------|
| MCP screenshot/script-execute | `flutter analyze` + `flutter test` + `flutter logs` |
| GM 命令复现 | 导航到页面、输入测试数据、操作 Provider 状态 |
| C# 模板 | Dart widget test / integration test / SQLite mock 模板 |
| Unity Play 模式验证 | `flutter test` + 手动 `flutter run` |
| Go 服务端日志 | `flutter logs -d <device>` / `adb logcat` |
| 游戏特有分类（NPC/载具/动画） | 应用特有分类（LLM/数据库/状态/导航/UI/崩溃/性能/平台） |
| bug 目录 `docs/bugs/{VER}/{MOD}/` | `docs/bugs/{MODULE}/` |

diagnostic-strategies.md 关键词表（11 条）：
- LLM/AI/模型/回答/生成 → 检查 LlmManager 配置、API Key、fallback
- 数据库/存储/丢失/数据 → 检查 schema、migration、版本号
- 状态/Provider/刷新/不更新 → 检查 ChangeNotifier 注册、context.read/watch
- 题库/刷题/答题 → 检查 question_service
- 匹配/岗位/公告 → 检查 match_engine、crawler_service
- 导航/路由/跳转 → 检查 app.dart routes、home_screen
- 崩溃/闪退/Exception → flutter analyze + flutter test
- 卡顿/慢/性能 → ListView.builder、SQLite index、LLM stream
- 平台/Windows/Android → Platform.isXxx、平台特有配置
- UI/界面/显示/布局 → 读 screen 文件、const constructor
- 无明显关键词 → flutter analyze + flutter test + git log

### 辅助更新

**`GKGB/.claude/INDEX.md`**: 添加 skills 条目

## 实现顺序

1. 创建 `GKGB/.claude/skills/app-feature/SKILL.md`
2. 创建 `GKGB/.claude/skills/app-bug-explore/SKILL.md`
3. 创建 `app-bug-explore/` 下全部辅助文件（diagnostic-strategies.md、reproduction-playbooks.md、dart-templates.md、metrics-schema.md）
4. 创建 Python 脚本（record-metrics.py、evolve.py、select-variant.py）
5. 更新 `GKGB/.claude/INDEX.md`
6. 创建 `docs/features/` 和 `docs/bugs/` 空目录（.gitkeep）

## 验证方式

1. 检查 SKILL.md frontmatter 格式正确（name + description 字段存在）
2. Python 脚本语法检查：`python -c "import ast; ast.parse(open('file').read())"`
3. 确认 INDEX.md 链接路径正确
4. 在 Claude Code 中输入 "我想做一个XXX功能" 确认 app-feature 触发
5. 在 Claude Code 中输入 "有个 bug 但说不清" 确认 app-bug-explore 触发
