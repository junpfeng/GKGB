"""
粉笔网爬虫（tiku.fenbi.com）
主力数据源，题量大、解析详细

API 流程：
1. GET /subLabels → 省份/地区列表（含 labelId）
2. GET /papers/?labelId=X → 试卷列表
3. POST /exercises (type=1, paperId=X, exerciseTimeMode=2) → 创建 exercise
4. GET /exercises/{exerciseId} → exercise 详情（含 sheet.questionIds）
5. GET /solutions?ids=X,Y,Z → 题目+选项+答案+解析（最丰富端点）
"""

import re
import json
import logging
import time
from typing import Optional
from html import unescape

from base_scraper import BaseScraper
from config import FENBI_CONFIG, TARGET_YEARS

logger = logging.getLogger("fenbi_scraper")

# 粉笔 API 基础参数
BASE_PARAMS = "app=web&kav=100&av=100&hav=1&version=3.0.0.0"

# 科目 URL 前缀 → 科目名映射
PREFIX_SUBJECT_MAP = {
    "xingce": "行测",
    "shenlun": "申论",
    "gonggong": "公基",
}

# 行测分类映射（章节名 → 标准分类名）
CHAPTER_CATEGORY_MAP = {
    "常识判断": "常识判断",
    "言语理解与表达": "言语理解",
    "数量关系": "数量关系",
    "判断推理": "判断推理",
    "资料分析": "资料分析",
}

# 目标省份/地区 label 名称
TARGET_LABELS = {"国考", "江苏", "浙江", "上海", "山东"}


def _strip_html(html: str) -> str:
    """去除 HTML 标签，保留纯文本"""
    if not html:
        return ""
    # 处理 <img> formula 标签（粉笔用 img 嵌入公式）
    text = re.sub(r'<img[^>]*alt=["\']([^"\']*)["\'][^>]*>', r'\1', html)
    # 处理 <br> 和 <p>
    text = re.sub(r'<br\s*/?>', '\n', text)
    text = re.sub(r'</p>\s*<p>', '\n', text)
    # 去除剩余 HTML 标签
    text = re.sub(r'<[^>]+>', '', text)
    # HTML 实体解码
    text = unescape(text)
    # 规范化空白
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def _parse_year_from_name(name: str) -> int:
    """从试卷名提取年份，如 '2024年国家公务员录用考试' → 2024"""
    m = re.search(r'(20\d{2})年', name)
    return int(m.group(1)) if m else 0


def _parse_exam_info_from_name(name: str) -> dict:
    """从试卷名解析考试类型和地区信息"""
    info = {"exam_type": "", "region": "", "exam_session": ""}
    if "国家公务员" in name or "国考" in name:
        info["exam_type"] = "国考"
        info["region"] = "全国"
    elif "事业" in name:
        info["exam_type"] = "事业编"
    else:
        info["exam_type"] = "省考"

    # 解析卷别信息
    if "副省" in name:
        info["exam_session"] = "副省级"
    elif "地市" in name:
        info["exam_session"] = "地市级"
    elif "行政执法" in name:
        info["exam_session"] = "行政执法"
    elif "A类" in name or "Ａ类" in name:
        info["exam_session"] = "A类"
    elif "B类" in name or "Ｂ类" in name:
        info["exam_session"] = "B类"
    elif "C类" in name or "Ｃ类" in name:
        info["exam_session"] = "C类"

    return info


def _choice_to_letter(choice_str: str, options_count: int) -> str:
    """将粉笔的 choice 索引（0-indexed）转为字母答案"""
    if not choice_str:
        return ""
    # 可能是多选：'0,2' → 'AC'
    parts = choice_str.split(",")
    letters = []
    for p in parts:
        p = p.strip()
        if p.isdigit():
            idx = int(p)
            if 0 <= idx < options_count:
                letters.append(chr(65 + idx))
    return "".join(sorted(letters))


