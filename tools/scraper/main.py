"""
真题爬虫主入口
调度各爬虫 → 标准化 → 去重 → 输出 JSON

使用方法：
    # 安装依赖
    pip install -r requirements.txt

    # 运行全部爬虫（生产模式）
    python main.py

    # 仅运行特定爬虫
    python main.py --source fenbi
    python main.py --source qzzn
    python main.py --source gov --province jiangsu

    # 仅标准化和去重已有数据
    python main.py --normalize-only --input /path/to/raw.json
"""

import os
import sys
import json
import logging
import argparse
from datetime import datetime
from typing import Optional

from config import (
    GUOKAO_DIR,
    SHENGKAO_DIR,
    SHIYEBIAN_DIR,
    TARGET_YEARS,
    GUOKAO_SUBJECTS,
    SHENGKAO_SUBJECTS,
    SHIYEBIAN_SUBJECTS,
    LOG_FILE,
    LOG_LEVEL,
)
from normalizer import normalize_batch
from dedup import dedup, compute_content_hash

# 配置日志
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger("main")


def run_fenbi(cookie: Optional[str] = None) -> list[dict]:
    """运行粉笔网爬虫"""
    try:
        from fenbi_scraper import FenbiScraper
        scraper = FenbiScraper(cookie=cookie)
        return scraper.scrape()
    except Exception as e:
        logger.error(f"粉笔网爬虫失败: {e}")
        return []


def run_qzzn() -> list[dict]:
    """运行 QZZN 论坛爬虫"""
    try:
        from qzzn_scraper import QzznScraper
        scraper = QzznScraper()
        return scraper.scrape()
    except Exception as e:
        logger.error(f"QZZN 爬虫失败: {e}")
        return []


def run_gov(province: Optional[str] = None) -> list[dict]:
    """运行各省人事考试网爬虫"""
    try:
        from gov_scraper import scrape_all_provinces, GovExamScraper
        if province:
            scraper = GovExamScraper(province)
            return scraper.scrape()
        else:
            return scrape_all_provinces()
    except Exception as e:
        logger.error(f"政府网站爬虫失败: {e}")
        return []


def run_xiaohongshu(cookie: Optional[str] = None) -> list[dict]:
    """运行小红书爬虫"""
    try:
        from xiaohongshu_scraper import XiaohongshuScraper
        scraper = XiaohongshuScraper(cookie=cookie)
        return scraper.scrape()
    except Exception as e:
        logger.error(f"小红书爬虫失败: {e}")
        return []


def group_by_exam_config(questions: list[dict]) -> dict:
    """
    将题目按 (exam_type, region, year, subject) 分组
    用于生成对应的 JSON 文件
    """
    groups: dict[tuple, list[dict]] = {}
    for q in questions:
        key = (
            q.get("exam_type", ""),
            q.get("region", ""),
            q.get("year", 0),
            q.get("subject", ""),
        )
        groups.setdefault(key, []).append(q)
    return groups


def build_paper_meta(exam_type: str, region: str, year: int, subject: str) -> dict:
    """构建试卷元数据"""
    # 根据考试类型确定时限和题量
    if exam_type == "国考":
        sub_config = GUOKAO_SUBJECTS.get(region, {}).get(subject, {})
    elif exam_type == "省考":
        sub_config = SHENGKAO_SUBJECTS.get(region, {}).get(subject, {})
    elif exam_type == "事业编":
        sub_config = SHIYEBIAN_SUBJECTS.get("通用", {}).get(subject, {})
    else:
        sub_config = {}

    return {
        "name": f"{year}年{region or exam_type}{subject}真题",
        "region": region or "全国",
        "year": year,
        "exam_type": exam_type,
        "exam_session": "",
        "subject": subject,
        "time_limit": sub_config.get("time_limit", 7200),
        "total_score": 100,
        "question_ids": [],  # 导入时由 Flutter 端填充
    }


