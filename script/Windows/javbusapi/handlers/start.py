"""
Start and configuration handlers
Commands: /start, /help, /setapi, /sleep
"""
from telegram import Update
from telegram.ext import ContextTypes
import config


async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle /start command - Welcome message."""
    welcome_text = """
🎬 *JavBus API Bot*

欢迎使用 JavBus API Telegram 机器人！

📌 *首次使用请先设置 API 地址:*
`/setapi https://your-api-url.com`

━━━━━━━━━━━━━━━

*可用命令:*

🔧 *配置*
• `/setapi <url>` - 设置 API 地址
• `/sleep <秒>` - 设置请求延迟 (0-5秒)
• `/symedia` - 管理 Symedia 推送配置

🎬 *影片浏览*
• `/movies` - 浏览影片列表
• `/movies <页码>` - 指定页码
• `/movies uncensored` - 无码影片
• `/movies star <id>` - 演员作品

🔍 *搜索*
• `/search <关键词>` - 搜索影片

📝 *详情* (或直接发送番号)
• `/movie <番号>` - 影片详情
• `/magnets <番号>` - 获取磁力链接
• `/star <id>` - 演员信息

🧲 *批量磁力*
• `/movies_magnets all 1-2` - 获取1-2页磁力
• `/search_magnets 关键词 all 1-2` - 搜索结果磁力

📤 *Symedia 推送* (命令末尾加 sa)
• `SSIS-406 sa` - 获取磁力并推送
• `/movies_magnets all 1 sa` - 批量获取并推送
• `/search_magnets 关键词 all 1 sa`

━━━━━━━━━━━━━━━
💡 *快捷方式*: 直接发送番号 (如 `SSIS-406`) 可查看详情+磁力
"""
    await update.message.reply_text(welcome_text, parse_mode="Markdown")


async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle /help command - Show help."""
    help_text = """
📖 命令帮助

配置:
• /setapi <url> - 设置API地址
• /sleep <秒> - 请求延迟 (默认1秒)
• /symedia - 管理Symedia推送

浏览:
• /movies - 浏览影片列表
• /search 关键词 - 搜索

详情:
• SSIS-406 - 直接发送番号查看
• /movie SSIS-406 - 查看详情
• /magnets SSIS-406 - 获取磁力

批量磁力:
• /movies_magnets all 1-2 - 批量获取
• /search_magnets 三上 all 1 - 搜索批量

Symedia 推送 (末尾加 sa):
• SSIS-406 sa - 获取并推送
• /movies_magnets all 1 sa - 批量推送
• /search_magnets 三上 all 1 sa

Symedia 管理:
• /symedia set <url> - 设置地址
• /symedia token <t> - 设置Token
• /symedia cid <id> - 设置文件夹
• /symedia test - 测试连接
"""
    await update.message.reply_text(help_text)


async def setapi_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle /setapi command - Set API URL."""
    if not context.args:
        current_url = config.get_api_url(update.effective_chat.id)
        if current_url:
            await update.message.reply_text(
                f"📌 当前 API 地址:\n`{current_url}`\n\n使用 `/setapi <url>` 更改",
                parse_mode="Markdown"
            )
        else:
            await update.message.reply_text(
                "❌ 未设置 API 地址\n\n使用方法:\n`/setapi https://your-api-url.com`",
                parse_mode="Markdown"
            )
        return

    url = context.args[0].strip()

    # Basic URL validation
    if not url.startswith(("http://", "https://")):
        await update.message.reply_text(
            "❌ 无效的 URL 格式\n\nURL 必须以 `http://` 或 `https://` 开头",
            parse_mode="Markdown"
        )
        return

    config.set_api_url(update.effective_chat.id, url)
    await update.message.reply_text(
        f"✅ API 地址已设置为:\n`{url}`\n\n现在可以使用 `/movies` 开始浏览",
        parse_mode="Markdown"
    )


async def sleep_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle /sleep command - Set request delay."""
    chat_id = update.effective_chat.id
    current_delay = config.get_sleep_delay(chat_id)

    if not context.args:
        await update.message.reply_text(
            f"⏱️ 当前请求延迟: `{current_delay}` 秒\n\n"
            f"使用 `/sleep <秒>` 更改 (范围: 0-5)\n"
            f"例: `/sleep 0.5`",
            parse_mode="Markdown"
        )
        return

    try:
        delay = float(context.args[0])
        config.set_sleep_delay(chat_id, delay)
        actual_delay = config.get_sleep_delay(chat_id)
        await update.message.reply_text(
            f"✅ 请求延迟已设置为: `{actual_delay}` 秒\n\n"
            f"💡 如果仍有429错误，请增大延迟值",
            parse_mode="Markdown"
        )
    except ValueError:
        await update.message.reply_text(
            "❌ 无效的数值\n\n请输入数字，例: `/sleep 0.5`",
            parse_mode="Markdown"
        )
