"""
爬虫基类
封装请求限速、robots.txt 检查、重试逻辑
"""

import time
import random
import logging
import urllib.robotparser
from abc import ABC, abstractmethod
from typing import Optional
from urllib.parse import urlparse

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from config import (
    REQUEST_DELAY_MIN,
    REQUEST_DELAY_MAX,
    REQUEST_TIMEOUT,
    MAX_RETRIES,
    RETRY_DELAY,
    USER_AGENT,
    LOG_LEVEL,
    LOG_FILE,
)

# 配置日志
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(),
    ],
)


class BaseScraper(ABC):
    """
    爬虫基类，提供：
    - robots.txt 合规检查
    - 请求限速（≥2s 间隔）
    - 自动重试（指数退避）
    - 统一 User-Agent
    """

    def __init__(self, name: str, base_url: str):
        self.name = name
        self.base_url = base_url
        self.logger = logging.getLogger(name)
        self._last_request_time: float = 0
        self._robots_parser: Optional[urllib.robotparser.RobotFileParser] = None
        self._session = self._build_session()

    def _build_session(self) -> requests.Session:
        """构建带重试策略的 HTTP Session"""
        session = requests.Session()
        retry_strategy = Retry(
            total=MAX_RETRIES,
            backoff_factor=2,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST"],
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount("https://", adapter)
        session.mount("http://", adapter)
        session.headers.update({
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate, br",
        })
        return session

    def _check_robots(self, url: str) -> bool:
        """
        检查目标 URL 是否被 robots.txt 允许爬取
        返回 True 表示允许，False 表示禁止
        """
        try:
            parsed = urlparse(url)
            robots_url = f"{parsed.scheme}://{parsed.netloc}/robots.txt"

            if self._robots_parser is None:
                self._robots_parser = urllib.robotparser.RobotFileParser()
                self._robots_parser.set_url(robots_url)
                try:
                    self._robots_parser.read()
                    self.logger.info(f"已加载 robots.txt: {robots_url}")
                except Exception as e:
                    # robots.txt 读取失败时保守处理，允许访问
                    self.logger.warning(f"robots.txt 加载失败（{robots_url}）: {e}，默认允许访问")
                    return True

            allowed = self._robots_parser.can_fetch(USER_AGENT, url)
            if not allowed:
                self.logger.warning(f"robots.txt 禁止访问: {url}")
            return allowed
        except Exception as e:
            self.logger.warning(f"robots.txt 检查异常: {e}，保守放行")
            return True

    def _rate_limit(self):
        """限速：确保请求间隔 ≥ REQUEST_DELAY_MIN 秒"""
        now = time.time()
        elapsed = now - self._last_request_time
        delay = random.uniform(REQUEST_DELAY_MIN, REQUEST_DELAY_MAX)
        if elapsed < delay:
            sleep_time = delay - elapsed
            self.logger.debug(f"限速等待 {sleep_time:.2f}s")
            time.sleep(sleep_time)
        self._last_request_time = time.time()

    def get(self, url: str, **kwargs) -> Optional[requests.Response]:
        """
        发送 GET 请求（含限速、robots 检查、重试）
        返回 Response 或 None（失败时）
        """
        if not self._check_robots(url):
            self.logger.error(f"robots.txt 拒绝，跳过: {url}")
            return None

        self._rate_limit()

        for attempt in range(1, MAX_RETRIES + 1):
            try:
                resp = self._session.get(url, timeout=REQUEST_TIMEOUT, **kwargs)
                resp.raise_for_status()
                self.logger.debug(f"GET {url} -> {resp.status_code}")
                return resp
            except requests.exceptions.HTTPError as e:
                if resp.status_code == 429:
                    wait = RETRY_DELAY * (2 ** attempt)
                    self.logger.warning(f"被限速(429)，等待 {wait}s 后重试")
                    time.sleep(wait)
                else:
                    self.logger.error(f"HTTP 错误 {e}（尝试 {attempt}/{MAX_RETRIES}）")
                    if attempt < MAX_RETRIES:
                        time.sleep(RETRY_DELAY)
            except requests.exceptions.RequestException as e:
                self.logger.error(f"请求失败: {e}（尝试 {attempt}/{MAX_RETRIES}）")
                if attempt < MAX_RETRIES:
                    time.sleep(RETRY_DELAY * attempt)

        self.logger.error(f"已放弃: {url}")
        return None

    def post(self, url: str, **kwargs) -> Optional[requests.Response]:
        """发送 POST 请求（含限速和重试）"""
        if not self._check_robots(url):
            self.logger.error(f"robots.txt 拒绝，跳过: {url}")
            return None

        self._rate_limit()

        for attempt in range(1, MAX_RETRIES + 1):
            try:
                resp = self._session.post(url, timeout=REQUEST_TIMEOUT, **kwargs)
                resp.raise_for_status()
                return resp
            except requests.exceptions.RequestException as e:
                self.logger.error(f"POST 失败: {e}（尝试 {attempt}/{MAX_RETRIES}）")
                if attempt < MAX_RETRIES:
                    time.sleep(RETRY_DELAY * attempt)

        return None

    @abstractmethod
    def scrape(self) -> list[dict]:
        """
        执行爬取，返回原始题目数据列表
        每条数据为 dict，包含题目内容、选项、答案等字段
        由子类实现具体页面解析逻辑
        """
        pass
