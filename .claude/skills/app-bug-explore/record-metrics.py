#!/usr/bin/env python3
"""bug-explore 指标记录工具。将每次 bug-explore 运行的指标写入 metrics.jsonl。"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

METRICS_PATH = "docs/skills/bug-explore-metrics.jsonl"


def main():
    parser = argparse.ArgumentParser(description="记录 bug-explore 运行指标")
    parser.add_argument("--fix-result", required=True, choices=["success", "failed", "not_a_bug"])
    parser.add_argument("--module", required=True, help="Bug 所属模块（如 LLM、Database）")
    parser.add_argument("--strategies-matched", nargs="*", default=[], help="命中的策略关键词")
    parser.add_argument("--phase1-actions", type=int, required=True, help="Phase 1 采集动作数")
    parser.add_argument("--phase1-rounds", type=int, required=True, help="Phase 1 采集轮次")
    parser.add_argument("--phase1-actions-cited", type=int, default=0, help="被修复引用的动作数")
    parser.add_argument("--phase2-rounds", type=int, required=True, help="Phase 2 提问轮次")
    parser.add_argument("--phase2-early-exit", action="store_true", help="是否提前退出")
    parser.add_argument("--phase4-retries", type=int, default=0, help="修复重试次数")
    parser.add_argument("--failure-reason", default=None, help="失败原因")
    parser.add_argument("--harness-gap", default=None, help="诊断能力缺口")
    parser.add_argument("--variant", default="main", help="SKILL 版本")
    parser.add_argument("--dry-run", action="store_true", help="只输出不写文件")

    args = parser.parse_args()

    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "module": args.module,
        "fix_result": args.fix_result,
        "strategies_matched": args.strategies_matched,
        "phase1_actions": args.phase1_actions,
        "phase1_rounds": args.phase1_rounds,
        "phase1_actions_cited": args.phase1_actions_cited,
        "phase2_rounds": args.phase2_rounds,
        "phase2_early_exit": args.phase2_early_exit,
        "phase4_retries": args.phase4_retries,
        "variant": args.variant,
    }

    if args.failure_reason:
        record["failure_reason"] = args.failure_reason
    if args.harness_gap:
        record["harness_gap"] = args.harness_gap

    line = json.dumps(record, ensure_ascii=False)

    if args.dry_run:
        print(line)
        return

    os.makedirs(os.path.dirname(METRICS_PATH), exist_ok=True)
    with open(METRICS_PATH, "a", encoding="utf-8") as f:
        f.write(line + "\n")

    print(line)


if __name__ == "__main__":
    main()
