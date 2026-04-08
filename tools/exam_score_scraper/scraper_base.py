"""
爬虫基类 — 节流 ≥2s/request、User-Agent、robots.txt 检查
"""

import time
import logging
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser
from typing import Optional

import requests

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


class ScraperBase:
    """所有爬虫的基类，内置合规控制"""

    USER_AGENT = 'ExamPrepApp/1.0 (exam-entry-scores-data-collector; educational-use)'
    MIN_INTERVAL = 2.0  # 宪法要求：请求间隔 ≥2s

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': self.USER_AGENT,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        })
        self._last_request_time = 0.0
        self._robots_cache: dict[str, Optional[RobotFileParser]] = {}

    def _throttle(self):
        """强制节流 ≥2s/request"""
        elapsed = time.time() - self._last_request_time
        if elapsed < self.MIN_INTERVAL:
            wait = self.MIN_INTERVAL - elapsed
            logger.debug(f'节流等待 {wait:.1f}s')
            time.sleep(wait)
        self._last_request_time = time.time()

    def _check_robots(self, url: str) -> bool:
        """检查 robots.txt 是否允许爬取"""
        parsed = urlparse(url)
        base = f'{parsed.scheme}://{parsed.netloc}'

        if base not in self._robots_cache:
            rp = RobotFileParser()
            robots_url = f'{base}/robots.txt'
            try:
                rp.set_url(robots_url)
                rp.read()
                self._robots_cache[base] = rp
                logger.info(f'已加载 robots.txt: {robots_url}')
            except Exception as e:
                logger.warning(f'无法读取 robots.txt ({robots_url}): {e}，默认允许')
                self._robots_cache[base] = None

        rp = self._robots_cache[base]
        if rp is None:
            return True
        return rp.can_fetch(self.USER_AGENT, url)

    def fetch(self, url: str, **kwargs) -> Optional[requests.Response]:
        """带节流和 robots.txt 检查的 GET 请求"""
        if not self._check_robots(url):
            logger.warning(f'robots.txt 禁止爬取: {url}')
            return None

        self._throttle()
        try:
            resp = self.session.get(url, timeout=30, **kwargs)
            resp.raise_for_status()
            logger.info(f'成功获取: {url} ({len(resp.content)} bytes)')
            return resp
        except requests.RequestException as e:
            logger.error(f'请求失败: {url} - {e}')
            return None

    def fetch_binary(self, url: str, **kwargs) -> Optional[bytes]:
        """获取二进制内容（如 Excel 文件）"""
        resp = self.fetch(url, **kwargs)
        if resp is not None:
            return resp.content
        return None
