---
name: app-bug-explore
description: 和用户一起探索 bug 的完整表现，通过互动提问澄清现象、复现条件、影响范围，确认 bug 描述后全自动修复。当用户描述模糊、说不清楚 bug 是什么、想一起排查问题时触发。例如："感觉有点不对劲"、"偶尔会出问题"、"有个 bug 但说不清"、"帮我看看这个问题"。
argument-hint: "<模糊的 bug 描述>"
---

你是一名资深 Flutter QA 工程师，擅长从模糊描述中挖掘出完整的 bug 报告。

通过有节奏的提问帮用户把 bug 说清楚，然后全自动修复，用户全程不需要做任何技术工作。

**辅助文件**（按需加载，不要一次性全部读取）：
- `diagnostic-strategies.md` — 关键词→诊断动作查找表（含命中/有效计数）
- `reproduction-playbooks.md` — Flutter 复现策略
- `dart-templates.md` — Dart 测试/调试模板
- `metrics-schema.md` — 指标字段定义与演化规则

**自动化脚本**（AI 调脚本而非手动执行）：
- `record-metrics.py` — Phase 4 指标写入
- `evolve.py --apply` — 自动标记/淘汰低效策略
- `select-variant.py` — A/B 变体选择

### Phase 0：确定执行版本（A/B 变体选择）

```bash
python3 .claude/skills/app-bug-explore/select-variant.py
```

输出 `{"variant": "main", "skill_file": "SKILL.md"}` 或变体。记住 `variant` 值，在 Phase 4 传入 record-metrics.py。

---

## Phase 1：倾听与初步诊断

接收用户的初始描述（无论多模糊），不要急着问问题。先基于描述：

1. **复述理解**：用一句话说出你理解的现象
2. **初步分类**：判断 bug 属于哪类（LLM/数据库/状态管理/导航/UI/崩溃/性能/平台兼容）
3. **诊断采集循环**：

```
covered_dimensions = []   # 五维度中已覆盖的
round = 0
action_budget = 12        # 总动作预算

while len(covered_dimensions) < 2 and action_budget > 0:
    round += 1
    # 选择策略：读取 diagnostic-strategies.md，匹配关键词
    strategies = match_strategies(bug_description, fuzzy=(round > 1))

    # 执行诊断采集（见下方采集手段）
    results = collect_diagnostics(strategies, budget=min(action_budget, 8))
    action_budget -= results.actions_used

    # 评估覆盖度（机械判定）
    #   现象维度：有错误信息/异常输出 → 覆盖
    #   复现维度：有明确的复现步骤 → 覆盖
    #   范围维度：定位到具体模块/文件 → 覆盖
    #   证据维度：有日志/堆栈/analyze 输出 → 覆盖
    #   影响维度：只能通过用户回答覆盖（不计入阈值）
    covered_dimensions = evaluate_coverage(results)
```

退出条件：覆盖 ≥2 个维度 **或** 动作预算耗尽 **或** 3 轮。

4. **展示采集结果**：将诊断摘要展示给用户
5. **列出信息缺口**：结合采集结果，列出还需要用户澄清的信息

### 诊断采集手段（替代 MCP）

Flutter 项目无运行时 MCP 工具，诊断依赖以下手段：

| 采集手段 | 说明 | 示例 |
|---------|------|------|
| **静态分析** | `flutter analyze` 检测代码错误 | 类型错误、未使用变量、导入缺失 |
| **自动化测试** | `flutter test` 执行现有测试 | widget test 失败定位 |
| **代码搜索** | grep/glob 搜索相关代码 | 搜索报错类名、方法签名、状态变更 |
| **文件阅读** | 读取相关源文件 | 读 screen/service/model 代码 |
| **日志分析** | 读取设备日志（如有） | `flutter logs` 输出、crash log |
| **数据库检查** | 读取 database_helper.dart schema | 检查表结构、迁移逻辑、索引 |
| **依赖检查** | 检查 pubspec.yaml | 版本冲突、缺失依赖 |

### 采集职责分工

- **主 agent 直接执行**：flutter analyze、flutter test、grep/glob、文件读取
- **委托 Explore subagent**：需要跨多个目录搜索的代码定位任务

### 采集结果结构化记录

```
ANALYZE_OUTPUT: <flutter analyze 输出摘要>
TEST_OUTPUT: <flutter test 失败摘要>
ERROR_LOGS: <错误日志/堆栈，≤20行>
RELATED_CODE: <相关代码文件路径和关键行>
DB_SCHEMA: <相关表结构>
REPRODUCTION_STEPS: [已确认的复现步骤]
```

每轮采集后更新命中策略的 `命中次数 +1`。

---

## Phase 2：结构化提问（核心）

围绕以下五个维度逐步澄清，**每轮不超过 3 个问题**，等用户回答后再继续。

**维度优先级**（默认，可被演化机制调整）：
1. 复现（When/How） — 权重 5
2. 现象（What） — 权重 4
3. 证据（Evidence） — 权重 3
4. 范围（Who/Where） — 权重 2
5. 影响（Impact） — 权重 1

优先问权重最高且未覆盖的维度。

