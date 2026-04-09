#!/usr/bin/env python3
"""
公告抓取 Python 脚本
与 Dart CLI (bin/crawler_tool.dart) 功能对等的轻量 Python 实现。
读取 tool/crawl_sites.json 站点配置，使用 requests + BeautifulSoup 抓取，
使用 sqlite3 标准库操作同一个 SQLite 数据库。

环境变量:
  LLM_API_KEY   — LLM API Key（抓取时必须）
  LLM_BASE_URL  — LLM API Base URL（抓取时必须）
  LLM_MODEL     — 模型名（可选，默认 gpt-4o-mini）

用法:
  python tool/crawl.py --list
  python tool/crawl.py --all
  python tool/crawl.py --province 江苏,浙江
  python tool/crawl.py --show [--province 江苏]
  python tool/crawl.py --stats
  python tool/crawl.py --export json|csv [--province 江苏]
"""

import argparse
import csv
import io
import json
import os
import re
import sqlite3
import sys
import time
from datetime import datetime
from pathlib import Path
from urllib.parse import urljoin, urlparse

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    print("缺少依赖，请先安装: pip install -r tool/requirements.txt")
    sys.exit(1)


# ===== 配置 =====

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ExamPrepApp/1.0",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
}

KEYWORDS = ["公告", "招聘", "引进", "人才", "事业单位", "事业编", "选调", "招录"]

REQUEST_INTERVAL = 2  # 请求间隔秒数（宪法要求 ≥2s）


# ===== 站点配置 =====

def load_sites(json_path: str) -> list[dict]:
    """从 JSON 文件加载站点配置"""
    with open(json_path, "r", encoding="utf-8") as f:
        return json.load(f)


def find_sites_json() -> str | None:
    """查找 crawl_sites.json 文件"""
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent

    candidates = [
        script_dir / "crawl_sites.json",
        project_dir / "tool" / "crawl_sites.json",
        project_dir / "assets" / "config" / "crawl_sites.json",
    ]
    for path in candidates:
        if path.exists():
            return str(path)
    return None


# ===== 数据库 =====

def detect_db_path(specified: str | None = None) -> str:
    """自动检测或使用指定的数据库路径"""
    if specified:
        return specified

    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA", "")
        if appdata:
            candidates = [
                os.path.join(appdata, "com.example", "exam_prep_app", "databases", "exam_prep.db"),
                os.path.join(os.path.dirname(appdata), "exam_prep_app", "databases", "exam_prep.db"),
                os.path.join(os.getcwd(), "exam_prep.db"),
            ]
            for path in candidates:
                if os.path.exists(path):
                    return path
    else:
        home = os.environ.get("HOME", "")
        if home:
            candidates = [
                os.path.join(home, ".local", "share", "exam_prep_app", "exam_prep.db"),
                os.path.join(os.getcwd(), "exam_prep.db"),
            ]
            for path in candidates:
                if os.path.exists(path):
                    return path

    return os.path.join(os.getcwd(), "exam_prep.db")


def ensure_tables(conn: sqlite3.Connection):
    """确保数据库表存在"""
    conn.execute("""
        CREATE TABLE IF NOT EXISTS talent_policies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            province TEXT,
            city TEXT,
            policy_type TEXT,
            content TEXT,
            source_url TEXT,
            deadline TEXT,
            created_at TEXT,
            updated_at TEXT
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS crawl_sources (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            province TEXT,
            city TEXT,
            base_url TEXT,
            list_path TEXT,
            policy_type TEXT,
            status TEXT DEFAULT 'pending',
            enabled INTEGER DEFAULT 1,
            last_crawled_at TEXT,
            created_at TEXT,
            updated_at TEXT
        )
    """)
    conn.commit()


# ===== HTTP =====

def fetch_page(url: str) -> str:
    """获取页面 HTML"""
    try:
        resp = requests.get(url, headers=HEADERS, timeout=30, allow_redirects=True)
        resp.encoding = resp.apparent_encoding or "utf-8"
        return resp.text
    except Exception as e:
        print(f"  页面获取失败 {url}: {e}")
        return ""


