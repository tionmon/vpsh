"""
Star/actress detail handler
Commands: /star
"""
from telegram import Update
from telegram.ext import ContextTypes
import config
from api_client import JavBusAPIClient
from utils.formatters import format_star
from utils.keyboards import build_star_actions_keyboard
from utils.common import check_api_configured


@check_api_configured
async def star_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle /star command - Get star/actress details.
    
    Usage:
        /star 2xi - Get star info
        /star 2jd uncensored - Get uncensored star info
    """
    chat_id = update.effective_chat.id
    api_url = config.get_api_url(chat_id)
    client = JavBusAPIClient(api_url)
    
    args = context.args or []
    if not args:
        await update.message.reply_text(
            "❌ 请提供演员 ID\n\n使用方法:\n`/star <演员ID>`\n例: `/star 2xi`",
            parse_mode="Markdown"
        )
        return
    
    star_id = args[0]
    star_type = "normal"
    
    if len(args) > 1 and args[1].lower() == "uncensored":
        star_type = "uncensored"
    
    # Send typing action
    await update.message.chat.send_action("typing")
    
    # Fetch star detail
    result = await client.get_star(star_id, star_type)
    
    if not result:
        await update.message.reply_text(f"❌ 获取演员信息失败: 请求失败")
        return
    
    if "error" in result:
        await update.message.reply_text(f"❌ 获取演员信息失败: {result['error']}")
        return
    
    # Format message
    message = format_star(result)
    
    # Send with avatar if available
    avatar_url = result.get("avatar")
    if avatar_url:
        try:
            await update.message.reply_photo(
                photo=avatar_url,
                caption=message,
                parse_mode="Markdown",
                reply_markup=build_star_actions_keyboard(star_id)
            )
            return
        except Exception:
            pass  # Fall back to text message
    
    await update.message.reply_text(
        message,
        parse_mode="Markdown",
        reply_markup=build_star_actions_keyboard(star_id)
    )
