"""
Movies browsing and search handlers
Commands: /movies, /search
"""
from telegram import Update
from telegram.ext import ContextTypes
import config
from api_client import JavBusAPIClient
from utils.formatters import format_movie_list
from utils.keyboards import build_movie_list_keyboard, build_search_list_keyboard
from utils.common import check_api_configured


@check_api_configured
async def movies_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle /movies command - Browse movie list.
    
    Usage:
        /movies - First page with magnets
        /movies 2 - Page 2
        /movies uncensored - Uncensored movies
        /movies star rsv - Filter by star ID
        /movies genre 4 - Filter by genre ID
    """
    chat_id = update.effective_chat.id
    api_url = config.get_api_url(chat_id)
    client = JavBusAPIClient(api_url)
    
    # Parse arguments
    page = 1
    movie_type = "normal"
    filter_type = None
    filter_value = None
    
    args = context.args or []
    i = 0
    while i < len(args):
        arg = args[i].lower()
        
        if arg == "uncensored":
            movie_type = "uncensored"
        elif arg.isdigit():
            page = int(arg)
        elif arg in ("star", "genre", "director", "studio", "label", "series"):
            filter_type = arg
            if i + 1 < len(args):
                filter_value = args[i + 1]
                i += 1
        i += 1
    
    # Send typing action
    await update.message.chat.send_action("typing")
    
    # Fetch movies
    result = await client.get_movies(
        page=page,
        movie_type=movie_type,
        filter_type=filter_type,
        filter_value=filter_value
    )
    
    if not result or "error" in result:
        error_msg = result.get("error", "未知错误") if result else "请求失败"
        await update.message.reply_text(f"❌ 获取影片列表失败: {error_msg}")
        return
    
    movies = result.get("movies", [])
    pagination = result.get("pagination", {})
    filter_info = result.get("filter")
    
    # Format message
    message = format_movie_list(movies, pagination, filter_info=filter_info)
    
    # Build keyboard
    extra_params = ""
    if movie_type == "uncensored":
        extra_params = "uncensored"
    if filter_type and filter_value:
        extra_params = f"{filter_type}:{filter_value}"
    
    keyboard = build_movie_list_keyboard(
        movies,
        pagination.get("currentPage", 1),
        pagination.get("hasNextPage", False),
        callback_prefix="movies",
        extra_params=extra_params
    )
    
    await update.message.reply_text(message, reply_markup=keyboard, parse_mode="Markdown")


@check_api_configured
async def search_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle /search command - Search movies.
    
    Usage:
        /search 三上 - Search keyword
        /search 三上 2 - Search page 2
    """
    chat_id = update.effective_chat.id
    api_url = config.get_api_url(chat_id)
    client = JavBusAPIClient(api_url)
    
    args = context.args or []
    if not args:
        await update.message.reply_text(
            "❌ 请提供搜索关键词\n\n使用方法:\n`/search <关键词>` 或 `/search <关键词> <页码>`",
            parse_mode="Markdown"
        )
        return
    
    # Parse arguments - last arg might be page number
    keyword = " ".join(args)
    page = 1
    
    if len(args) > 1 and args[-1].isdigit():
        page = int(args[-1])
        keyword = " ".join(args[:-1])
    
    # Send typing action
    await update.message.chat.send_action("typing")
    
    # Search movies
    result = await client.search_movies(keyword=keyword, page=page)
    
    if not result or "error" in result:
        error_msg = result.get("error", "未知错误") if result else "请求失败"
        await update.message.reply_text(f"❌ 搜索失败: {error_msg}")
        return
    
    movies = result.get("movies", [])
    pagination = result.get("pagination", {})
    
    # Format message
    message = format_movie_list(movies, pagination, keyword=keyword)
    
    # Build keyboard - use search-specific keyboard
    keyboard = build_search_list_keyboard(
        movies,
        pagination.get("currentPage", 1),
        pagination.get("hasNextPage", False),
        keyword=keyword
    )
    
    await update.message.reply_text(message, reply_markup=keyboard, parse_mode="Markdown")