# ===== 链接提取 =====

def normalize_url(href: str, base_url: str) -> str | None:
    """URL 规范化：处理相对路径"""
    if not href:
        return None
    if href.startswith(("javascript:", "#", "mailto:")):
        return None
    if href.startswith(("http://", "https://")):
        return href
    if href.startswith("//"):
        return f"http:{href}"

    base = base_url.rstrip("/")
    if href.startswith("/"):
        parsed = urlparse(base)
        return f"{parsed.scheme}://{parsed.netloc}{href}"

    return f"{base}/{href}"


def extract_announcement_links(html: str, base_url: str) -> list[dict]:
    """启发式提取公告链接（关键词匹配 <a> 标签）"""
    soup = BeautifulSoup(html, "html.parser")
    links = []
    seen = set()

    for a in soup.find_all("a", href=True):
        href = a.get("href", "")
        text = a.get_text(strip=True)

        if not href or not text:
            continue
        if len(text) < 4 or len(text) > 200:
            continue

        has_keyword = any(kw in text for kw in KEYWORDS)
        if not has_keyword:
            continue

        full_url = normalize_url(href, base_url)
        if not full_url:
            continue

        if full_url in seen:
            continue
        seen.add(full_url)

        links.append({"url": full_url, "title": text})

    return links


# ===== LLM =====

def call_llm(prompt: str, api_key: str, base_url: str, model: str) -> str:
    """通过 OpenAI 兼容 API 调用 LLM"""
    url = f"{base_url}/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    data = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,
    }
    resp = requests.post(url, headers=headers, json=data, timeout=60)
    resp.raise_for_status()
    result = resp.json()
    return result["choices"][0]["message"]["content"]


def ai_extract_links(html: str, base_url: str, api_key: str, llm_base_url: str, model: str) -> list[dict]:
    """AI 回退：分析页面结构提取公告链接"""
    try:
        soup = BeautifulSoup(html, "html.parser")
        for tag in soup.find_all(["script", "style"]):
            tag.decompose()
        clean_html = str(soup.body) if soup.body else ""
        truncated = clean_html[:4000]

        prompt = (
            "从以下政府网站HTML片段中，提取所有与人才引进、事业单位招聘、公开招录相关的公告链接。\n"
            "以 JSON 数组格式返回，每项包含 url 和 title 字段。\n"
            "只返回 JSON 数组，不要其他文字。\n"
            "如果没有找到相关链接，返回空数组 []。\n\n"
            f"基础 URL: {base_url}\n\n"
            f"HTML 片段:\n{truncated}"
        )

        result = call_llm(prompt, api_key, llm_base_url, model)

        # 提取 JSON 数组
        start = result.find("[")
        end = result.rfind("]") + 1
        if start < 0 or end <= start:
            return []

        items = json.loads(result[start:end])
        links = []
        for item in items:
            url = normalize_url(item.get("url", ""), base_url)
            if url:
                links.append({"url": url, "title": item.get("title", "")})
        return links
    except Exception as e:
        print(f"  AI 提取链接失败: {e}")
        return []


# ===== 公告处理 =====

