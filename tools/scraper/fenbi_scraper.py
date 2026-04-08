"""
粉笔网爬虫（fenbi.com）
主力数据源，题量大、解析详细
注意：需要登录态 Cookie，建议手动获取后配置
"""

import json
import logging
from typing import Optional

from base_scraper import BaseScraper
from config import FENBI_CONFIG, TARGET_YEARS

logger = logging.getLogger("fenbi_scraper")


class FenbiScraper(BaseScraper):
    """
    粉笔网真题爬虫
    粉笔网结构特点：
    - 题目通过 API 返回 JSON
    - 需要登录态（Cookie: userid, token）
    - 题目有分类标签（exam_type, subject, category）

    TODO: 实际调研粉笔网 API 结构后补全以下 endpoint：
    - 题目列表：GET /api/exercises/{courseId}/questions?page=1&limit=20
    - 题目详情：GET /api/questions/{questionId}
    - 分类列表：GET /api/courses
    """

    # 已知题型 ID（TODO: 调研确认）
    COURSE_ID_MAP = {
        ("国考", "行测"): "xt",      # 行测课程 ID 前缀
        ("国考", "申论"): "sl",      # 申论课程 ID 前缀
        ("省考", "行测"): "sx",
        ("省考", "申论"): "ss",
        ("事业编", "公基"): "gj",
    }

    def __init__(self, cookie: Optional[str] = None):
        super().__init__("FenbiScraper", FENBI_CONFIG["base_url"])
        if cookie:
            self._session.headers.update({"Cookie": cookie})
        self._api_base = FENBI_CONFIG["api_url"]

    def _fetch_question_list(self, course_id: str, page: int = 1, limit: int = 20) -> dict:
        """
        获取题目列表
        TODO: 根据实际 API 结构调整 URL 和参数
        """
        url = f"{self._api_base}/exercises/{course_id}/questions"
        params = {"page": page, "limit": limit, "real_exam": 1}
        resp = self.get(url, params=params)
        if resp is None:
            return {}
        try:
            return resp.json()
        except Exception as e:
            logger.error(f"JSON 解析失败: {e}")
            return {}

    def _fetch_question_detail(self, question_id: str) -> dict:
        """
        获取单题详情（含解析）
        TODO: 根据实际 API 结构调整
        """
        url = f"{self._api_base}/questions/{question_id}"
        resp = self.get(url)
        if resp is None:
            return {}
        try:
            return resp.json()
        except Exception as e:
            logger.error(f"解析题目详情失败: {e}")
            return {}

    def _parse_question(self, raw: dict, exam_type: str, subject: str, year: int) -> Optional[dict]:
        """
        将粉笔 API 返回的原始数据转换为标准格式
        TODO: 根据实际 API 响应结构调整字段映射
        """
        try:
            content = raw.get("content") or raw.get("question") or raw.get("stem", "")
            if not content:
                return None

            # TODO: 调整字段名以匹配实际 API 响应
            options_raw = raw.get("options", raw.get("choices", []))
            options = []
            if isinstance(options_raw, list):
                for i, opt in enumerate(options_raw):
                    prefix = chr(ord('A') + i)
                    if isinstance(opt, dict):
                        text = opt.get("content", opt.get("text", ""))
                        options.append(f"{prefix}. {text}")
                    else:
                        options.append(f"{prefix}. {opt}")

            answer = raw.get("answer", raw.get("correct_answer", ""))
            explanation = raw.get("explanation", raw.get("analysis", raw.get("solution", "")))

            # 分类映射（TODO: 调整为实际 API 返回的分类字段）
            category_map = {
                "言语理解": "言语理解",
                "数量关系": "数量关系",
                "判断推理": "判断推理",
                "资料分析": "资料分析",
                "常识判断": "常识判断",
            }
            raw_category = raw.get("category", raw.get("tag", ""))
            category = category_map.get(raw_category, raw_category or subject)

            return {
                "subject": subject,
                "category": category,
                "type": self._map_question_type(raw.get("type", "single")),
                "content": content.strip(),
                "options": options,
                "answer": answer,
                "explanation": explanation or "",
                "difficulty": raw.get("difficulty", 2),
                "region": "全国" if exam_type == "国考" else raw.get("region", ""),
                "year": year,
                "exam_type": exam_type,
                "exam_session": raw.get("exam_session", ""),
                "is_real_exam": 1,
            }
        except Exception as e:
            logger.error(f"解析题目失败: {e}, raw={raw}")
            return None

    def _map_question_type(self, raw_type: str) -> str:
        """映射粉笔题型到标准类型"""
        # TODO: 根据粉笔实际类型值调整
        type_map = {
            "单选题": "single",
            "多选题": "multiple",
            "判断题": "judge",
            "主观题": "subjective",
            "single": "single",
            "multiple": "multiple",
            "judge": "judge",
            "subjective": "subjective",
        }
        return type_map.get(raw_type, "single")

    def scrape(self) -> list[dict]:
        """
        爬取粉笔网真题
        TODO: 完整实现需要：
        1. 登录获取有效 Cookie（或用户配置 Cookie）
        2. 遍历 TARGET_YEARS 和各科目
        3. 分页获取题目列表
        4. 逐题获取详情和解析
        """
        results = []
        logger.info("粉笔网爬虫启动（TODO: 需配置有效 Cookie）")

        # TODO: 实现完整爬取逻辑
        # 示例框架：
        # for year in TARGET_YEARS:
        #     for (exam_type, subject), course_id_prefix in self.COURSE_ID_MAP.items():
        #         course_id = f"{course_id_prefix}_{year}"
        #         page = 1
        #         while True:
        #             data = self._fetch_question_list(course_id, page)
        #             if not data or not data.get("questions"):
        #                 break
        #             for raw_q in data["questions"]:
        #                 detail = self._fetch_question_detail(raw_q["id"])
        #                 parsed = self._parse_question(detail, exam_type, subject, year)
        #                 if parsed:
        #                     results.append(parsed)
        #             if page >= data.get("total_pages", 1):
        #                 break
        #             page += 1

        logger.info(f"粉笔网爬取完成，共 {len(results)} 道题")
        return results
