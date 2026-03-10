#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
定时任务调度器
使用 APScheduler 管理 cron 定时爬取任务
"""

import logging
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

logger = logging.getLogger(__name__)

scheduler = BackgroundScheduler(timezone="Asia/Shanghai")


def init_scheduler():
    """启动调度器"""
    if not scheduler.running:
        scheduler.start()
        logger.info("✅ 调度器已启动")


def shutdown_scheduler():
    """关闭调度器"""
    if scheduler.running:
        scheduler.shutdown(wait=False)


def add_scheduled_task(task_config, run_func):
    """
    添加定时任务

    Args:
        task_config: {
            "id": "task_1",
            "name": "每日爬取",
            "forum_url": "https://sehuatang.net/forum-160-1.html",
            "start_page": 1,
            "end_page": 3,
            "cron": "0 8 * * *",       # cron 表达式 (分 时 日 月 星期)
            "tg_chat_id": ""            # 可选 TG 通知目标
        }
        run_func: callable(task_config) — 实际执行爬取的回调
    """
    job_id = task_config.get("id", task_config.get("name", "unknown"))
    cron_expr = task_config.get("cron", "").strip()

    if not cron_expr:
        logger.warning(f"任务 {job_id} 无 cron 表达式，跳过")
        return False

    # 解析 cron: "分 时 日 月 星期"
    parts = cron_expr.split()
    if len(parts) != 5:
        logger.error(f"无效 cron 表达式: {cron_expr} (需要 5 部分: 分 时 日 月 星期)")
        return False

    try:
        trigger = CronTrigger(
            minute=parts[0],
            hour=parts[1],
            day=parts[2],
            month=parts[3],
            day_of_week=parts[4],
            timezone="Asia/Shanghai",
        )

        # 如果已有同 ID 的任务，先移除
        if scheduler.get_job(job_id):
            scheduler.remove_job(job_id)

        scheduler.add_job(
            run_func,
            trigger=trigger,
            args=[task_config],
            id=job_id,
            name=task_config.get("name", job_id),
            replace_existing=True,
            max_instances=1,
            misfire_grace_time=300,
        )
        logger.info(f"✅ 定时任务已添加: {job_id} → {cron_expr}")
        return True
    except Exception as e:
        logger.error(f"❌ 添加定时任务失败: {e}")
        return False


def remove_scheduled_task(job_id):
    """移除定时任务"""
    try:
        if scheduler.get_job(job_id):
            scheduler.remove_job(job_id)
            logger.info(f"✅ 定时任务已移除: {job_id}")
            return True
        return False
    except Exception as e:
        logger.error(f"❌ 移除定时任务失败: {e}")
        return False


def get_scheduled_jobs():
    """获取所有定时任务信息"""
    jobs = []
    for job in scheduler.get_jobs():
        next_run = job.next_run_time.strftime("%Y-%m-%d %H:%M:%S") if job.next_run_time else "N/A"
        jobs.append({
            "id": job.id,
            "name": job.name,
            "next_run": next_run,
        })
    return jobs