def process_announcement_link(
    url: str,
    link_title: str,
    site: dict,
    conn: sqlite3.Connection,
    api_key: str,
    llm_base_url: str,
    model: str,
) -> dict | None:
    """处理单个公告链接"""
    # 去重检查（按 URL）
    cursor = conn.execute("SELECT id FROM talent_policies WHERE source_url = ?", (url,))
    if cursor.fetchone():
        return None

    # 获取详情页
    detail_html = fetch_page(url)
    if not detail_html:
        return None

    # 提取正文
    soup = BeautifulSoup(detail_html, "html.parser")
    for tag in soup.find_all(["script", "style", "nav", "header", "footer"]):
        tag.decompose()
    body_text = re.sub(r"\s+", " ", soup.get_text(strip=True))

    if len(body_text) < 50:
        return None

    truncated = body_text[:3000]

    # AI 解析公告基本信息
    title = link_title if link_title else "抓取的公告"
    province = site.get("province")
    city = site.get("city")
    policy_type = "事业编招聘" if site.get("policy_type") == "shiyebian" else "人才引进"
    deadline = None

    try:
        info_prompt = (
            "从以下政府公告网页内容中提取基本信息，以 JSON 格式返回：\n"
            "{\n"
            '  "title": "公告标题（完整标题）",\n'
            '  "province": "省份",\n'
            '  "city": "城市",\n'
            '  "policy_type": "公告类型（人才引进/事业编招聘/选调生/其他）",\n'
            '  "deadline": "报名截止日期（如有，格式YYYY-MM-DD）"\n'
            "}\n"
            "只返回 JSON，不要其他文字。\n\n"
            f"网页内容：\n{truncated}"
        )

        info_result = call_llm(info_prompt, api_key, llm_base_url, model)
        start = info_result.find("{")
        end = info_result.rfind("}") + 1
        if start >= 0 and end > start:
            info = json.loads(info_result[start:end])
            title = info.get("title", title)
            province = info.get("province", province)
            city = info.get("city", city)
            policy_type = info.get("policy_type", policy_type)
            deadline = info.get("deadline")
    except Exception as e:
        print(f"  AI 解析公告基本信息失败: {e}")

    # 去重检查（按 title+province+city）
    cursor = conn.execute(
        "SELECT id FROM talent_policies WHERE title = ? AND province = ? AND city = ?",
        (title, province or "", city or ""),
    )
    if cursor.fetchone():
        return None

    # 入库
    now = datetime.now().isoformat()
    conn.execute(
        """INSERT INTO talent_policies
           (title, province, city, policy_type, content, source_url, deadline, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (title, province, city, policy_type, truncated, url, deadline, now, now),
    )
    conn.commit()

    print(f"  新增公告: {title}")
    return {"policies": 1, "positions": 0}


# ===== 抓取逻辑 =====

def crawl_sites(
    sites: list[dict],
    conn: sqlite3.Connection,
    api_key: str,
    llm_base_url: str,
    model: str,
) -> dict:
    """抓取一组站点"""
    success = 0
    failed = 0
    new_policies = 0
    new_positions = 0
    errors = []

    for i, site in enumerate(sites):
        base_url = site["base_url"].rstrip("/")
        list_path = site["list_path"]
        if not list_path.startswith("/"):
            list_path = f"/{list_path}"
        list_url = f"{base_url}{list_path}"

        city_str = f' {site.get("city", "")}' if site.get("city") else ""
        print(f'[{i + 1}/{len(sites)}] 正在抓取: {site["province"]}{city_str} - {site["name"]}')

        try:
            html = fetch_page(list_url)
            if not html:
                raise Exception("列表页内容为空")

            links = extract_announcement_links(html, base_url)
            if not links:
                links = ai_extract_links(html, base_url, api_key, llm_base_url, model)

            if not links:
                print(f'  {site["name"]}: 未找到公告链接')
            else:
                print(f"  找到 {len(links)} 条公告链接")
                for link in links[:10]:
                    result = process_announcement_link(
                        link["url"], link.get("title", ""), site, conn, api_key, llm_base_url, model
                    )
                    if result:
                        new_policies += result["policies"]
                        new_positions += result["positions"]
                    time.sleep(REQUEST_INTERVAL)

            success += 1
            _update_source_status(conn, site, "success")

        except Exception as e:
            failed += 1
            error_msg = f'{site["name"]}: {e}'
            errors.append(error_msg)
            print(f"  抓取失败 - {error_msg}")
            _update_source_status(conn, site, "failed")

        if i < len(sites) - 1:
            time.sleep(REQUEST_INTERVAL)

    summary = f"抓取完成 - 成功 {success}/{len(sites)} 站点, 新增 {new_policies} 条公告, {new_positions} 个岗位"
    print(f"\n{summary}")

    return {
        "total_sources": len(sites),
        "success_sources": success,
        "failed_sources": failed,
        "new_policies": new_policies,
        "new_positions": new_positions,
        "errors": errors,
    }


def _update_source_status(conn: sqlite3.Connection, site: dict, status: str):
    """更新站点抓取状态"""
    try:
        now = datetime.now().isoformat()
        conn.execute(
            "UPDATE crawl_sources SET status = ?, last_crawled_at = ? WHERE base_url = ? AND list_path = ?",
            (status, now, site["base_url"], site["list_path"]),
        )
        conn.commit()
    except Exception as e:
        print(f"  更新站点状态失败: {e}")


# ===== 查看/统计/导出 =====

def query_policies(conn: sqlite3.Connection, province: str | None = None) -> list[dict]:
    """查询公告"""
    if province:
        cursor = conn.execute(
            "SELECT * FROM talent_policies WHERE province = ? ORDER BY created_at DESC", (province,)
        )
    else:
        cursor = conn.execute("SELECT * FROM talent_policies ORDER BY created_at DESC")
    columns = [desc[0] for desc in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def get_stats(conn: sqlite3.Connection) -> dict:
    """统计概览"""
    total = conn.execute("SELECT COUNT(*) FROM talent_policies").fetchone()[0]
    by_province = conn.execute(
        "SELECT province, COUNT(*) as cnt FROM talent_policies GROUP BY province ORDER BY cnt DESC"
    ).fetchall()
    by_type = conn.execute(
        "SELECT policy_type, COUNT(*) as cnt FROM talent_policies GROUP BY policy_type ORDER BY cnt DESC"
    ).fetchall()
    sources_total = conn.execute("SELECT COUNT(*) FROM crawl_sources").fetchone()[0]
    sources_success = conn.execute("SELECT COUNT(*) FROM crawl_sources WHERE status = 'success'").fetchone()[0]

    return {
        "total_policies": total,
        "by_province": by_province,
        "by_type": by_type,
        "total_sources": sources_total,
        "success_sources": sources_success,
    }


def export_json(conn: sqlite3.Connection, province: str | None = None) -> str:
    """导出 JSON"""
    policies = query_policies(conn, province)
    return json.dumps(policies, ensure_ascii=False, indent=2)


def export_csv_str(conn: sqlite3.Connection, province: str | None = None) -> str:
    """导出 CSV"""
    policies = query_policies(conn, province)
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "title", "province", "city", "policy_type", "source_url", "deadline", "created_at"])
    for p in policies:
        writer.writerow([
            p.get("id", ""),
            p.get("title", ""),
            p.get("province", ""),
            p.get("city", ""),
            p.get("policy_type", ""),
            p.get("source_url", ""),
            p.get("deadline", ""),
            p.get("created_at", ""),
        ])
    return output.getvalue()


# ===== 主入口 =====

def main():
    parser = argparse.ArgumentParser(description="公告抓取 Python 工具")
    parser.add_argument("-a", "--all", action="store_true", help="抓取全部五省站点")
    parser.add_argument("-p", "--province", type=str, help="指定省份抓取（逗号分隔）")
    parser.add_argument("-l", "--list", action="store_true", help="列出所有站点配置")
    parser.add_argument("-s", "--show", action="store_true", help="查看已抓取的公告")
    parser.add_argument("--stats", action="store_true", help="统计概览")
    parser.add_argument("-e", "--export", choices=["json", "csv"], help="导出数据")
    parser.add_argument("--db-path", type=str, help="数据库文件路径")

    args = parser.parse_args()

    # 查找站点配置
    sites_json_path = find_sites_json()
    if not sites_json_path:
        print("错误: 找不到 crawl_sites.json 配置文件")
        sys.exit(1)

    sites = load_sites(sites_json_path)

    # --list: 列出站点
    if args.list:
        grouped: dict[str, list] = {}
        for site in sites:
            grouped.setdefault(site["province"], []).append(site)

        print(f"共 {len(sites)} 个站点:\n")
        for province, province_sites in grouped.items():
            print(f"=== {province}（{len(province_sites)}个站点） ===")
            for site in province_sites:
                city = f' ({site["city"]})' if site.get("city") else ""
                print(f'  {site["name"]}{city}')
                print(f'    {site["base_url"]}{site["list_path"]}')
                print(f'    类型: {site["policy_type"]}')
            print()
        return

    # 以下命令需要数据库
    db_path = detect_db_path(args.db_path)
    print(f"数据库路径: {db_path}")

    if not os.path.exists(db_path):
        print(f"警告: 数据库文件不存在，将创建新数据库: {db_path}")

    conn = sqlite3.connect(db_path)
    ensure_tables(conn)

    try:
        if args.all or args.province:
            # 检查环境变量
            api_key = os.environ.get("LLM_API_KEY", "")
            llm_base_url = os.environ.get("LLM_BASE_URL", "")
            model = os.environ.get("LLM_MODEL", "gpt-4o-mini")

            if not api_key or not llm_base_url:
                print("错误: 抓取功能需要设置环境变量:")
                print("  LLM_API_KEY  — LLM API Key")
                print("  LLM_BASE_URL — LLM API Base URL")
                print("  LLM_MODEL    — 模型名（可选，默认 gpt-4o-mini）")
                sys.exit(1)

            if args.all:
                print(f"开始抓取全部 {len(sites)} 个站点...\n")
                report = crawl_sites(sites, conn, api_key, llm_base_url, model)
                _print_report(report)
            else:
                provinces = [p.strip() for p in args.province.split(",")]
                for province in provinces:
                    province_sites = [s for s in sites if s["province"] == province]
                    if not province_sites:
                        print(f"未找到省份 '{province}' 的站点配置")
                        continue
                    print(f"开始抓取: {province}\n")
                    report = crawl_sites(province_sites, conn, api_key, llm_base_url, model)
                    _print_report(report)
                    print()

        elif args.show:
            policies = query_policies(conn, args.province)
            if not policies:
                print("暂无公告数据")
            else:
                print(f"共 {len(policies)} 条公告:\n")
                for p in policies:
                    print(f'  [{p["id"]}] {p["title"]}')
                    print(f'      省份: {p.get("province", "-")}  城市: {p.get("city", "-")}  类型: {p.get("policy_type", "-")}')
                    if p.get("source_url"):
                        print(f'      链接: {p["source_url"]}')
                    print(f'      时间: {p.get("created_at", "-")}')
                    print()

        elif args.stats:
            stats = get_stats(conn)
            print("=== 抓取统计 ===")
            print(f'公告总数: {stats["total_policies"]}')
            print(f'站点总数: {stats["total_sources"]}（成功: {stats["success_sources"]}）')
            print("\n按省份分布:")
            for row in stats["by_province"]:
                print(f"  {row[0]}: {row[1]} 条")
            print("\n按类型分布:")
            for row in stats["by_type"]:
                print(f"  {row[0] or '未知'}: {row[1]} 条")

        elif args.export:
            if args.export == "json":
                data = export_json(conn, args.province)
                filename = f"policies_export_{int(time.time() * 1000)}.json"
                with open(filename, "w", encoding="utf-8") as f:
                    f.write(data)
                print(f"已导出到: {filename}")
            else:
                data = export_csv_str(conn, args.province)
                filename = f"policies_export_{int(time.time() * 1000)}.csv"
                with open(filename, "w", encoding="utf-8", newline="") as f:
                    f.write(data)
                print(f"已导出到: {filename}")

        else:
            parser.print_help()

    finally:
        conn.close()


def _print_report(report: dict):
    """打印抓取报告"""
    print("\n=== 抓取报告 ===")
    print(f'站点总数: {report["total_sources"]}')
    print(f'成功: {report["success_sources"]}')
    print(f'失败: {report["failed_sources"]}')
    print(f'新增公告: {report["new_policies"]}')
    print(f'新增岗位: {report["new_positions"]}')
    if report["errors"]:
        print("\n错误列表:")
        for e in report["errors"]:
            print(f"  - {e}")


if __name__ == "__main__":
    main()