class FenbiScraper(BaseScraper):
    """
    粉笔网真题爬虫
    需要登录态 Cookie
    """

    def __init__(self, cookie: Optional[str] = None, prefix: str = "xingce"):
        super().__init__("FenbiScraper", FENBI_CONFIG["base_url"])
        self._api_base = FENBI_CONFIG["api_url"]
        self._prefix = prefix
        if cookie:
            self._session.headers.update({"Cookie": cookie})

    def _api_url(self, path: str, extra_params: str = "") -> str:
        """构建完整 API URL"""
        sep = "&" if "?" in path else "?"
        url = f"{self._api_base}/{self._prefix}/{path}{sep}{BASE_PARAMS}"
        if extra_params:
            url += f"&{extra_params}"
        return url

    def get_sub_labels(self) -> list[dict]:
        """获取省份/地区列表"""
        url = self._api_url("subLabels")
        resp = self.get(url)
        if resp is None:
            return []
        try:
            return resp.json()
        except Exception as e:
            logger.error(f"解析 subLabels 失败: {e}")
            return []

    def get_papers(self, label_id: int, page_size: int = 50) -> list[dict]:
        """获取指定 label 的试卷列表"""
        url = self._api_url("papers/", f"toPage=0&pageSize={page_size}&labelId={label_id}")
        resp = self.get(url)
        if resp is None:
            return []
        try:
            data = resp.json()
            return data.get("list", [])
        except Exception as e:
            logger.error(f"解析 papers 失败: {e}")
            return []

    def create_exercise(self, paper_id: int) -> Optional[dict]:
        """创建 exercise（如果已存在则返回已有的）"""
        url = self._api_url("exercises")
        data = f"type=1&paperId={paper_id}&exerciseTimeMode=2"
        self._session.headers["Content-Type"] = "application/x-www-form-urlencoded"
        resp = self.post(url, data=data)
        if self._session.headers.get("Content-Type"):
            del self._session.headers["Content-Type"]
        if resp is None:
            return None
        try:
            if resp.text:
                return resp.json()
            return None
        except Exception as e:
            logger.error(f"创建 exercise 失败: {e}")
            return None

    def get_exercise(self, exercise_id: int) -> Optional[dict]:
        """获取 exercise 详情（含 questionIds）"""
        url = self._api_url(f"exercises/{exercise_id}")
        resp = self.get(url)
        if resp is None:
            return None
        try:
            return resp.json()
        except Exception as e:
            logger.error(f"解析 exercise 失败: {e}")
            return None

    def get_solutions(self, question_ids: list[int]) -> list[dict]:
        """批量获取题目解析（含题目内容+选项+答案+解析）"""
        if not question_ids:
            return []
        ids_str = ",".join(str(qid) for qid in question_ids)
        url = self._api_url("solutions", f"ids={ids_str}")
        resp = self.get(url)
        if resp is None:
            return []
        try:
            return resp.json()
        except Exception as e:
            logger.error(f"解析 solutions 失败: {e}")
            return []

    def _get_question_ids_for_paper(self, paper: dict) -> tuple[Optional[int], list[int], list[dict]]:
        """
        获取试卷的 question IDs
        返回: (exercise_id, question_ids, chapters)
        """
        paper_id = paper["id"]
        paper_name = paper.get("name", "")

        # 检查是否已有 exercise
        existing_ex = paper.get("exercise")
        exercise_id = existing_ex.get("id") if existing_ex else None

        if exercise_id:
            logger.info(f"  使用已有 exercise {exercise_id}")
        else:
            # 创建新 exercise
            result = self.create_exercise(paper_id)
            if result and "id" in result:
                exercise_id = result["id"]
                logger.info(f"  创建 exercise {exercise_id}")
            else:
                logger.warning(f"  创建 exercise 失败: {paper_name}")
                return None, [], []

        # 获取 exercise 详情
        ex_detail = self.get_exercise(exercise_id)
        if not ex_detail:
            return exercise_id, [], []

        sheet = ex_detail.get("sheet", {})
        question_ids = sheet.get("questionIds", [])
        chapters = sheet.get("chapters", [])

        return exercise_id, question_ids, chapters

    def _build_chapter_question_map(self, chapters: list[dict], question_ids: list[int]) -> dict[int, str]:
        """
        根据 chapters 和 questionIds 构建 questionId → 章节名 映射
        chapters 中有 questionCount，按顺序分配
        """
        qid_to_chapter = {}
        idx = 0
        for ch in chapters:
            ch_name = ch.get("name", "")
            ch_count = ch.get("questionCount", 0)
            for _ in range(ch_count):
                if idx < len(question_ids):
                    qid_to_chapter[question_ids[idx]] = ch_name
                    idx += 1
        return qid_to_chapter

    def _parse_solution(self, sol: dict, exam_info: dict, year: int,
                        region: str, qid_to_chapter: dict) -> Optional[dict]:
        """将粉笔 solution 数据转为标准格式"""
        try:
            qid = sol.get("id", 0)
            content_html = sol.get("content", "")
            content = _strip_html(content_html)
            if not content or len(content) < 5:
                return None

            # 选项
            accessories = sol.get("accessories", [])
            options_html = accessories[0].get("options", []) if accessories else []
            options = []
            for i, opt_html in enumerate(options_html):
                letter = chr(65 + i)
                opt_text = _strip_html(opt_html)
                options.append(f"{letter}. {opt_text}")

            # 答案
            correct = sol.get("correctAnswer", {})
            choice = correct.get("choice", "")
            answer = _choice_to_letter(choice, len(options))

            # 解析
            solution_html = sol.get("solution", "")
            explanation = _strip_html(solution_html)

            # 材料（资料分析题等）
            material = sol.get("material")
            if material and material.get("content"):
                material_text = _strip_html(material["content"])
                content = f"【材料】{material_text}\n\n【题目】{content}"

            # 分类（从章节映射获取）
            chapter_name = qid_to_chapter.get(qid, "")
            category = CHAPTER_CATEGORY_MAP.get(chapter_name, chapter_name)
            if not category:
                # 从 keypoints 获取
                keypoints = sol.get("keypoints", [])
                if keypoints:
                    category = keypoints[0].get("name", "")

            # 难度
            difficulty = sol.get("difficulty", 3)
            if isinstance(difficulty, float):
                difficulty = round(difficulty)
            difficulty = max(1, min(5, difficulty))

            # 题型
            q_type = "single"
            if len(answer) > 1:
                q_type = "multiple"

            subject = PREFIX_SUBJECT_MAP.get(self._prefix, "行测")

            return {
                "subject": subject,
                "category": category or subject,
                "type": q_type,
                "content": content,
                "options": options,
                "answer": answer,
                "explanation": explanation,
                "difficulty": difficulty,
                "region": region,
                "year": year,
                "exam_type": exam_info.get("exam_type", ""),
                "exam_session": exam_info.get("exam_session", ""),
                "is_real_exam": 1,
            }
        except Exception as e:
            logger.error(f"解析题目失败: {e}")
            return None

    def scrape(self) -> list[dict]:
        """爬取粉笔网真题"""
        results = []

        # 获取省份/地区列表
        labels = self.get_sub_labels()
        if not labels:
            logger.error("获取 subLabels 失败")
            return results

        # 筛选目标地区
        target_labels = []
        for lb in labels:
            name = lb.get("name", "")
            label_meta = lb.get("labelMeta", {})
            if name in TARGET_LABELS:
                target_labels.append({
                    "name": name,
                    "id": label_meta.get("id", 0),
                    "paper_count": label_meta.get("paperCount", 0),
                })
                logger.info(f"目标地区: {name}, labelId={label_meta.get('id')}, papers={label_meta.get('paperCount')}")

        if not target_labels:
            logger.warning(f"未找到目标地区，可用地区: {[lb.get('name') for lb in labels]}")
            return results

        # 遍历每个地区
        for label in target_labels:
            label_name = label["name"]
            label_id = label["id"]
            paper_count = label["paper_count"]

            logger.info(f"\n{'='*40}")
            logger.info(f"开始爬取: {label_name} ({paper_count} 套试卷)")

            papers = self.get_papers(label_id, page_size=paper_count)
            if not papers:
                logger.warning(f"  未获取到试卷列表")
                continue

            # 筛选目标年份的试卷
            for paper in papers:
                paper_name = paper.get("name", "")
                year = _parse_year_from_name(paper_name)

                if year not in TARGET_YEARS:
                    logger.debug(f"  跳过非目标年份: {paper_name} (year={year})")
                    continue

                logger.info(f"\n  处理: {paper_name}")

                # 解析考试信息
                exam_info = _parse_exam_info_from_name(paper_name)
                region = label_name if label_name != "国考" else "全国"
                if not exam_info["exam_type"]:
                    exam_info["exam_type"] = "国考" if label_name == "国考" else "省考"

                # 获取 question IDs
                exercise_id, question_ids, chapters = self._get_question_ids_for_paper(paper)
                if not question_ids:
                    logger.warning(f"  未获取到题目 IDs")
                    continue

                logger.info(f"  共 {len(question_ids)} 道题")

                # 构建章节映射
                qid_to_chapter = self._build_chapter_question_map(chapters, question_ids)

                # 分批获取 solutions（每批 20 题，避免 URL 过长）
                batch_size = 20
                paper_questions = []
                for i in range(0, len(question_ids), batch_size):
                    batch = question_ids[i:i + batch_size]
                    solutions = self.get_solutions(batch)

                    for sol in solutions:
                        if sol is None:
                            continue
                        parsed = self._parse_solution(sol, exam_info, year, region, qid_to_chapter)
                        if parsed:
                            paper_questions.append(parsed)

                logger.info(f"  解析成功: {len(paper_questions)} 道题")
                results.extend(paper_questions)

        logger.info(f"\n粉笔网爬取完成，共 {len(results)} 道题")
        return results
