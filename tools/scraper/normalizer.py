"""
数据标准化模块
将各爬虫输出的原始数据统一转换为标准 JSON 格式
"""

import re
import logging
from typing import Optional

logger = logging.getLogger("normalizer")

# 标准字段定义
REQUIRED_FIELDS = {"subject", "category", "type", "content", "options", "answer", "is_real_exam"}
VALID_TYPES = {"single", "multiple", "judge", "subjective"}
VALID_SUBJECTS = {"行测", "申论", "公基", "职业能力倾向测验", "综合应用能力", "行政职业能力测验"}
VALID_EXAM_TYPES = {"国考", "省考", "事业编", "选调"}


def normalize(raw: dict) -> Optional[dict]:
    """
    将原始题目数据标准化为应用所需格式
    返回标准化后的 dict，验证失败返回 None
    """
    if not isinstance(raw, dict):
        return None

    result = {}

    # --- 必填字段 ---
    content = _clean_text(raw.get("content", ""))
    if len(content) < 5:
        logger.debug(f"题目内容太短，跳过: {content[:50]}")
        return None
    result["content"] = content

    # 科目
    subject = _normalize_subject(raw.get("subject", ""))
    if not subject:
        logger.debug(f"无效科目: {raw.get('subject')}")
        return None
    result["subject"] = subject

    # 分类
    category = _normalize_category(raw.get("category", ""), subject)
    result["category"] = category

    # 题型
    q_type = _normalize_type(raw.get("type", "single"))
    result["type"] = q_type

    # 选项（客观题必须有选项）
    options = _normalize_options(raw.get("options", []))
    if q_type in ("single", "multiple", "judge") and len(options) < 2:
        logger.debug(f"客观题选项不足: {options}")
        return None
    result["options"] = options

    # 答案
    answer = _normalize_answer(raw.get("answer", ""), q_type, options)
    result["answer"] = answer

    # --- 可选字段 ---
    result["explanation"] = _clean_text(raw.get("explanation", ""))
    result["difficulty"] = _normalize_difficulty(raw.get("difficulty", 2))

    # 真题专属字段
    result["is_real_exam"] = 1
    result["region"] = _normalize_region(raw.get("region", ""))
    result["year"] = _normalize_year(raw.get("year", 0))
    result["exam_type"] = _normalize_exam_type(raw.get("exam_type", ""))
    result["exam_session"] = _clean_text(raw.get("exam_session", ""))

    return result


def _clean_text(text) -> str:
    """清理文本：去除多余空白、HTML 标签、特殊字符"""
    if not isinstance(text, str):
        text = str(text) if text else ""
    # 去除 HTML 标签
    text = re.sub(r"<[^>]+>", "", text)
    # 全角空格转半角
    text = text.replace("\u3000", " ")
    # 多余空白合并
    text = re.sub(r"\s+", " ", text)
    # 去除首尾空白
    text = text.strip()
    return text


def _normalize_subject(subject: str) -> Optional[str]:
    """标准化科目名称"""
    subject = _clean_text(subject)
    # 同义词映射
    subject_map = {
        "行政职业能力测验": "行测",
        "行政能力测验": "行测",
        "行测": "行测",
        "申论": "申论",
        "公共基础知识": "公基",
        "公共基础": "公基",
        "公基": "公基",
        "职业能力倾向测验": "职业能力倾向测验",
        "综合应用能力": "综合应用能力",
    }
    return subject_map.get(subject, subject if subject in VALID_SUBJECTS else None)


def _normalize_category(category: str, subject: str) -> str:
    """标准化题目分类"""
    category = _clean_text(category)
    # 分类别名映射
    category_map = {
        "言语": "言语理解",
        "言语理解与表达": "言语理解",
        "言语理解": "言语理解",
        "数量": "数量关系",
        "数量关系": "数量关系",
        "逻辑": "判断推理",
        "判断推理": "判断推理",
        "图形推理": "判断推理",
        "定义判断": "判断推理",
        "类比推理": "判断推理",
        "逻辑判断": "判断推理",
        "资料": "资料分析",
        "资料分析": "资料分析",
        "常识": "常识判断",
        "常识判断": "常识判断",
        "政治": "常识判断",
        "法律": "常识判断",
        "经济": "常识判断",
    }
    normalized = category_map.get(category, category)
    # 如果分类为空，用科目作为默认分类
    if not normalized:
        return subject
    return normalized


def _normalize_type(q_type: str) -> str:
    """标准化题型"""
    type_map = {
        "单选题": "single",
        "单选": "single",
        "single": "single",
        "多选题": "multiple",
        "多选": "multiple",
        "multiple": "multiple",
        "判断题": "judge",
        "判断": "judge",
        "judge": "judge",
        "主观题": "subjective",
        "申论": "subjective",
        "作文": "subjective",
        "subjective": "subjective",
    }
    return type_map.get(q_type, "single")


def _normalize_options(options) -> list:
    """标准化选项列表，确保格式为 ['A. xxx', 'B. xxx', ...]"""
    if not isinstance(options, list):
        return []
    result = []
    prefixes = ["A", "B", "C", "D", "E"]
    for i, opt in enumerate(options[:5]):  # 最多 5 个选项
        if i >= len(prefixes):
            break
        prefix = prefixes[i]
        opt_text = _clean_text(str(opt))
        # 去除已有的选项前缀（如 "A." "A、" 等）
        opt_text = re.sub(rf"^[{prefix.lower()}{prefix}][.、。\s]+", "", opt_text).strip()
        if opt_text:
            result.append(f"{prefix}. {opt_text}")
    return result


def _normalize_answer(answer: str, q_type: str, options: list) -> str:
    """标准化答案"""
    if not isinstance(answer, str):
        answer = str(answer) if answer else ""
    answer = answer.strip().upper()
    # 去除多余字符
    answer = re.sub(r"[^ABCDE]", "", answer)
    return answer


def _normalize_difficulty(difficulty) -> int:
    """标准化难度（1-5）"""
    try:
        d = int(difficulty)
        return max(1, min(5, d))
    except (ValueError, TypeError):
        return 2


def _normalize_region(region: str) -> str:
    """标准化地区名称"""
    region = _clean_text(region)
    region_map = {
        "全国": "全国",
        "国考": "全国",
        "": "",
        "江苏": "江苏",
        "浙江": "浙江",
        "上海": "上海",
        "山东": "山东",
    }
    return region_map.get(region, region)


def _normalize_year(year) -> int:
    """标准化年份"""
    try:
        y = int(year)
        if 2000 <= y <= 2030:
            return y
        return 0
    except (ValueError, TypeError):
        return 0


def _normalize_exam_type(exam_type: str) -> str:
    """标准化考试类型"""
    exam_type = _clean_text(exam_type)
    type_map = {
        "国家公务员考试": "国考",
        "国考": "国考",
        "省级公务员考试": "省考",
        "省考": "省考",
        "事业单位": "事业编",
        "事业编": "事业编",
        "选调生": "选调",
        "选调": "选调",
    }
    return type_map.get(exam_type, exam_type)


def normalize_batch(raw_list: list[dict]) -> list[dict]:
    """批量标准化"""
    results = []
    skipped = 0
    for raw in raw_list:
        normalized = normalize(raw)
        if normalized:
            results.append(normalized)
        else:
            skipped += 1
    logger.info(f"标准化完成: {len(results)} 条有效, {skipped} 条跳过")
    return results
