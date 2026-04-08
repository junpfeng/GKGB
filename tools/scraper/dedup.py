"""
跨源去重模块
基于题目内容 MD5 哈希去重，避免同一题从多个来源重复入库
"""

import re
import hashlib
import logging
from typing import Optional

logger = logging.getLogger("dedup")


def _normalize_for_hash(text: str) -> str:
    """
    标准化文本用于哈希计算
    - 去除所有空白字符
    - 转为小写
    - 去除标点符号
    目的：使语义相同但格式略有差异的题目能被识别为重复
    """
    # 去除空白
    text = re.sub(r"\s+", "", text)
    # 去除常见标点
    text = re.sub(r"[，。？！、；：""''【】《》\(\)（）\[\]…—]", "", text)
    # 转小写
    text = text.lower()
    return text


def compute_content_hash(question: dict) -> str:
    """
    计算题目内容哈希（MD5）
    使用 content + options 的归一化内容
    """
    content = question.get("content", "")
    options = question.get("options", [])

    # 组合内容：题目正文 + 所有选项文字（去除选项前缀 A. B. C. D.）
    combined_parts = [_normalize_for_hash(content)]
    for opt in options:
        # 去除 "A. " 这样的前缀
        opt_text = re.sub(r"^[A-E][.、]\s*", "", str(opt))
        combined_parts.append(_normalize_for_hash(opt_text))

    combined = "|".join(combined_parts)
    return hashlib.md5(combined.encode("utf-8")).hexdigest()


def dedup(questions: list[dict]) -> list[dict]:
    """
    对题目列表进行去重
    - 优先保留解析更完整的版本（explanation 不为空）
    - 同等情况下保留最早出现的（先来先得）

    返回去重后的题目列表
    """
    seen: dict[str, dict] = {}  # hash -> question
    duplicates = 0

    for q in questions:
        h = compute_content_hash(q)
        if h not in seen:
            seen[h] = q
        else:
            duplicates += 1
            existing = seen[h]
            # 如果新版本有解析而已有版本没有，则替换
            if (q.get("explanation") and not existing.get("explanation")):
                seen[h] = q
                logger.debug(f"用含解析版本替换: {q.get('content', '')[:30]}")

    result = list(seen.values())
    logger.info(f"去重完成: 原始 {len(questions)} 条 -> 有效 {len(result)} 条（去除 {duplicates} 条重复）")
    return result


def dedup_against_existing(
    new_questions: list[dict],
    existing_hashes: set[str],
) -> list[dict]:
    """
    增量去重：将新题目与已有哈希集合对比
    返回尚未存在的题目（新增题目）

    用于 Flutter 端增量导入逻辑
    """
    result = []
    skipped = 0

    for q in new_questions:
        h = compute_content_hash(q)
        if h in existing_hashes:
            skipped += 1
        else:
            q["content_hash"] = h  # 附加哈希，供数据库去重使用
            result.append(q)

    logger.info(f"增量去重: {len(new_questions)} 条 -> 新增 {len(result)} 条（跳过 {skipped} 条）")
    return result


def build_hash_set(questions: list[dict]) -> set[str]:
    """从题目列表构建哈希集合"""
    return {compute_content_hash(q) for q in questions}
