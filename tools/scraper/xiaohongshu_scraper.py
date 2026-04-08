"""
小红书爬虫（xiaohongshu.com）
真题回忆版补充来源，内容以图片为主，需要 OCR 识别
默认关闭，需要手动启用并配置 OCR 服务
"""

import logging
import re
from typing import Optional

from base_scraper import BaseScraper
from config import XIAOHONGSHU_CONFIG, TARGET_YEARS

logger = logging.getLogger("xiaohongshu_scraper")


class XiaohongshuScraper(BaseScraper):
    """
    小红书真题回忆版爬虫
    特殊挑战：
    1. 小红书强制登录，需要 Cookie/Token
    2. 真题内容多以图片形式发布，需要 OCR
    3. 内容质量参差不齐，需要过滤噪音
    4. 有较严格的反爬机制

    TODO: 实现完整功能需要：
    - 有效的小红书登录态（Cookie）
    - OCR 服务（推荐使用 paddleocr 或百度/阿里云 OCR API）
    - 图片质量过滤
    - 文本清洗和题目结构化
    """

    def __init__(self, cookie: Optional[str] = None, ocr_service=None):
        super().__init__("XiaohongshuScraper", XIAOHONGSHU_CONFIG["base_url"])
        if cookie:
            self._session.headers.update({
                "Cookie": cookie,
                "X-Sign": "",  # TODO: 小红书签名验证（需逆向）
            })
        self._ocr_service = ocr_service

    def _search_notes(self, keyword: str, page: int = 1) -> list[dict]:
        """
        搜索笔记（真题回忆相关）
        TODO: 小红书搜索 API 端点（需调研实际接口）
        """
        # TODO: 实现小红书搜索 API 调用
        # 注意：小红书有签名验证，直接 API 调用可能需要破解
        # 推荐使用 Selenium 模拟浏览器操作
        logger.warning("小红书搜索 TODO: 需要配置有效 Cookie 和签名")
        return []

    def _download_images(self, note_url: str) -> list[bytes]:
        """
        下载笔记中的图片
        TODO: 解析笔记页面，提取所有图片 URL 并下载
        """
        resp = self.get(note_url)
        if resp is None:
            return []

        # TODO: 解析图片 URL
        # soup = BeautifulSoup(resp.text, "lxml")
        # img_tags = soup.select("img.note-image")
        # images = []
        # for img in img_tags:
        #     img_url = img.get("src") or img.get("data-src")
        #     if img_url:
        #         img_resp = self.get(img_url)
        #         if img_resp:
        #             images.append(img_resp.content)
        # return images

        return []

    def _ocr_image(self, image_bytes: bytes) -> str:
        """
        对图片进行 OCR 识别
        TODO: 接入 OCR 服务（paddleocr / 云 OCR API）
        """
        if self._ocr_service is None:
            logger.warning("未配置 OCR 服务，跳过图片识别")
            return ""

        # TODO: 调用 OCR 服务
        # try:
        #     result = self._ocr_service.recognize(image_bytes)
        #     return result.text
        # except Exception as e:
        #     logger.error(f"OCR 识别失败: {e}")
        #     return ""

        return ""

    def _extract_questions_from_ocr_text(self, text: str, year: int, exam_type: str) -> list[dict]:
        """
        从 OCR 识别文本中提取题目
        OCR 文本通常含有噪音，需要更宽松的正则匹配
        """
        questions = []
        # OCR 文本可能存在错字、换行不规则等问题
        # 使用宽松的正则匹配
        pattern = re.compile(
            r"(\d+)[.、。]\s*(.{10,200}?)\s*"  # 题号 + 内容（最少10字）
            r"[AaＡ][.、。](.{2,50}?)\s*"       # 选项 A
            r"[BbＢ][.、。](.{2,50}?)\s*"       # 选项 B
            r"[CcＣ][.、。](.{2,50}?)\s*"       # 选项 C
            r"[DdＤ][.、。](.{2,50}?)"           # 选项 D
            r"(?:\s*答案[:：]\s*([ABCD]+))?",    # 可选答案
            re.DOTALL,
        )

        for match in pattern.finditer(text):
            groups = match.groups()
            _, content = groups[0], groups[1]
            a, b, c, d = groups[2], groups[3], groups[4], groups[5]
            answer = groups[6] if len(groups) > 6 else ""

            if len(content.strip()) < 10:  # 过滤太短的"题目"
                continue

            questions.append({
                "subject": "行测",
                "category": "言语理解",  # OCR 来源难以准确分类
                "type": "single",
                "content": content.strip(),
                "options": [
                    f"A. {a.strip() if a else ''}",
                    f"B. {b.strip() if b else ''}",
                    f"C. {c.strip() if c else ''}",
                    f"D. {d.strip() if d else ''}",
                ],
                "answer": (answer or "").strip(),
                "explanation": "",
                "difficulty": 2,
                "region": "",
                "year": year,
                "exam_type": exam_type,
                "exam_session": "",
                "is_real_exam": 1,
                "source": "xiaohongshu_ocr",  # 标记来源，便于质量过滤
            })

        return questions

    def scrape(self) -> list[dict]:
        """
        爬取小红书真题回忆版
        默认返回空列表（需手动启用）
        """
        if not XIAOHONGSHU_CONFIG.get("enabled", False):
            logger.info("小红书爬虫已禁用（在 config.py 中启用）")
            return []

        results = []
        logger.info("小红书爬虫启动（注意：需要有效登录态和 OCR 服务）")

        # TODO: 实现完整爬取逻辑
        # for keyword in XIAOHONGSHU_CONFIG["search_keywords"]:
        #     notes = self._search_notes(keyword)
        #     for note in notes:
        #         year = self._extract_year_from_note(note)
        #         if year not in TARGET_YEARS:
        #             continue
        #         images = self._download_images(note["url"])
        #         for img in images:
        #             text = self._ocr_image(img)
        #             if text:
        #                 questions = self._extract_questions_from_ocr_text(
        #                     text, year, "国考"
        #                 )
        #                 results.extend(questions)

        logger.info(f"小红书爬取完成，共 {len(results)} 道题")
        return results
