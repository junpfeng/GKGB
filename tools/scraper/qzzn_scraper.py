"""
QZZN 论坛爬虫（bbs.qzzn.com）
社区整理的真题补充来源，以帖子形式发布
"""

import re
import logging
from typing import Optional
from bs4 import BeautifulSoup

from base_scraper import BaseScraper
from config import QZZN_CONFIG, TARGET_YEARS

logger = logging.getLogger("qzzn_scraper")


class QzznScraper(BaseScraper):
    """
    QZZN 论坛真题爬虫
    论坛结构：
    - 帖子列表页（按版块分类）
    - 帖子详情页（含题目文本）
    - 题目以纯文本形式嵌入帖子内容

    TODO: 实际调研 QZZN 论坛版块结构和页面 HTML 后补全解析逻辑
    """

    # 年份关键词，用于筛选真题帖子
    YEAR_KEYWORDS = [str(y) for y in TARGET_YEARS]
    EXAM_KEYWORDS = ["国考", "省考", "行测", "真题", "申论"]

    def __init__(self):
        super().__init__("QzznScraper", QZZN_CONFIG["base_url"])

    def _fetch_thread_list(self, section_url: str, page: int = 1) -> list[dict]:
        """
        获取版块帖子列表
        TODO: 调整选择器以匹配实际 HTML 结构
        返回 [{title, url, date}, ...]
        """
        url = f"{self.base_url}{section_url}?page={page}"
        resp = self.get(url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, "lxml")

        threads = []
        # TODO: 根据实际 HTML 结构调整选择器
        # 示例选择器（需实际调研后修改）：
        # for row in soup.select("table.threadlist tr.thread-row"):
        #     title_tag = row.select_one("a.thread-title")
        #     if not title_tag:
        #         continue
        #     title = title_tag.get_text(strip=True)
        #     if not self._is_real_exam_thread(title):
        #         continue
        #     threads.append({
        #         "title": title,
        #         "url": self.base_url + title_tag["href"],
        #         "date": row.select_one("td.date").get_text(strip=True) if row.select_one("td.date") else "",
        #     })

        logger.info(f"获取帖子列表: {url} -> {len(threads)} 条")
        return threads

    def _is_real_exam_thread(self, title: str) -> bool:
        """判断帖子是否为真题相关"""
        title_lower = title.lower()
        has_year = any(year in title for year in self.YEAR_KEYWORDS)
        has_keyword = any(kw in title for kw in self.EXAM_KEYWORDS)
        return has_year and has_keyword

    def _parse_thread_content(self, url: str, exam_type: str, year: int) -> list[dict]:
        """
        解析帖子内容，提取题目
        TODO: 根据实际论坛帖子 HTML 结构调整
        """
        resp = self.get(url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, "lxml")

        # TODO: 提取帖子正文
        # content_div = soup.select_one("div.post-content, div.message-content")
        # if not content_div:
        #     return []
        # text = content_div.get_text("\n", strip=True)
        # return self._extract_questions_from_text(text, exam_type, year)

        return []

    def _extract_questions_from_text(self, text: str, exam_type: str, year: int) -> list[dict]:
        """
        从纯文本中正则提取题目
        论坛常见格式：
        1. 题目内容
        A. 选项一  B. 选项二  C. 选项三  D. 选项四
        【答案】A
        【解析】详细解析内容...
        """
        questions = []
        # 匹配题目块（数字序号开头）
        pattern = re.compile(
            r"(\d+)[.、]\s*(.+?)\s*"       # 题号 + 题目内容
            r"A[.、](.+?)\s*"               # 选项 A
            r"B[.、](.+?)\s*"               # 选项 B
            r"C[.、](.+?)\s*"               # 选项 C
            r"D[.、](.+?)\s*"               # 选项 D
            r"【?答案】?\s*([ABCD]+)\s*"    # 答案
            r"(?:【?解析】?\s*(.+?))?(?=\d+[.、]|\Z)",  # 解析（可选）
            re.DOTALL,
        )

        for match in pattern.finditer(text):
            _, content, a, b, c, d, answer, explanation = match.groups()
            questions.append({
                "subject": "行测",
                "category": self._guess_category(content),
                "type": "single",
                "content": content.strip(),
                "options": [
                    f"A. {a.strip()}",
                    f"B. {b.strip()}",
                    f"C. {c.strip()}",
                    f"D. {d.strip()}",
                ],
                "answer": answer.strip(),
                "explanation": (explanation or "").strip(),
                "difficulty": 2,
                "region": "",
                "year": year,
                "exam_type": exam_type,
                "exam_session": "",
                "is_real_exam": 1,
            })

        return questions

    def _guess_category(self, content: str) -> str:
        """根据题目内容猜测分类（关键词启发式）"""
        if any(kw in content for kw in ["数据", "图表", "增长率", "比重"]):
            return "资料分析"
        if any(kw in content for kw in ["逻辑", "推理", "假设", "削弱", "加强"]):
            return "判断推理"
        if any(kw in content for kw in ["工程", "行程", "概率", "排列", "组合", "利润"]):
            return "数量关系"
        if any(kw in content for kw in ["法律", "常识", "政治", "历史", "地理", "科技"]):
            return "常识判断"
        return "言语理解"

    def scrape(self) -> list[dict]:
        """
        爬取 QZZN 论坛真题
        TODO: 完整实现需要：
        1. 遍历各版块（国考、省考）
        2. 筛选年份相关帖子
        3. 解析帖子内容提取题目
        """
        results = []
        logger.info("QZZN 论坛爬虫启动")

        # TODO: 实现完整爬取逻辑
        # for section_name, section_path in QZZN_CONFIG["sections"].items():
        #     page = 1
        #     while True:
        #         threads = self._fetch_thread_list(section_path, page)
        #         if not threads:
        #             break
        #         for thread in threads:
        #             year = self._extract_year_from_title(thread["title"])
        #             if year not in TARGET_YEARS:
        #                 continue
        #             exam_type = "国考" if section_name == "guokao" else "省考"
        #             questions = self._parse_thread_content(thread["url"], exam_type, year)
        #             results.extend(questions)
        #         page += 1

        logger.info(f"QZZN 爬取完成，共 {len(results)} 道题")
        return results

    def _extract_year_from_title(self, title: str) -> int:
        """从帖子标题中提取年份"""
        for year in TARGET_YEARS:
            if str(year) in title:
                return year
        return 0