def save_group_to_json(
    exam_type: str,
    region: str,
    year: int,
    subject: str,
    questions: list[dict],
    output_dir: str,
) -> str:
    """将一组题目保存为 JSON 文件"""
    os.makedirs(output_dir, exist_ok=True)

    # 文件名规范：{region}_{year}_{subject}.json
    safe_region = region.replace(" ", "_") or "unknown"
    safe_subject = subject.replace(" ", "_").replace("/", "_")
    filename = f"{safe_region}_{year}_{safe_subject}.json"
    filepath = os.path.join(output_dir, filename)

    paper_meta = build_paper_meta(exam_type, region, year, subject)
    output = {
        "paper": paper_meta,
        "questions": questions,
        "generated_at": datetime.now().isoformat(),
        "source": "scraped",
        "total": len(questions),
    }

    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    logger.info(f"已保存: {filepath} ({len(questions)} 题)")
    return filepath


def save_all_groups(questions: list[dict]) -> list[str]:
    """将所有题目按分组保存到对应目录"""
    groups = group_by_exam_config(questions)
    saved_files = []

    for (exam_type, region, year, subject), group_questions in groups.items():
        if not exam_type or not year or not subject:
            logger.warning(f"跳过无效分组: exam_type={exam_type}, year={year}, subject={subject}")
            continue

        # 确定输出目录
        if exam_type == "国考":
            output_dir = GUOKAO_DIR
        elif exam_type == "省考":
            output_dir = SHENGKAO_DIR
        elif exam_type == "事业编":
            output_dir = SHIYEBIAN_DIR
        else:
            output_dir = os.path.join(os.path.dirname(GUOKAO_DIR), "other")

        filepath = save_group_to_json(
            exam_type, region, year, subject, group_questions, output_dir
        )
        saved_files.append(filepath)

    return saved_files


def main():
    parser = argparse.ArgumentParser(description="考公真题爬虫主程序")
    parser.add_argument(
        "--source",
        choices=["all", "fenbi", "qzzn", "gov", "xiaohongshu"],
        default="all",
        help="指定数据源（默认: all）",
    )
    parser.add_argument("--province", help="指定省份（仅 gov 模式）")
    parser.add_argument("--fenbi-cookie", help="粉笔网登录 Cookie")
    parser.add_argument("--xhs-cookie", help="小红书登录 Cookie")
    parser.add_argument("--normalize-only", action="store_true", help="仅执行标准化（跳过爬取）")
    parser.add_argument("--input", help="输入原始数据 JSON 文件（与 --normalize-only 配合使用）")
    args = parser.parse_args()

    logger.info("=" * 60)
    logger.info(f"真题爬虫启动 @ {datetime.now().isoformat()}")
    logger.info(f"目标年份: {TARGET_YEARS}")
    logger.info("=" * 60)

    # 收集原始数据
    raw_questions = []

    if args.normalize_only and args.input:
        logger.info(f"从文件加载原始数据: {args.input}")
        with open(args.input, encoding="utf-8") as f:
            raw_questions = json.load(f)
    else:
        source = args.source

        if source in ("all", "fenbi"):
            logger.info("▶ 粉笔网爬虫...")
            raw_questions.extend(run_fenbi(cookie=args.fenbi_cookie))

        if source in ("all", "qzzn"):
            logger.info("▶ QZZN 论坛爬虫...")
            raw_questions.extend(run_qzzn())

        if source in ("all", "gov"):
            logger.info("▶ 省级人事考试网爬虫...")
            raw_questions.extend(run_gov(province=args.province))

        if source in ("all", "xiaohongshu"):
            logger.info("▶ 小红书爬虫...")
            raw_questions.extend(run_xiaohongshu(cookie=args.xhs_cookie))

    logger.info(f"原始数据: {len(raw_questions)} 条")

    if not raw_questions:
        logger.warning("未获取到任何数据，程序退出")
        logger.info("提示：爬虫框架已就绪，各爬虫的 scrape() 方法中有详细的 TODO 注释")
        logger.info("      实际运行前需要完成各数据源的页面解析逻辑")
        return

    # 标准化
    logger.info("▶ 数据标准化...")
    normalized = normalize_batch(raw_questions)
    logger.info(f"标准化后: {len(normalized)} 条")

    # 去重
    logger.info("▶ 去重处理...")
    deduped = dedup(normalized)
    logger.info(f"去重后: {len(deduped)} 条")

    # 保存
    logger.info("▶ 保存 JSON 文件...")
    saved_files = save_all_groups(deduped)

    logger.info("=" * 60)
    logger.info(f"完成！共生成 {len(saved_files)} 个 JSON 文件:")
    for f in saved_files:
        logger.info(f"  {f}")
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
