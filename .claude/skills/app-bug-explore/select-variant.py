#!/usr/bin/env python3
"""bug-explore A/B 变体选择器。Phase 0 调用，决定使用 main 还是变体 SKILL。"""

import json
import os
import random
import sys

SKILL_DIR = ".claude/skills/app-bug-explore"
METRICS_PATH = "docs/skills/bug-explore-metrics.jsonl"


def load_recent_variant_metrics(variant_name, n=2):
    """加载变体最近 n 条指标记录。"""
    if not os.path.exists(METRICS_PATH):
        return []
    with open(METRICS_PATH, "r", encoding="utf-8") as f:
        records = [json.loads(line) for line in f if line.strip()]
    return [r for r in records if r.get("variant") == variant_name][-n:]


def main():
    # 扫描变体文件
    variants = []
    if os.path.exists(SKILL_DIR):
        variants = [
            f for f in os.listdir(SKILL_DIR)
            if f.startswith("SKILL.variant-") and f.endswith(".md")
        ]

    if not variants:
        print(json.dumps({"variant": "main", "skill_file": "SKILL.md"}))
        return

    # 选择第一个变体（如果有多个，取第一个）
    variant_file = variants[0]
    variant_name = variant_file.replace("SKILL.variant-", "").replace(".md", "")

    # 快速失败检测：最近 2 条都失败则跳过变体
    recent = load_recent_variant_metrics(variant_name, n=2)
    if len(recent) >= 2 and all(r.get("fix_result") == "failed" for r in recent):
        print(json.dumps({"variant": "main", "skill_file": "SKILL.md"}))
        return

    # 50/50 随机选择
    if random.random() < 0.5:
        print(json.dumps({"variant": variant_name, "skill_file": variant_file}))
    else:
        print(json.dumps({"variant": "main", "skill_file": "SKILL.md"}))


if __name__ == "__main__":
    main()
