"""
数据清洗和标准化
将各爬虫产出的原始数据统一为 ExamEntryScore 模型格式
"""

import re
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# 省份名称标准化映射
PROVINCE_NORMALIZE = {
    '江苏省': '江苏', '浙江省': '浙江', '上海市': '上海', '山东省': '山东',
    '北京市': '北京', '广东省': '广东', '四川省': '四川', '湖北省': '湖北',
}

# 考试类型标准化映射
EXAM_TYPE_NORMALIZE = {
    '国家公务员': '国考', '国家公务员考试': '国考', '中央机关': '国考',
    '省公务员': '省考', '省级公务员': '省考', '地方公务员': '省考',
    '事业单位': '事业编', '事业编制': '事业编', '事业单位公开招聘': '事业编',
}


def clean_records(records: list[dict]) -> list[dict]:
    """
    清洗和标准化数据记录

    处理内容：
    1. 省份名称标准化
    2. 考试类型标准化
    3. 分数值校验（合理范围 0-300）
    4. 去重（相同 province+city+year+exam_type+department+position_name）
    5. 缺失字段补全
    6. 文本清理（去除多余空白、特殊字符）
    """
    cleaned = []
    seen = set()

    for record in records:
        try:
            r = _clean_single(record)
            if r is None:
                continue

            # 去重键
            dedup_key = (
                r['province'], r['city'], r['year'],
                r['exam_type'], r['department'], r['position_name']
            )
            if dedup_key in seen:
                continue
            seen.add(dedup_key)

            cleaned.append(r)
        except Exception as e:
            logger.debug(f'清洗记录失败: {e}')

    logger.info(f'清洗完成: {len(records)} → {len(cleaned)} 条（去重/无效过滤）')
    return cleaned


def _clean_single(record: dict) -> Optional[dict]:
    """清洗单条记录"""
    # 必填字段校验
    province = _clean_text(record.get('province', ''))
    city = _clean_text(record.get('city', ''))
    year = record.get('year')
    exam_type = _clean_text(record.get('exam_type', ''))
    department = _clean_text(record.get('department', ''))
    position_name = _clean_text(record.get('position_name', ''))

    if not all([province, year, exam_type, department, position_name]):
        return None

    # 省份标准化
    province = PROVINCE_NORMALIZE.get(province, province)

    # 城市默认为省份名
    if not city:
        city = province

    # 考试类型标准化
    exam_type = EXAM_TYPE_NORMALIZE.get(exam_type, exam_type)
    if exam_type not in ('国考', '省考', '事业编'):
        logger.debug(f'未知考试类型: {exam_type}')
        return None

    # 分数校验
    min_score = _validate_score(record.get('min_entry_score'))
    max_score = _validate_score(record.get('max_entry_score'))

    if min_score is None and max_score is None:
        return None

    # 确保 min <= max
    if min_score is not None and max_score is not None and min_score > max_score:
        min_score, max_score = max_score, min_score

    # 招录人数校验
    recruit_count = _validate_positive_int(record.get('recruit_count'))
    entry_count = _validate_positive_int(record.get('entry_count'))

    return {
        'province': province,
        'city': city,
        'year': int(year),
        'exam_type': exam_type,
        'department': department,
        'position_name': position_name,
        'position_code': _clean_text(record.get('position_code')) or None,
        'recruit_count': recruit_count,
        'major_req': _clean_text(record.get('major_req')) or None,
        'education_req': _clean_text(record.get('education_req')) or None,
        'degree_req': _clean_text(record.get('degree_req')) or None,
        'political_req': _clean_text(record.get('political_req')) or None,
        'work_exp_req': _clean_text(record.get('work_exp_req')) or None,
        'other_req': _clean_text(record.get('other_req')) or None,
        'min_entry_score': min_score,
        'max_entry_score': max_score,
        'entry_count': entry_count,
        'source_url': record.get('source_url'),
    }


def _clean_text(text: Optional[str]) -> str:
    """清理文本：去除多余空白和特殊字符"""
    if text is None:
        return ''
    text = str(text).strip()
    # 合并连续空白
    text = re.sub(r'\s+', ' ', text)
    # 去除不可见字符
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', '', text)
    return text


def _validate_score(value) -> Optional[float]:
    """校验分数值在合理范围内"""
    if value is None:
        return None
    try:
        score = float(value)
        # 公务员/事业编笔试分数通常在 30-300 之间
        if 30 <= score <= 300:
            return round(score, 1)
        logger.debug(f'分数超出合理范围: {score}')
        return None
    except (ValueError, TypeError):
        return None


def _validate_positive_int(value) -> Optional[int]:
    """校验正整数"""
    if value is None:
        return None
    try:
        n = int(value)
        return n if n > 0 else None
    except (ValueError, TypeError):
        return None
