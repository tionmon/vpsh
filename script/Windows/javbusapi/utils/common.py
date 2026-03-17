"""
Common utilities for handlers
"""
from telegram import Update
from telegram.ext import ContextTypes
import config


def check_api_configured(func):
    """Decorator to check if API URL is configured."""
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        chat_id = update.effective_chat.id
        if not config.has_api_url(chat_id):
            await update.message.reply_text(
                "❌ 请先设置 API 地址\n\n使用 `/setapi https://your-api-url.com`",
                parse_mode="Markdown"
            )
            return
        return await func(update, context)
    return wrapper
