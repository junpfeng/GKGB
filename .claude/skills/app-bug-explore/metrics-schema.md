# 指标体系与演化规则

## 指标文件

路径：`docs/skills/bug-explore-metrics.jsonl`（每行一个 JSON，append 模式）

## 字段定义

| 字段 | 类型 | 说明 |
|------|------|------|
| `timestamp` | string (ISO8601) | 完成时间 |
| `module` | string | Bug 所属模块（如 LLM、Database、Navigation） |
| `fix_result` | enum | `"success"` / `"failed"` / `"not_a_bug"` |
| `failure_reason` | string? | 仅失败时：`"root_cause_unknown"` / `"fix_regression"` / `"compile_error"` / `"fix_rounds_exhausted"` |
| `harness_gap` | string? | 仅失败时：诊断策略/工具/复现能力的具体缺口 |
| `strategies_matched` | string[] | Phase 1 命中的策略关键词列表 |
| `phase1_actions` | int | Phase 1 总采集动作数 |
| `phase1_rounds` | int | Phase 1 采集轮次（1-3） |
| `phase1_actions_cited` | int | 修复时实际引用的 Phase 1 采集动作数 |
| `phase2_rounds` | int | Phase 2 提问轮次 |
| `phase2_early_exit` | bool | 是否提前退出（不是 bug） |
| `phase4_retries` | int | 修复重试次数（0 或 1） |
| `variant` | string | SKILL 版本：`"main"` 或变体名 |

## 派生指标（evolve.py 计算）

| 指标 | 公式 | 健康阈值 |
|------|------|---------|
| 诊断命中率 | `phase1_actions_cited / phase1_actions` | ≥40% |
| 修复成功率 | `count(success) / count(total)` | ≥70% |
| 平均提问轮次 | `avg(phase2_rounds)` | ≤2.5 |
| 二轮采集比例 | `count(phase1_rounds>=2) / count(total)` | ≤30% |

## 诊断策略演化规则

**计数更新时机**：
- Phase 1 关键词匹配时：策略 `命中次数 +1`
- 修复成功且引用了策略采集证据：策略 `有效次数 +1`

**淘汰规则**：
- `命中次数 ≥5` 且 `有效次数/命中次数 < 20%` → 标记为低效
- 下次 evolve.py 执行时：低效策略被替换或删除
- 最多 25 条策略；满时替换有效率最低的

**约束**：
- 每次 evolve.py 最多变更 3 条策略
- 变更必须基于实际指标数据，不允许臆测

## Phase 2 维度权重演化

| 维度 | 默认权重 | 说明 |
|------|---------|------|
| 复现（When/How） | 5 | 修复价值最高 |
| 现象（What） | 4 | 缩小排查范围 |
| 证据（Evidence） | 3 | Phase 1 已采集的跳过 |
| 范围（Who/Where） | 2 | 缩小影响面 |
| 影响（Impact） | 1 | 优先级判断 |

**演化规则**：
- 最近 10 次中，某维度信息被修复引用 ≤8 次 → 权重 -1（最低 1）
- 某维度频繁被引用 → 权重 +1（最高 5）

## A/B 实验

| 变体名 | 假设 | 开始日期 | 样本数 | 结果 |
|--------|------|---------|--------|------|
| *（暂无活跃实验）* | | | | |

**A/B 规则**：
- **触发**：evolve.py 同一告警连续 ≥3 次
- **创建**：复制 SKILL.md → SKILL.variant-{name}.md，仅修改 Phase 1/Phase 4 逻辑
- **执行**：有变体时 50/50 随机选择；记录 `variant` 字段
- **判定**：≥5 样本，比较派生指标。优于 main → 合并；否则删除
- **早停**：前 3 样本变体综合分 <15% → 提前删除
- **安全**：不可修改 Phase 2/3 交互流程
