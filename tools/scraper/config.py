"""
爬虫配置文件
所有数据源 URL、请求间隔、User-Agent 等集中配置
"""

import os

# ===== 请求配置 =====
# 合规要求：请求间隔 ≥ 2s，遵守 robots.txt
REQUEST_DELAY_MIN = 2.0   # 最小请求间隔（秒）
REQUEST_DELAY_MAX = 5.0   # 最大请求间隔（秒，随机抖动）
REQUEST_TIMEOUT = 30      # 请求超时（秒）
MAX_RETRIES = 3           # 最大重试次数
RETRY_DELAY = 10          # 重试等待（秒）

# ===== User-Agent =====
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36 "
    "ExamPrepBot/1.0 (educational-use; contact@example.com)"
)

# ===== 数据源配置 =====

# 粉笔网（fenbi.com）— 主力源
FENBI_CONFIG = {
    "base_url": "https://fenbi.com",
    "api_url": "https://tiku.fenbi.com/api",
    "enabled": True,
}

# 粉笔网 Cookie（通过命令行参数 --fenbi-cookie 传入更安全）
FENBI_COOKIE = os.environ.get("FENBI_COOKIE", "")

# QZZN 论坛
QZZN_CONFIG = {
    "base_url": "https://bbs.qzzn.com",
    "sections": {
        "guokao": "/thread-list-1.htm",      # 国考专区（TODO: 确认实际路径）
        "shengkao": "/thread-list-2.htm",    # 省考专区（TODO: 确认实际路径）
    },
    "enabled": True,
}

# 各省人事考试网（官方来源）
GOV_EXAM_CONFIG = {
    "sites": {
        "jiangsu": {
            "name": "江苏",
            "url": "http://www.jszk.com.cn",    # TODO: 确认实际域名
            "enabled": True,
        },
        "zhejiang": {
            "name": "浙江",
            "url": "http://www.zjrsks.com",      # TODO: 确认实际域名
            "enabled": True,
        },
        "shanghai": {
            "name": "上海",
            "url": "http://www.rsj.sh.gov.cn",   # TODO: 确认实际域名
            "enabled": True,
        },
        "shandong": {
            "name": "山东",
            "url": "http://www.sdzk.cn",         # TODO: 确认实际域名
            "enabled": True,
        },
    },
    "enabled": True,
}

# 小红书（真题回忆版，图片为主，需要 OCR）
XIAOHONGSHU_CONFIG = {
    "base_url": "https://www.xiaohongshu.com",
    "search_keywords": ["国考真题", "省考真题", "行测真题回忆"],
    "enabled": False,  # 默认关闭，需要登录态和 OCR 支持
}

# ===== 覆盖范围 =====
TARGET_YEARS = list(range(2020, 2026))  # 2020-2025

# 国考科目配置
GUOKAO_SUBJECTS = {
    "副省级": {
        "行测": {"time_limit": 7200, "question_count": 135},
        "申论": {"time_limit": 10800, "question_count": 5},
    },
    "地市级": {
        "行测": {"time_limit": 7200, "question_count": 130},
        "申论": {"time_limit": 10800, "question_count": 5},
    },
}

# 省考科目配置（各省差异较小，以行测+申论为主）
SHENGKAO_SUBJECTS = {
    "江苏": {
        "行测": {"time_limit": 7200, "question_count": 120},
        "申论": {"time_limit": 10800, "question_count": 5},
    },
    "浙江": {
        "行测": {"time_limit": 7200, "question_count": 120},
        "申论": {"time_limit": 10800, "question_count": 5},
    },
    "上海": {
        "行政职业能力测验": {"time_limit": 7200, "question_count": 120},
        "申论": {"time_limit": 10800, "question_count": 5},
    },
    "山东": {
        "行测": {"time_limit": 7200, "question_count": 120},
        "申论": {"time_limit": 10800, "question_count": 5},
    },
}

# 事业编科目配置
SHIYEBIAN_SUBJECTS = {
    "通用": {
        "公基": {"time_limit": 7200, "question_count": 100},
        "职业能力倾向测验": {"time_limit": 5400, "question_count": 100},
        "综合应用能力": {"time_limit": 7200, "question_count": 3},
    },
}

# ===== 输出配置 =====
OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets", "questions", "real_exam"
)

# 子目录
GUOKAO_DIR = os.path.join(OUTPUT_DIR, "guokao")
SHENGKAO_DIR = os.path.join(OUTPUT_DIR, "shengkao")
SHIYEBIAN_DIR = os.path.join(OUTPUT_DIR, "shiyebian")

# ===== 日志 =====
LOG_LEVEL = "INFO"
LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scraper.log")