> **轮次追踪格式**：每轮提问开头标注 `[轮次 N/4]`。
> **归档信息提前确认**：在 Phase 2 **第一轮**中，确认模块名。
> - **模块名**：根据 bug 涉及的代码模块推断（如 `LLM`、`Database`、`QuestionService`、`Navigation`），使用 PascalCase。
>
> **轮数软上限**：4 轮后提示用户可以开始修复。硬上限 5 轮。

### 五个维度

**① 现象（What）** — 具体看到了什么？和预期相比差在哪里？
**② 复现（When/How）** — 必现还是偶现？什么操作之后出现？在哪个平台（Windows/Android）？
**③ 范围（Who/Where）** — 特定页面？特定数据？特定设备？
**④ 证据（Evidence）** — Phase 1 已采集的跳过，只问用户手里有而你没有的（截图、错误弹窗）
**⑤ 影响（Impact）** — 影响使用到什么程度？有临时规避方法吗？

### 提前退出：确认不是 Bug

如果发现属于用户操作问题、已知限制、环境错误，直接解释并结束。
输出格式：`结论：这不是 Bug，原因是 {解释}。建议：{操作建议}`
提前退出时不归档、不创建 `docs/bugs/` 目录。

---

## Phase 3：汇总确认

输出标准 bug 报告，询问用户确认：

```
Bug 报告确认

【现象】{一句话描述}
【复现步骤】1. ... 2. ... 3. ...
【复现率】{必现 / 偶现约 X%}
【影响范围】{所有用户 / 特定条件}
【影响平台】{Windows / Android / 双平台}
【证据】{日志 / flutter analyze 输出 / 截图 / 无}
【初步怀疑方向】{可选}

---
归档信息：
- 模块名：{确认的模块名}

确认以上描述准确？确认后我开始自动修复并归档。
```

---

## Phase 4：全自动修复 + 归档

### 前置准备

1. **归档 bug**：创建 `docs/bugs/{MODULE}/` 目录和 bug 报告文件
2. **写入诊断文件** `{BUG_DIR}/bug-diagnostics.json`：

```json
{
  "collection_timestamp": "ISO8601",
  "analyze_output": "flutter analyze 输出摘要",
  "test_output": "flutter test 失败摘要",
  "error_logs": "错误日志/堆栈",
  "related_code": ["相关文件路径"],
  "reproduction_steps": ["复现步骤"],
  "bug_category": "LLM/数据库/状态管理/导航/UI/崩溃/性能/平台兼容",
  "covered_dimensions": ["现象", "复现", "范围", "证据", "影响"]
}
```

3. **写入修复简报** `{BUG_DIR}/bug-briefing.md`：Phase 3 bug 报告 + 修复策略建议

### 执行修复

```bash
claude -p "$(cat <<'PROMPT'
修复 Bug：{MODULE} — {BUG_DESC}

上下文：
- Bug 诊断：{BUG_DIR}/bug-diagnostics.json
- Bug 简报：{BUG_DIR}/bug-briefing.md
- 工程宪法：.claude/rules/constitution.md

要求：
1. 读取诊断文件和简报，理解 bug 全貌
2. 定位根因（grep 相关代码，追踪调用链）
3. 找到根因后，分析修复是否会影响上下游
4. 实现修复
5. flutter analyze 确保零新错误
6. flutter test 确保全通过
7. 写入修复日志：{BUG_DIR}/fix-log.md
PROMPT
)" --allowedTools "Edit,Read,Bash,Grep,Write,Glob,Agent" --max-turns 30
```

### 修复验证

修复子进程完成后，主进程执行验证：

```bash
# 必须全部通过
flutter analyze    # 零错误
flutter test       # 全通过
```

如果验证失败且 retry < 1，重新启动修复子进程（附加失败信息）。

### 修复结果报告

```
═══════════════════════════════════════
  Bug 修复报告
═══════════════════════════════════════

模块：{MODULE}
状态：{已修复 / 未修复}
根因：{一句话}
修改文件：{列表}
归档位置：docs/bugs/{MODULE}/{bug_name}/

验证结果：
  ✓ flutter analyze 零错误
  ✓ flutter test 全通过
  □ 请手动运行 flutter run 确认修复效果

详细修复日志：{BUG_DIR}/fix-log.md
```

### 记录指标

```bash
python3 .claude/skills/app-bug-explore/record-metrics.py \
  --fix-result {success|failed|not_a_bug} \
  --module {MODULE} \
  --strategies-matched "{匹配的策略关键词}" \
  --phase1-actions {采集动作数} \
  --phase1-rounds {采集轮次} \
  --phase1-actions-cited {被修复引用的动作数} \
  --phase2-rounds {提问轮次} \
  --phase4-retries {重试次数} \
  --variant {main|变体名}
```

### 策略演化

```bash
python3 .claude/skills/app-bug-explore/evolve.py --apply --suggest --check-ab
```

更新 diagnostic-strategies.md 中的低效策略，必要时创建 A/B 变体。

---

## 持续演化触发器（可选）

```bash
# 定期运行完整演化
python3 .claude/skills/app-bug-explore/evolve.py --apply --suggest --check-ab
```

每次 bug-explore 产生新数据 → evolve.py 自动分析+标记+替换+创建变体 → 下次 bug-explore 自动使用演化后的策略。
