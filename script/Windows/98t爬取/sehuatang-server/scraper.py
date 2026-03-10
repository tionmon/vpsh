#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sehuatang 论坛磁力链接爬虫引擎
使用 DrissionPage 控制无头 Chromium 浏览器
"""

import re
import os
import time
import json
import random
import logging
from datetime import datetime
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

BASE_URL = "https://sehuatang.net"
RESULTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
os.makedirs(RESULTS_DIR, exist_ok=True)


def parse_forum_url(url):
    """
    解析论坛 URL 提取板块 ID
    https://sehuatang.net/forum-160-1.html → forum_id=160
    """
    m = re.search(r'forum-(\d+)-\d+\.html', url)
    if m:
        return int(m.group(1))
    return None


def build_forum_page_url(forum_id, page):
    return f"{BASE_URL}/forum-{forum_id}-{page}.html"


class CrawlTask:
    """表示一个爬取任务的状态"""

    def __init__(self, task_id, forum_url, start_page, end_page):
        self.task_id = task_id
        self.forum_url = forum_url
        self.forum_id = parse_forum_url(forum_url)
        self.start_page = start_page
        self.end_page = end_page
        self.status = "pending"  # pending / running / completed / failed / stopped
        self.progress = 0  # 0-100
        self.phase = ""  # 当前阶段描述
        self.logs = []
        self.results = []  # [{ title, url, links: [] }]
        self.result_file = None
        self.created_at = datetime.now().isoformat()
        self.finished_at = None
        self.should_stop = False

    def log(self, msg, level="info"):
        ts = datetime.now().strftime("%H:%M:%S")
        entry = {"time": ts, "level": level, "msg": msg}
        self.logs.append(entry)
        # 保留最近 500 条
        if len(self.logs) > 500:
            self.logs = self.logs[-500:]
        getattr(logger, level, logger.info)(f"[Task {self.task_id}] {msg}")

    def to_dict(self):
        magnets = 0
        ed2k = 0
        for r in self.results:
            for link in r.get("links", []):
                if link.startswith("magnet"):
                    magnets += 1
                elif link.lower().startswith("ed2k"):
                    ed2k += 1
        return {
            "task_id": self.task_id,
            "forum_url": self.forum_url,
            "forum_id": self.forum_id,
            "start_page": self.start_page,
            "end_page": self.end_page,
            "status": self.status,
            "progress": self.progress,
            "phase": self.phase,
            "logs": self.logs[-50:],  # 返回最近 50 条
            "stats": {
                "threads": len(self.results),
                "magnets": magnets,
                "ed2k": ed2k,
                "total": magnets + ed2k,
            },
            "result_file": os.path.basename(self.result_file) if self.result_file else None,
            "created_at": self.created_at,
            "finished_at": self.finished_at,
        }


class SehuatangScraper:
    """爬虫引擎"""

    def __init__(self, config=None):
        self.config = config or {}
        self.page = None
        self.age_verified = False

    def _delay_range(self):
        mn = self.config.get("delay_min", 2)
        mx = self.config.get("delay_max", 4)
        return mn, mx

    def _max_retries(self):
        return self.config.get("max_retries", 5)

    def _random_delay(self):
        mn, mx = self._delay_range()
        time.sleep(random.uniform(mn, mx))

    def init_browser(self):
        """初始化无头浏览器"""
        from DrissionPage import ChromiumPage, ChromiumOptions

        options = ChromiumOptions()
        if self.config.get("headless", True):
            options.headless(True)
            options.set_user_agent(
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            )
        options.set_argument("--disable-blink-features=AutomationControlled")
        options.set_argument("--no-sandbox")
        options.set_argument("--disable-dev-shm-usage")
        options.set_argument("--disable-gpu")
        options.set_argument("--window-size=1920,1080")

        self.page = ChromiumPage(options)
        logger.info("浏览器已启动")

    def close_browser(self):
        if self.page:
            try:
                self.page.quit()
            except Exception:
                pass
            self.page = None

    def bypass_age_verification(self):
        """绕过年龄验证"""
        if self.age_verified:
            return True

        try:
            self.page.get(BASE_URL)
            time.sleep(3)
            html = self.page.html

            if "满18岁" in html or "enter-btn" in html:
                enter_btn = self.page.ele("css:.enter-btn", timeout=5)
                if enter_btn:
                    enter_btn.click()
                    time.sleep(3)
                else:
                    enter_btn = self.page.ele("text:满18岁", timeout=5)
                    if enter_btn:
                        enter_btn.click()
                        time.sleep(3)

            html = self.page.html
            if "满18岁" not in html and "enter-btn" not in html:
                self.age_verified = True
                return True
            return False
        except Exception as e:
            logger.error(f"年龄验证出错: {e}")
            return False

    def get_page(self, url, retries=0):
        """获取页面内容，带重试"""
        max_retries = self._max_retries()
        if retries >= max_retries:
            return None

        try:
            self.page.get(url)
            time.sleep(2)
            html = self.page.html

            # 年龄验证
            if "满18岁" in html or "enter-btn" in html:
                if self.bypass_age_verification():
                    return self.get_page(url, retries + 1)
                return None

            # Cloudflare
            if "Just a moment" in html or "请稍候" in html or "Checking your browser" in html:
                wait = 8 + retries * 5
                logger.warning(f"CF 验证，等待 {wait}s...")
                time.sleep(wait)
                return self.get_page(url, retries + 1)

            return html
        except Exception as e:
            wait = 3 * (2 ** retries)
            logger.warning(f"请求失败: {e}，{wait}s 后重试")
            time.sleep(wait)
            return self.get_page(url, retries + 1)

    def parse_thread_list(self, html_content):
        """解析帖子列表（Discuz 结构）"""
        threads = []
        soup = BeautifulSoup(html_content, "lxml")

        # 标准选择器
        thread_rows = soup.select("tbody[id^='normalthread_']")
        for row in thread_rows:
            try:
                title_link = row.select_one("a.s.xst") or row.select_one("a.xst")
                if not title_link:
                    continue
                title = title_link.get_text(strip=True)
                href = title_link.get("href", "")
                if href and title:
                    if not href.startswith("http"):
                        href = BASE_URL + "/" + href.lstrip("/")
                    threads.append({"title": title, "url": href})
            except Exception:
                continue

        # 备用
        if not threads:
            for link in soup.select("a.s.xst, a.xst"):
                title = link.get_text(strip=True)
                href = link.get("href", "")
                if href and title and ("thread-" in href or "viewthread" in href):
                    if not href.startswith("http"):
                        href = BASE_URL + "/" + href.lstrip("/")
                    threads.append({"title": title, "url": href})

        return threads

    def extract_links(self, html_content):
        """从帖子页面提取 magnet/ed2k 链接"""
        links = set()

        # magnet
        magnet_re = re.compile(
            r'magnet:\?xt=urn:btih:[a-zA-Z0-9]+[^\s"\'<>\])}\u3001\u3002\uff0c]*',
            re.IGNORECASE,
        )
        for m in magnet_re.findall(html_content):
            links.add(re.sub(r'[,，。、)\]}>]+$', '', m))

        # ed2k
        ed2k_re = re.compile(
            r'ed2k://\|file\|[^|]+\|\d+\|[a-fA-F0-9]+\|[^\s"\'<>]*',
            re.IGNORECASE,
        )
        for m in ed2k_re.findall(html_content):
            links.add(re.sub(r'[,，。、)\]}>]+$', '', m))

        # DOM 补充
        try:
            soup = BeautifulSoup(html_content, "lxml")
            for a in soup.select('a[href^="magnet:"], a[href^="ed2k://"]'):
                links.add(a["href"])
            for pc in soup.select('.t_f, .message, .postmessage, [id^="postmessage_"]'):
                text = pc.get_text()
                for m in magnet_re.findall(text):
                    links.add(re.sub(r'[,，。、)\]}>]+$', '', m))
                for m in ed2k_re.findall(text):
                    links.add(re.sub(r'[,，。、)\]}>]+$', '', m))
        except Exception:
            pass

        return list(links)

    def run(self, task: CrawlTask):
        """
        执行爬取任务

        Args:
            task: CrawlTask 实例（会被就地修改以更新状态）
        """
        task.status = "running"
        task.phase = "初始化浏览器"
        task.log("🚀 启动爬取任务")

        if not task.forum_id:
            task.log("❌ 无法解析论坛 URL", "error")
            task.status = "failed"
            return

        try:
            self.init_browser()
            task.log("✅ 浏览器已启动")

            # 年龄验证
            task.phase = "年龄验证"
            if not self.bypass_age_verification():
                task.log("⚠️ 年龄验证未确认，继续尝试...", "warning")

            # Phase 1: 收集帖子列表
            all_threads = []
            total_pages = task.end_page - task.start_page + 1

            task.phase = "收集帖子列表"
            task.log(f"📋 第一阶段：获取第 {task.start_page}-{task.end_page} 页帖子列表")

            for p in range(task.start_page, task.end_page + 1):
                if task.should_stop:
                    task.log("⏹ 用户停止", "warning")
                    break

                url = build_forum_page_url(task.forum_id, p)
                task.log(f"📄 获取第 {p} 页...")
                task.progress = int((p - task.start_page) / total_pages * 30)

                html = self.get_page(url)
                if html:
                    threads = self.parse_thread_list(html)
                    task.log(f"✅ 第 {p} 页 → {len(threads)} 个帖子")
                    all_threads.extend(threads)
                else:
                    task.log(f"❌ 第 {p} 页获取失败", "error")

                if p < task.end_page:
                    self._random_delay()

            if task.should_stop:
                task.status = "stopped"
                task.finished_at = datetime.now().isoformat()
                return

            # 去重
            seen = set()
            unique_threads = []
            for t in all_threads:
                if t["url"] not in seen:
                    seen.add(t["url"])
                    unique_threads.append(t)
            all_threads = unique_threads

            if not all_threads:
                task.log("❌ 未获取到任何帖子", "error")
                task.status = "failed"
                task.finished_at = datetime.now().isoformat()
                return

            task.log(f"📊 共 {len(all_threads)} 个帖子，开始提取链接...")

            # Phase 2: 提取链接
            task.phase = "提取磁力链接"
            for i, thread in enumerate(all_threads):
                if task.should_stop:
                    task.log("⏹ 用户停止", "warning")
                    break

                task.progress = 30 + int((i + 1) / len(all_threads) * 65)
                html = self.get_page(thread["url"])

                if html:
                    links = self.extract_links(html)
                    if links:
                        task.results.append({
                            "title": thread["title"],
                            "url": thread["url"],
                            "links": links,
                        })
                        task.log(
                            f"✅ [{i+1}/{len(all_threads)}] "
                            f"{thread['title'][:35]}... → {len(links)} 链接"
                        )
                    else:
                        task.log(
                            f"⬚  [{i+1}/{len(all_threads)}] "
                            f"{thread['title'][:35]}... → 无链接"
                        )
                else:
                    task.log(
                        f"❌ [{i+1}/{len(all_threads)}] "
                        f"{thread['title'][:35]}... → 获取失败",
                        "error",
                    )

                if i < len(all_threads) - 1:
                    self._random_delay()

            # 保存结果
            task.phase = "保存结果"
            task.progress = 95
            result_file = self._save_results(task)
            task.result_file = result_file

            if task.should_stop:
                task.status = "stopped"
            else:
                task.status = "completed"
            task.progress = 100
            task.finished_at = datetime.now().isoformat()

            stats = task.to_dict()["stats"]
            task.log(
                f"🎉 完成！{stats['threads']} 帖子, "
                f"{stats['magnets']} 磁力, {stats['ed2k']} ED2K"
            )

        except Exception as e:
            task.log(f"❌ 爬取异常: {e}", "error")
            task.status = "failed"
            task.finished_at = datetime.now().isoformat()
        finally:
            self.close_browser()

    def _save_results(self, task: CrawlTask):
        """保存结果到文件"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        basename = f"sht_{task.forum_id}_p{task.start_page}-{task.end_page}_{timestamp}"

        # TXT 文件（纯链接，每行一个）
        txt_path = os.path.join(RESULTS_DIR, f"{basename}.txt")
        with open(txt_path, "w", encoding="utf-8") as f:
            f.write(f"# Sehuatang 爬取结果\n")
            f.write(f"# 时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"# 板块: forum-{task.forum_id}, 页码: {task.start_page}-{task.end_page}\n")
            f.write(f"# {'=' * 50}\n\n")
            for item in task.results:
                f.write(f"# {item['title']}\n")
                # 去重：按 btih hash 去重，避免同一磁力出现多次（如带"复制代码"后缀的变体）
                seen_hashes = set()
                unique_links = []
                for link in item["links"]:
                    hash_match = re.search(r'btih:([a-fA-F0-9]+)', link)
                    key = hash_match.group(1).upper() if hash_match else link
                    if key not in seen_hashes:
                        seen_hashes.add(key)
                        unique_links.append(link)
                for link in unique_links:
                    f.write(f"{link}\n")
                f.write("\n")

        # JSON 文件
        json_path = os.path.join(RESULTS_DIR, f"{basename}.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "forum_id": task.forum_id,
                    "pages": f"{task.start_page}-{task.end_page}",
                    "timestamp": datetime.now().isoformat(),
                    "results": task.results,
                },
                f,
                ensure_ascii=False,
                indent=2,
            )

        logger.info(f"结果已保存: {txt_path}")
        return txt_path
