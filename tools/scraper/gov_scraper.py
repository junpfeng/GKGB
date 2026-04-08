"""
各省人事考试网爬虫
官方真题来源（部分省份公开发布）
"""

import re
import logging
from typing import Optional
from bs4 import BeautifulSoup

from base_scraper import BaseScraper
from config import GOV_EXAM_CONFIG, TARGET_YEARS

logger = logging.getLogger("gov_scraper")


class GovExamScraper(BaseScraper):
    """
    省级人事考试网真题爬虫
    各省网站结构差异较大，需要逐一调研

    已知特点：
    - 多数省份以 PDF 或 Word 形式发布真题
    - 少数省份直接发布 HTML 页面（解析相对简单）
    - 部分省份只公布答案，不公布题目内容

    TODO: 各省具体页面结构需实际访问后确认
    """

    def __init__(self, province: str):
        site_config = GOV_EXAM_CONFIG["sites"].get(province, {})
        if not site_config:
            raise ValueError(f"不支持的省份: {province}")
        super().__init__(f"GovScraper_{province}", site_config["url"])
        self.province_key = province
        self.province_name = site_config["name"]
        self.site_config = site_config

    def _fetch_exam_page_list(self, page: int = 1) -> list[dict]:
        """
        获取真题发布页面列表
        TODO: 各省网站结构不同，需分别实现
        返回 [{title, url, year, subject}, ...]
        """
        resp = self.get(self.base_url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, "lxml")
        pages = []

        # TODO: 根据各省网站实际 HTML 结构调整
        # 通用策略：在页面中搜索包含"真题"或"试题"的链接
        for link in soup.find_all("a", href=True):
            text = link.get_text(strip=True)
            href = link["href"]
            if not self._is_exam_link(text, href):
                continue
            year = self._extract_year(text + href)
            if year not in TARGET_YEARS:
                continue
            full_url = self._make_absolute(href)
            pages.append({
                "title": text,
                "url": full_url,
                "year": year,
                "subject": self._guess_subject(text),
            })

        logger.info(f"{self.province_name}: 找到 {len(pages)} 个真题页面")
        return pages

    def _is_exam_link(self, text: str, href: str) -> bool:
        """判断链接是否为真题相关"""
        keywords = ["真题", "试题", "行测", "申论", "笔试", "历年"]
        combined = text + href
        return any(kw in combined for kw in keywords)

    def _extract_year(self, text: str) -> int:
        """从文本中提取年份"""
        match = re.search(r"(202[0-5])", text)
        return int(match.group(1)) if match else 0

    def _guess_subject(self, text: str) -> str:
        """从标题猜测科目"""
        if "行测" in text or "行政职业能力" in text:
            return "行测"
        if "申论" in text:
            return "申论"
        if "公基" in text or "公共基础" in text:
            return "公基"
        return "行测"

    def _make_absolute(self, href: str) -> str:
        """将相对路径转为绝对路径"""
        if href.startswith("http"):
            return href
        if href.startswith("/"):
            return self.base_url + href
        return self.base_url + "/" + href

    def _parse_html_page(self, url: str, year: int, subject: str) -> list[dict]:
        """
        解析 HTML 格式真题页面
        TODO: 根据各省实际 HTML 结构调整选择器
        """
        resp = self.get(url)
        if resp is None:
            return []

        soup = BeautifulSoup(resp.text, "lxml")

        # TODO: 提取题目内容区域
        # content_div = soup.select_one("div.article-content, div.exam-content, #content")
        # if not content_div:
        #     return []
        # text = content_div.get_text("\n", strip=True)
        # return self._parse_text_questions(text, year, subject)

        return []

    def _parse_text_questions(self, text: str, year: int, subject: str) -> list[dict]:
        """
        从纯文本中解析题目（官网发布格式通常较规范）
        """
        questions = []
        # 匹配标准行测题目格式
        pattern = re.compile(
            r"(\d+)(?:[.、])\s*(.+?)(?:\n|　)"
            r"A(?:[.、])(.+?)(?:\n|　)"
            r"B(?:[.、])(.+?)(?:\n|　)"
            r"C(?:[.、])(.+?)(?:\n|　)"
            r"D(?:[.、])(.+?)(?=\d+[.、]|\Z)",
            re.DOTALL,
        )

        for match in pattern.finditer(text):
            _, content, a, b, c, d = match.groups()
            questions.append({
                "subject": subject,
                "category": self._guess_category(content),
                "type": "single",
                "content": content.strip(),
                "options": [
                    f"A. {a.strip()}",
                    f"B. {b.strip()}",
                    f"C. {c.strip()}",
                    f"D. {d.strip()}",
                ],
                "answer": "",  # 官网一般单独发布答案
                "explanation": "",
                "difficulty": 2,
                "region": self.province_name,
                "year": year,
                "exam_type": "省考",
                "exam_session": "",
                "is_real_exam": 1,
            })

        return questions

    def _guess_category(self, content: str) -> str:
        """根据题目内容猜测分类"""
        if any(kw in content for kw in ["数据", "图表", "增长", "比重", "总量"]):
            return "资料分析"
        if any(kw in content for kw in ["推理", "论证", "削弱", "加强", "假设", "图形"]):
            return "判断推理"
        if any(kw in content for kw in ["工程", "行程", "概率", "排列", "组合"]):
            return "数量关系"
        if any(kw in content for kw in ["法律", "宪法", "政治", "历史", "科学"]):
            return "常识判断"
        return "言语理解"

    def scrape(self) -> list[dict]:
        """
        爬取省级人事考试网真题
        TODO: 完整实现需要：
        1. 获取真题发布页面列表
        2. 按年份筛选（2020-2025）
        3. 下载并解析题目（HTML/PDF/Word）
        4. 与答案关联（可能需要分别下载）
        """
        results = []
        logger.info(f"{self.province_name}人事考试网爬虫启动")

        # TODO: 实现完整爬取逻辑
        # pages = self._fetch_exam_page_list()
        # for page_info in pages:
        #     questions = self._parse_html_page(
        #         page_info["url"],
        #         page_info["year"],
        #         page_info["subject"],
        #     )
        #     results.extend(questions)

        logger.info(f"{self.province_name}: 爬取完成，共 {len(results)} 道题")
        return results


def scrape_all_provinces() -> list[dict]:
    """批量爬取所有配置省份"""
    all_results = []
    for province_key, config in GOV_EXAM_CONFIG["sites"].items():
        if not config.get("enabled", False):
            continue
        try:
            scraper = GovExamScraper(province_key)
            results = scraper.scrape()
            all_results.extend(results)
        except Exception as e:
            logger.error(f"爬取 {province_key} 失败: {e}")
    return all_results
