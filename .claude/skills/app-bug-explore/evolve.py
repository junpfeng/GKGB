#!/usr/bin/env python3
"""bug-explore 策略演化工具。基于 metrics 数据自动更新 diagnostic-strategies.md。"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone

METRICS_PATH = "docs/skills/bug-explore-metrics.jsonl"
STRATEGIES_PATH = ".claude/skills/app-bug-explore/diagnostic-strategies.md"
CHANGELOG_PATH = "docs/skills/bug-explore-changelog.md"
ALERT_HISTORY_PATH = ".claude/skills/app-bug-explore/.alert-history.json"
SKILL_DIR = ".claude/skills/app-bug-explore"

# 常量
MIN_HITS_FOR_EVAL = 5
INEFFECTIVE_THRESHOLD = 0.2
MAX_STRATEGIES = 25
RECENT_N = 10
AB_MIN_SAMPLES = 5
AB_WIN_MARGIN = 0.05
AB_EARLY_STOP_N = 3
AB_EARLY_STOP_MARGIN = 0.15
VARIANT_ALERT_THRESHOLD = 3

HEALTH_THRESHOLDS = {
    "diagnostic_hit_rate": 0.4,
    "fix_success_rate": 0.7,
    "avg_question_rounds": 2.5,
    "two_round_collection_ratio": 0.3,
}


def load_metrics(n=None):
    """加载 metrics.jsonl，返回最近 n 条记录。"""
    if not os.path.exists(METRICS_PATH):
        return []
    with open(METRICS_PATH, "r", encoding="utf-8") as f:
        records = [json.loads(line) for line in f if line.strip()]
    if n is not None:
        records = records[-n:]
    return records


def compute_derived_metrics(records):
    """计算派生指标。"""
    if not records:
        return {}
    total = len(records)
    success = sum(1 for r in records if r["fix_result"] == "success")
    actions = sum(r.get("phase1_actions", 0) for r in records)
    cited = sum(r.get("phase1_actions_cited", 0) for r in records)
    q_rounds = [r.get("phase2_rounds", 0) for r in records]
    two_round = sum(1 for r in records if r.get("phase1_rounds", 1) >= 2)

    return {
        "diagnostic_hit_rate": cited / actions if actions > 0 else 0,
        "fix_success_rate": success / total if total > 0 else 0,
        "avg_question_rounds": sum(q_rounds) / len(q_rounds) if q_rounds else 0,
        "two_round_collection_ratio": two_round / total if total > 0 else 0,
    }


def check_health(derived):
    """对比健康阈值，返回告警列表。"""
    alerts = []
    for key, threshold in HEALTH_THRESHOLDS.items():
        val = derived.get(key, 0)
        if key == "avg_question_rounds" or key == "two_round_collection_ratio":
            if val > threshold:
                alerts.append(f"{key}: {val:.2f} > {threshold}")
        else:
            if val < threshold:
                alerts.append(f"{key}: {val:.2f} < {threshold}")
    return alerts


def parse_strategies_table(content):
    """解析 diagnostic-strategies.md 表格，返回策略列表。"""
    strategies = []
    for line in content.split("\n"):
        match = re.match(r"\| \*\*(.+?)\*\* \| (.+?) \| (.+?) \| (\d+) \| (\d+) \|", line)
        if match:
            strategies.append({
                "keywords": match.group(1),
                "actions": match.group(2),
                "tools": match.group(3),
                "hits": int(match.group(4)),
                "effective": int(match.group(5)),
            })
    return strategies


def find_ineffective(strategies):
    """找出低效策略。"""
    return [
        s for s in strategies
        if s["hits"] >= MIN_HITS_FOR_EVAL
        and (s["effective"] / s["hits"] if s["hits"] > 0 else 0) < INEFFECTIVE_THRESHOLD
    ]


def load_alert_history():
    """加载告警历史。"""
    if not os.path.exists(ALERT_HISTORY_PATH):
        return {}
    with open(ALERT_HISTORY_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def save_alert_history(history):
    """保存告警历史。"""
    with open(ALERT_HISTORY_PATH, "w", encoding="utf-8") as f:
        json.dump(history, f, ensure_ascii=False, indent=2)


def update_alert_history(alerts):
    """更新告警历史，返回是否需要创建变体。"""
    history = load_alert_history()
    current_keys = set()
    for alert in alerts:
        key = alert.split(":")[0]
        current_keys.add(key)
        history[key] = history.get(key, 0) + 1

    # 不在当前告警中的 key 归零
    for key in list(history.keys()):
        if key not in current_keys:
            history[key] = 0

    save_alert_history(history)

    # 检查是否有达到阈值的告警
    return any(v >= VARIANT_ALERT_THRESHOLD for v in history.values())


def append_changelog(message):
    """追加 changelog 条目。"""
    os.makedirs(os.path.dirname(CHANGELOG_PATH), exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M")
    with open(CHANGELOG_PATH, "a", encoding="utf-8") as f:
        f.write(f"- [{timestamp}] {message}\n")


def main():
    parser = argparse.ArgumentParser(description="bug-explore 策略演化")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--apply", action="store_true", help="写入变更到文件")
    parser.add_argument("--suggest", action="store_true", help="生成候选替换策略")
    parser.add_argument("--check-ab", action="store_true", help="检查 A/B 实验")
    args = parser.parse_args()

    records = load_metrics(RECENT_N)
    derived = compute_derived_metrics(records)
    alerts = check_health(derived)

    # 解析策略表
    strategies = []
    if os.path.exists(STRATEGIES_PATH):
        with open(STRATEGIES_PATH, "r", encoding="utf-8") as f:
            content = f.read()
        strategies = parse_strategies_table(content)

    ineffective = find_ineffective(strategies)
    harness_gaps = {}
    for r in records:
        gap = r.get("harness_gap")
        if gap:
            harness_gaps[gap] = harness_gaps.get(gap, 0) + 1

    result = {
        "derived_metrics": derived,
        "health_alerts": alerts,
        "strategies_total": len(strategies),
        "strategies_ineffective": [s["keywords"] for s in ineffective],
        "harness_gaps_repeated": {k: v for k, v in harness_gaps.items() if v >= 2},
        "dry_run": args.dry_run,
        "apply": args.apply,
        "suggest": args.suggest,
        "check_ab": args.check_ab,
    }

    if args.apply and not args.dry_run:
        should_create_variant = update_alert_history(alerts)
        if should_create_variant:
            result["variant_trigger"] = True

        if ineffective:
            # 标记低效策略（实际文件编辑由 AI 根据输出执行）
            result["mark_ineffective"] = [s["keywords"] for s in ineffective[:3]]
            append_changelog(f"标记低效策略: {result['mark_ineffective']}")

    if args.check_ab:
        # 扫描变体文件
        variants = [f for f in os.listdir(SKILL_DIR) if f.startswith("SKILL.variant-")]
        result["active_variants"] = variants

        if variants and len(records) >= AB_MIN_SAMPLES:
            main_records = [r for r in records if r.get("variant") == "main"]
            for vf in variants:
                vname = vf.replace("SKILL.variant-", "").replace(".md", "")
                v_records = [r for r in records if r.get("variant") == vname]
                if len(v_records) >= AB_EARLY_STOP_N:
                    main_score = compute_derived_metrics(main_records)
                    v_score = compute_derived_metrics(v_records)
                    m_composite = main_score.get("diagnostic_hit_rate", 0) * 0.4 + main_score.get("fix_success_rate", 0) * 0.6
                    v_composite = v_score.get("diagnostic_hit_rate", 0) * 0.4 + v_score.get("fix_success_rate", 0) * 0.6
                    result[f"ab_{vname}"] = {
                        "samples": len(v_records),
                        "main_score": round(m_composite, 3),
                        "variant_score": round(v_composite, 3),
                    }

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
