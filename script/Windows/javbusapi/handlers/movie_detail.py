"""
Movie detail and magnet handlers
Commands: /movie, /magnets
"""
from collections import OrderedDict
from telegram import Update
from telegram.ext import ContextTypes
import config
from api_client import JavBusAPIClient
from utils.formatters import format_movie_detail, format_magnets
from utils.keyboards import build_movie_actions_keyboard
from utils.common import check_api_configured

# Store movie details for magnet lookup (gid, uc)
# Format: {chat_id: OrderedDict{movie_id: {"gid": str, "uc": str}}}
# Limited to MAX_CACHE_PER_USER entries per user
MAX_CACHE_PER_USER = 100
movie_cache: dict[int, OrderedDict] = {}


def _cache_movie(chat_id: int, movie_id: str, gid: str, uc: str) -> None:
    """Cache movie gid/uc with LRU eviction."""
    if chat_id not in movie_cache:
        movie_cache[chat_id] = OrderedDict()

    cache = movie_cache[chat_id]
    # Move to end if exists
    if movie_id in cache:
        cache.move_to_end(movie_id)
    cache[movie_id] = {"gid": gid, "uc": uc}

    # Evict oldest if over limit
    while len(cache) > MAX_CACHE_PER_USER:
        cache.popitem(last=False)


@check_api_configured
async def movie_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle /movie command - Get movie details.

    Usage:
        /movie SSIS-406
    """
    chat_id = update.effective_chat.id
    api_url = config.get_api_url(chat_id)
    client = JavBusAPIClient(api_url)

    args = context.args or []
    if not args:
        await update.message.reply_text(
            "❌ 请提供番号\n\n使用方法:\n`/movie <番号>`\n例: `/movie SSIS-406`",
            parse_mode="Markdown"
        )
        return

    movie_id = args[0].upper()

    # Send typing action
    await update.message.chat.send_action("typing")

    # Fetch movie detail
    result = await client.get_movie_detail(movie_id)

    if not result:
        await update.message.reply_text(f"❌ 获取影片详情失败: 请求失败")
        return

    if "error" in result:
        await update.message.reply_text(f"❌ 获取影片详情失败: {result['error']}")
        return

    # Cache gid and uc for magnet lookup
    gid = result.get("gid", "")
    uc = result.get("uc", "")
    if gid:
        _cache_movie(chat_id, movie_id, gid, uc)

    # Format message
    message = format_movie_detail(result)

    # Send with cover image if available
    img_url = result.get("img")
    if img_url:
        try:
            await update.message.reply_photo(
                photo=img_url,
                caption=message,
                parse_mode="Markdown",
                reply_markup=build_movie_actions_keyboard(movie_id)
            )
            return
        except Exception:
            pass  # Fall back to text message

    await update.message.reply_text(
        message,
        parse_mode="Markdown",
        reply_markup=build_movie_actions_keyboard(movie_id)
    )


@check_api_configured
async def magnets_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle /magnets command - Get magnet links.

    Usage:
        /magnets SSIS-406
    """
    chat_id = update.effective_chat.id
    api_url = config.get_api_url(chat_id)
    client = JavBusAPIClient(api_url)

    args = context.args or []
    if not args:
        await update.message.reply_text(
            "❌ 请提供番号\n\n使用方法:\n`/magnets <番号>`\n例: `/magnets SSIS-406`",
            parse_mode="Markdown"
        )
        return

    movie_id = args[0].upper()

    # Send typing action
    await update.message.chat.send_action("typing")

    # Try to get gid/uc from cache
    cached = movie_cache.get(chat_id, {}).get(movie_id)

    if not cached:
        # Need to fetch movie detail first
        detail = await client.get_movie_detail(movie_id)
        if not detail or "error" in detail:
            await update.message.reply_text(
                f"❌ 获取 `{movie_id}` 信息失败\n请确认番号正确",
                parse_mode="Markdown"
            )
            return

        gid = detail.get("gid", "")
        uc = detail.get("uc", "")

        if not gid:
            await update.message.reply_text(f"❌ 无法获取 `{movie_id}` 的磁力链接信息", parse_mode="Markdown")
            return

        # Cache for future use
        _cache_movie(chat_id, movie_id, gid, uc)
        cached = {"gid": gid, "uc": uc}

    # Fetch magnets
    result = await client.get_magnets(
        movie_id=movie_id,
        gid=cached["gid"],
        uc=cached["uc"],
        sort_by="size",
        sort_order="desc"
    )

    if isinstance(result, dict) and "error" in result:
        await update.message.reply_text(f"❌ 获取磁力链接失败: {result['error']}")
        return

    magnets = result if isinstance(result, list) else []

    # Format message
    message = format_magnets(magnets, movie_id)

    await update.message.reply_text(message, parse_mode="Markdown")


def get_movie_cache():
    """Get movie cache for callback handlers."""
    return movie_cache
