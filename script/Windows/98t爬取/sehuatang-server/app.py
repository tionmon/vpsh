#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sehuatang 磁力爬虫 — Web 控制台
Flask 应用 + 鉴权 + API + 定时任务
"""

import os
import sys
import json
import uuid
import secrets
import logging
import threading
from datetime import datetime
from functools import wraps

from flask import (
    Flask, render_template, request, redirect, url_for,
    session, jsonify, send_from_directory, abort
)
import bcrypt

from scraper import SehuatangScraper, CrawlTask, RESULTS_DIR
from scheduler import (
    init_scheduler, shutdown_scheduler,
    add_scheduled_task, remove_scheduled_task, get_scheduled_jobs
)
from tg_notify import notify_task_complete

# ──────────────────────────────── Setup ────────────────────────────────

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(BASE_DIR, "config.json")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(os.path.join(BASE_DIR, "app.log"), encoding="utf-8"),
    ],
)
logger = logging.getLogger(__name__)

app = Flask(__name__, template_folder=os.path.join(BASE_DIR, "templates"))

# ──────────────────────────── Config Helpers ───────────────────────────

def load_config():
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {
            "password_hash": "",
            "secret_key": "",
            "telegram": {"enabled": False, "bot_token": "", "default_chat_id": ""},
            "scheduled_tasks": [],
            "scraper": {"delay_min": 2, "delay_max": 4, "max_retries": 5, "headless": True},
        }


def save_config(cfg):
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)


def ensure_config():
    """确保配置文件存在且有默认密码和 secret_key"""
    cfg = load_config()
    changed = False
    if not cfg.get("secret_key"):
        cfg["secret_key"] = secrets.token_hex(32)
        changed = True
    if not cfg.get("password_hash"):
        # 默认密码 admin
        cfg["password_hash"] = bcrypt.hashpw(b"admin", bcrypt.gensalt()).decode()
        changed = True
    if changed:
        save_config(cfg)
    return cfg


# ──────────────────────────── Auth Decorator ───────────────────────────

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get("authenticated"):
            if request.is_json or request.path.startswith("/api/"):
                return jsonify({"error": "未授权"}), 401
            return redirect(url_for("login"))
        return f(*args, **kwargs)
    return decorated


# ──────────────────────────── Task Management ─────────────────────────

tasks_lock = threading.Lock()
tasks = {}  # task_id → CrawlTask


def run_crawl_in_thread(task: CrawlTask, scraper_config, tg_config=None, tg_chat_id=None):
    """在后台线程中运行爬取"""
    scraper = SehuatangScraper(config=scraper_config)
    scraper.run(task)

    # TG 通知
    if tg_config and tg_config.get("enabled") and task.result_file:
        chat_id = tg_chat_id or tg_config.get("default_chat_id", "")
        bot_token = tg_config.get("bot_token", "")
        if bot_token and chat_id:
            stats = task.to_dict()["stats"]
            task_name = f"forum-{task.forum_id} p{task.start_page}-{task.end_page}"
            try:
                notify_task_complete(bot_token, chat_id, task_name, task.result_file, stats)
                task.log("📨 TG 通知已发送")
            except Exception as e:
                task.log(f"⚠️ TG 通知失败: {e}", "warning")


def run_scheduled_crawl(task_config):
    """定时任务回调"""
    logger.info(f"⏰ 定时任务触发: {task_config.get('name', 'unknown')}")
    cfg = load_config()

    from scraper import parse_forum_url
    task_id = f"sched_{uuid.uuid4().hex[:8]}"
    task = CrawlTask(
        task_id=task_id,
        forum_url=task_config["forum_url"],
        start_page=task_config.get("start_page", 1),
        end_page=task_config.get("end_page", 1),
    )
    with tasks_lock:
        tasks[task_id] = task

    tg_chat_id = task_config.get("tg_chat_id", "")
    run_crawl_in_thread(task, cfg.get("scraper", {}), cfg.get("telegram"), tg_chat_id)


# ──────────────────────────────── Routes ──────────────────────────────

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        return render_template("login.html")

    password = request.form.get("password", "")
    cfg = load_config()
    stored_hash = cfg.get("password_hash", "").encode()

    if bcrypt.checkpw(password.encode(), stored_hash):
        session["authenticated"] = True
        return redirect(url_for("index"))
    else:
        return render_template("login.html", error="密码错误")


@app.route("/logout")
def logout():
    session.pop("authenticated", None)
    return redirect(url_for("login"))


@app.route("/")
@login_required
def index():
    return render_template("index.html")


# ──────── API: Crawl ────────

@app.route("/api/crawl", methods=["POST"])
@login_required
def api_start_crawl():
    data = request.get_json()
    forum_url = data.get("forum_url", "").strip()
    start_page = int(data.get("start_page", 1))
    end_page = int(data.get("end_page", 1))
    tg_chat_id = data.get("tg_chat_id", "")

    if not forum_url:
        return jsonify({"error": "缺少 forum_url"}), 400

    task_id = f"manual_{uuid.uuid4().hex[:8]}"
    task = CrawlTask(task_id, forum_url, start_page, end_page)

    with tasks_lock:
        tasks[task_id] = task

    cfg = load_config()
    thread = threading.Thread(
        target=run_crawl_in_thread,
        args=(task, cfg.get("scraper", {}), cfg.get("telegram"), tg_chat_id),
        daemon=True,
    )
    thread.start()

    return jsonify({"task_id": task_id, "message": "任务已创建"})


@app.route("/api/crawl/<task_id>/stop", methods=["POST"])
@login_required
def api_stop_crawl(task_id):
    with tasks_lock:
        task = tasks.get(task_id)
    if not task:
        return jsonify({"error": "任务不存在"}), 404
    task.should_stop = True
    return jsonify({"message": "停止信号已发送"})


@app.route("/api/status")
@login_required
def api_status():
    """获取所有任务状态"""
    with tasks_lock:
        result = {tid: t.to_dict() for tid, t in tasks.items()}
    return jsonify(result)


@app.route("/api/status/<task_id>")
@login_required
def api_task_status(task_id):
    with tasks_lock:
        task = tasks.get(task_id)
    if not task:
        return jsonify({"error": "任务不存在"}), 404
    return jsonify(task.to_dict())


# ──────── API: Results ────────

@app.route("/api/results")
@login_required
def api_results():
    files = []
    if os.path.isdir(RESULTS_DIR):
        for f in sorted(os.listdir(RESULTS_DIR), reverse=True):
            fp = os.path.join(RESULTS_DIR, f)
            if os.path.isfile(fp):
                stat = os.stat(fp)
                files.append({
                    "name": f,
                    "size": stat.st_size,
                    "modified": datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
                })
    return jsonify(files)


@app.route("/api/download/<filename>")
@login_required
def api_download(filename):
    # 安全检查
    if ".." in filename or "/" in filename or "\\" in filename:
        abort(400)
    return send_from_directory(RESULTS_DIR, filename, as_attachment=True)


@app.route("/api/results/<filename>", methods=["DELETE"])
@login_required
def api_delete_result(filename):
    if ".." in filename or "/" in filename or "\\" in filename:
        abort(400)
    fp = os.path.join(RESULTS_DIR, filename)
    if os.path.isfile(fp):
        os.remove(fp)
        return jsonify({"message": f"已删除 {filename}"})
    return jsonify({"error": "文件不存在"}), 404


# ──────── API: Config ────────

@app.route("/api/config", methods=["GET"])
@login_required
def api_get_config():
    cfg = load_config()
    # 不返回敏感字段的完整值
    safe = {
        "telegram": {
            "enabled": cfg.get("telegram", {}).get("enabled", False),
            "bot_token": "***" if cfg.get("telegram", {}).get("bot_token") else "",
            "default_chat_id": cfg.get("telegram", {}).get("default_chat_id", ""),
        },
        "scraper": cfg.get("scraper", {}),
        "scheduled_tasks": cfg.get("scheduled_tasks", []),
    }
    return jsonify(safe)


@app.route("/api/config", methods=["POST"])
@login_required
def api_update_config():
    data = request.get_json()
    cfg = load_config()

    # 更新 scraper 配置
    if "scraper" in data:
        cfg["scraper"].update(data["scraper"])

    # 更新 TG 配置
    if "telegram" in data:
        tg = data["telegram"]
        if "enabled" in tg:
            cfg["telegram"]["enabled"] = tg["enabled"]
        if "bot_token" in tg and tg["bot_token"] != "***":
            cfg["telegram"]["bot_token"] = tg["bot_token"]
        if "default_chat_id" in tg:
            cfg["telegram"]["default_chat_id"] = tg["default_chat_id"]

    save_config(cfg)
    return jsonify({"message": "配置已保存"})


@app.route("/api/password", methods=["POST"])
@login_required
def api_change_password():
    data = request.get_json()
    new_password = data.get("password", "").strip()
    if not new_password or len(new_password) < 3:
        return jsonify({"error": "密码不能少于 3 个字符"}), 400
    cfg = load_config()
    cfg["password_hash"] = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()
    save_config(cfg)
    return jsonify({"message": "密码已更新"})


# ──────── API: Scheduled Tasks ────────

@app.route("/api/schedule", methods=["GET"])
@login_required
def api_get_schedules():
    cfg = load_config()
    scheduler_jobs = get_scheduled_jobs()
    return jsonify({
        "tasks": cfg.get("scheduled_tasks", []),
        "jobs": scheduler_jobs,
    })


@app.route("/api/schedule", methods=["POST"])
@login_required
def api_add_schedule():
    data = request.get_json()
    cfg = load_config()

    task_entry = {
        "id": data.get("id", f"sched_{uuid.uuid4().hex[:6]}"),
        "name": data.get("name", "未命名任务"),
        "forum_url": data.get("forum_url", ""),
        "start_page": int(data.get("start_page", 1)),
        "end_page": int(data.get("end_page", 1)),
        "cron": data.get("cron", ""),
        "tg_chat_id": data.get("tg_chat_id", ""),
    }

    if not task_entry["forum_url"] or not task_entry["cron"]:
        return jsonify({"error": "缺少 forum_url 或 cron 表达式"}), 400

    # 保存到配置
    existing = cfg.get("scheduled_tasks", [])
    # 更新或新增
    found = False
    for i, t in enumerate(existing):
        if t.get("id") == task_entry["id"]:
            existing[i] = task_entry
            found = True
            break
    if not found:
        existing.append(task_entry)
    cfg["scheduled_tasks"] = existing
    save_config(cfg)

    # 注册到调度器
    ok = add_scheduled_task(task_entry, run_scheduled_crawl)
    if ok:
        return jsonify({"message": f"定时任务已添加: {task_entry['name']}", "task": task_entry})
    else:
        return jsonify({"error": "Cron 表达式无效"}), 400


@app.route("/api/schedule/<task_id>", methods=["DELETE"])
@login_required
def api_delete_schedule(task_id):
    cfg = load_config()
    existing = cfg.get("scheduled_tasks", [])
    cfg["scheduled_tasks"] = [t for t in existing if t.get("id") != task_id]
    save_config(cfg)
    remove_scheduled_task(task_id)
    return jsonify({"message": f"定时任务已删除: {task_id}"})


# ──────────────────────────────── Main ────────────────────────────────

def main():
    cfg = ensure_config()
    app.secret_key = cfg["secret_key"]

    # 启动定时调度器
    init_scheduler()

    # 恢复已有定时任务
    for task_config in cfg.get("scheduled_tasks", []):
        add_scheduled_task(task_config, run_scheduled_crawl)

    logger.info("🚀 Sehuatang 磁力爬虫服务启动 → http://0.0.0.0:9898")
    try:
        app.run(host="0.0.0.0", port=9898, debug=False, threaded=True)
    finally:
        shutdown_scheduler()


if __name__ == "__main__":
    main()
