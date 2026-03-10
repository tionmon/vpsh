#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Telegram 通知模块
支持发送文本消息和文件到指定 chat_id / 频道
"""

import asyncio
import logging
import os

logger = logging.getLogger(__name__)


async def _send_document_async(bot_token, chat_id, file_path, caption=""):
    """异步发送文件到 Telegram"""
    from telegram import Bot
    bot = Bot(token=bot_token)
    with open(file_path, 'rb') as f:
        await bot.send_document(
            chat_id=chat_id,
            document=f,
            filename=os.path.basename(file_path),
            caption=caption[:1024] if caption else None,
            read_timeout=60,
            write_timeout=60
        )


async def _send_message_async(bot_token, chat_id, text):
    """异步发送文本消息到 Telegram"""
    from telegram import Bot
    bot = Bot(token=bot_token)
    # Telegram 消息最长 4096 字符
    for i in range(0, len(text), 4096):
        await bot.send_message(
            chat_id=chat_id,
            text=text[i:i + 4096],
            read_timeout=30,
            write_timeout=30
        )


def send_document(bot_token, chat_id, file_path, caption=""):
    """
    发送文件到 Telegram（同步包装）

    Args:
        bot_token: Telegram Bot Token
        chat_id: 目标 Chat ID 或频道 ID（如 @channel_name 或 -100xxxxx）
        file_path: 要发送的文件路径
        caption: 文件说明文字
    """
    if not bot_token or not chat_id:
        logger.warning("TG 未配置 bot_token 或 chat_id，跳过发送")
        return False

    if not os.path.exists(file_path):
        logger.error(f"文件不存在: {file_path}")
        return False

    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(_send_document_async(bot_token, chat_id, file_path, caption))
        loop.close()
        logger.info(f"✅ TG 文件发送成功 → {chat_id}: {os.path.basename(file_path)}")
        return True
    except Exception as e:
        logger.error(f"❌ TG 文件发送失败: {e}")
        return False


def send_message(bot_token, chat_id, text):
    """
    发送文本消息到 Telegram（同步包装）
    """
    if not bot_token or not chat_id:
        return False
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(_send_message_async(bot_token, chat_id, text))
        loop.close()
        logger.info(f"✅ TG 消息发送成功 → {chat_id}")
        return True
    except Exception as e:
        logger.error(f"❌ TG 消息发送失败: {e}")
        return False


def notify_task_complete(bot_token, chat_id, task_name, result_file, stats):
    """
    任务完成后发送通知 + 文件

    Args:
        bot_token: Bot Token
        chat_id: 目标 Chat ID
        task_name: 任务名称
        result_file: 结果文件路径
        stats: dict with keys: threads, magnets, ed2k, total
    """
    caption = (
        f"📊 爬取任务完成: {task_name}\n"
        f"━━━━━━━━━━━━━━━\n"
        f"📋 帖子数: {stats.get('threads', 0)}\n"
        f"🧲 磁力链: {stats.get('magnets', 0)}\n"
        f"📦 ED2K: {stats.get('ed2k', 0)}\n"
        f"🔗 总链接: {stats.get('total', 0)}"
    )
    return send_document(bot_token, chat_id, result_file, caption)
