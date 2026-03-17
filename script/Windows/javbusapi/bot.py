"""
JavBus API Telegram Bot - Main Entry Point

A Telegram bot providing full access to all JavBus API endpoints.

Usage:
    1. Create .env file with BOT_TOKEN=<your_bot_token>
    2. Run: python bot.py
    3. Use /setapi <url> to configure API endpoint
"""
import logging
import re
import asyncio
import time
from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    CallbackQueryHandler,
    MessageHandler,
    ContextTypes,
    filters,
)

import config
from api_client import JavBusAPIClient
from handlers.start import start_command, help_command, setapi_command, sleep_command
from handlers.movies import movies_command, search_command
from handlers.movie_detail import movie_command, magnets_command, get_movie_cache
from handlers.star import star_command
from handlers.symedia import symedia_command, push_to_symedia
from utils.formatters import (
    format_movie_list, format_movie_detail, format_magnets,
    format_movie_with_magnets, format_batch_magnets, get_best_magnet
)
from utils.keyboards import build_movie_list_keyboard, build_search_list_keyboard

# Configure logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logging.getLogger("httpx").setLevel(logging.WARNING)
logger = logging.getLogger(__name__)

# Regex pattern for movie IDs (e.g., SSIS-406, ABC-123, IPX-001)
MOVIE_ID_PATTERN = re.compile(r'^[A-Za-z]{2,10}-?\d{2,5}$')

# Max time for batch operations (seconds)
BATCH_TIMEOUT = 300


async def _do_symedia_push(update: Update, chat_id: int, results: list[dict]) -> None:
    """Helper: push batch magnet results to Symedia and reply with status."""
    if not config.has_symedia_config(chat_id):
        await update.message.reply_text(
            "⚠️ 未配置 Symedia\n使用 `/symedia set <url>` 进行设置",
            parse_mode="Markdown"
        )
        return

    links = [r["magnet"] for r in results if r.get("magnet")]
    if not links:
        await update.message.reply_text("⚠️ 没有可推送的磁力链接")
        return

    cfg = config.get_symedia_config(chat_id)
    await update.message.reply_text(f"📤 正在推送 {len(links)} 条链接到 Symedia...")
    result = await push_to_symedia(cfg, links)

    if result["success"]:
        await update.message.reply_text(f"✅ {result['message']}")
    else:
        await update.message.reply_text(f"❌ {result['message']}")


async def direct_movie_id_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle direct movie ID input - show both detail and magnets.
    Gets triggered when user sends just a movie ID like "SSIS-406".
    Also supports "SSIS-406 sa" to automatically push to Symedia.
    """
    chat_id = update.effective_chat.id
    text = update.message.text.strip()

    # Check for symedia auto-push keyword ('sa')
    should_push_symedia = False
    if text.lower().endswith(" sa"):
        should_push_symedia = True
        text = text[:-3].strip()

    text = text.upper()

    # Check if it looks like a movie ID
    if not MOVIE_ID_PATTERN.match(text):
        return

    # Check API configured
    if not config.has_api_url(chat_id):
        await update.message.reply_text(
            "❌ 请先设置 API 地址\n\n使用 `/setapi https://your-api-url.com`",
            parse_mode="Markdown"
        )
        return

    movie_id = text
    api_url = config.get_api_url(chat_id)
    client = JavBusAPIClient(api_url)

    # Send typing action
    await update.message.chat.send_action("typing")

    # Fetch movie detail
    detail = await client.get_movie_detail(movie_id)

    if not detail or "error" in detail:
        await update.message.reply_text(
            f"❌ 找不到番号 `{movie_id}`",
            parse_mode="Markdown"
        )
        return

    # Cache gid/uc
    movie_cache = get_movie_cache()
    if chat_id not in movie_cache:
        movie_cache[chat_id] = {}

    gid = detail.get("gid", "")
    uc = detail.get("uc", "")
    if gid:
        movie_cache[chat_id][movie_id] = {"gid": gid, "uc": uc}

    # Fetch magnets
    magnets = []
    if gid:
        result = await client.get_magnets(movie_id=movie_id, gid=gid, uc=uc)
        if isinstance(result, list):
            magnets = result

    # Format combined message
    message = format_movie_with_magnets(detail, magnets)

    # Send with cover image if available
    img_url = detail.get("img")
    if img_url:
        try:
            await update.message.reply_photo(
                photo=img_url,
                caption=message,
                parse_mode="Markdown"
            )
        except Exception:
            await update.message.reply_text(message, parse_mode="Markdown")
    else:
        await update.message.reply_text(message, parse_mode="Markdown")

    # Handle Symedia push if requested
    if should_push_symedia and magnets:
        best = get_best_magnet(magnets)
        if best and best.get("link"):
            await _do_symedia_push(
                update, chat_id,
                [{"movie_id": movie_id, "magnet": best["link"]}]
            )


async def _fetch_batch_magnets(
    client: JavBusAPIClient,
    chat_id: int,
    movies_fetcher,
    start_page: int,
    end_page: int,
    progress_callback=None,
) -> tuple[list[dict], list[str]]:
    """
    Core batch magnet fetcher with timeout protection and error recovery.

    Args:
        client: API client instance
        chat_id: Chat ID for sleep delay config
        movies_fetcher: async callable(page) -> result dict
        start_page / end_page: page range
        progress_callback: async callable(current, total, page) for progress updates

    Returns:
        (results, failed_movies)
    """
    results = []
    failed_movies = []
    movie_count = 0
    batch_start = time.monotonic()

    for page in range(start_page, end_page + 1):
        # Global timeout check
        if time.monotonic() - batch_start > BATCH_TIMEOUT:
            failed_movies.append("⏰ 超时，已跳过剩余影片")
            break

        try:
            movies_result = await movies_fetcher(page)
        except Exception as e:
            failed_movies.append(f"第{page}页: 获取列表失败 - {str(e)[:30]}")
            continue

        if not movies_result or "error" in movies_result:
            failed_movies.append(f"第{page}页: {movies_result.get('error', '请求失败') if movies_result else '请求失败'}")
            continue

        movies = movies_result.get("movies", [])
        total_movies = len(movies)

        for idx, movie in enumerate(movies):
            # Timeout check per movie
            if time.monotonic() - batch_start > BATCH_TIMEOUT:
                failed_movies.append("⏰ 超时，已跳过剩余影片")
                break

            movie_id = movie.get("id", "")
            if not movie_id:
                continue

            # Rate limiting delay
            if movie_count > 0:
                await asyncio.sleep(config.get_sleep_delay(chat_id))
            movie_count += 1

            # Progress update
            if progress_callback and movie_count % 3 == 0:
                try:
                    await progress_callback(movie_count, total_movies, page)
                except Exception:
                    pass

            try:
                # Get movie detail for gid/uc
                detail = await client.get_movie_detail(movie_id)
                if not detail:
                    failed_movies.append(f"`{movie_id}`: 获取详情失败")
                    continue
                if "error" in detail:
                    failed_movies.append(f"`{movie_id}`: {detail.get('error', '未知错误')}")
                    continue

                gid = detail.get("gid", "")
                uc = detail.get("uc", "")
                if not gid:
                    failed_movies.append(f"`{movie_id}`: 无gid参数")
                    continue

                # Get magnets
                magnets_result = await client.get_magnets(movie_id=movie_id, gid=gid, uc=uc)
                if not isinstance(magnets_result, list):
                    failed_movies.append(f"`{movie_id}`: 磁力请求失败")
                    continue
                if not magnets_result:
                    failed_movies.append(f"`{movie_id}`: 无磁力链接")
                    continue

                # Get best magnet
                best = get_best_magnet(magnets_result)
                if best:
                    is_hd = best.get("isHD", False)
                    has_sub = best.get("hasSubtitle", False)
                    tags = []
                    if is_hd:
                        tags.append("高清")
                    if has_sub:
                        tags.append("字幕")
                    info = " ".join([f"[{t}]" for t in tags]) if tags else ""

                    results.append({
                        "movie_id": movie_id,
                        "magnet": best.get("link", ""),
                        "info": info
                    })
            except Exception as e:
                failed_movies.append(f"`{movie_id}`: {str(e)[:30]}")
                logger.error(f"Error processing {movie_id}: {e}")
                continue

    return results, failed_movies


async def movies_magnets_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle /movies_magnets command - Get batch magnets from movie list.

    Usage:
        /movies_magnets all 1-2      - Get magnets from pages 1-2
        /movies_magnets all 1        - Get magnets from page 1
        /movies_magnets all 1 sa     - Get magnets and push to Symedia
    """
    chat_id = update.effective_chat.id

    if not config.has_api_url(chat_id):
        await update.message.reply_text(
            "❌ 请先设置 API 地址",
            parse_mode="Markdown"
        )
        return

    args = context.args or []
    if len(args) < 2:
        await update.message.reply_text(
            "❌ 使用方法:\n"
            "/movies_magnets all 1-2 (第1-2页)\n"
            "/movies_magnets all 1 sa (获取并推送到Symedia)"
        )
        return

    # Check for symedia auto-push flag ('sa')
    should_push_symedia = False
    if args[-1].lower() == "sa":
        should_push_symedia = True
        args = args[:-1]

    # Parse page range
    page_range = args[1]
    if "-" in page_range:
        start_page, end_page = map(int, page_range.split("-"))
    else:
        start_page = end_page = int(page_range)

    # Limit to max 5 pages
    end_page = min(end_page, start_page + 4)

    status_msg = await update.message.reply_text(
        f"🔄 正在获取第 {start_page}-{end_page} 页的磁力链接...",
        parse_mode="Markdown"
    )

    api_url = config.get_api_url(chat_id)
    client = JavBusAPIClient(api_url)

    async def fetcher(page):
        return await client.get_movies(page=page)

    async def progress(current, total, page):
        try:
            await status_msg.edit_text(
                f"🔄 第{page}页 进度: {current}个影片已处理..."
            )
        except Exception:
            pass

    results, failed_movies = await _fetch_batch_magnets(
        client, chat_id, fetcher, start_page, end_page, progress
    )

    # Format and send results
    if results:
        message = format_batch_magnets(results)
        if failed_movies:
            message += f"\n\n⚠️ {len(failed_movies)} 个影片获取失败"
            message += "\n" + "\n".join(failed_movies[:5])
            if len(failed_movies) > 5:
                message += f"\n... 还有 {len(failed_movies) - 5} 个"

        if len(message) > 4000:
            await status_msg.edit_text(f"🧲 共获取到 {len(results)} 个磁力链接")
            chunks = []
            current_chunk = "🧲 *批量磁力链接*\n\n"
            for item in results:
                line = f"`{item['movie_id']}` {item['info']}\n`{item['magnet']}`\n\n"
                if len(current_chunk) + len(line) > 4000:
                    chunks.append(current_chunk)
                    current_chunk = ""
                current_chunk += line
            if current_chunk:
                chunks.append(current_chunk)
            for chunk in chunks:
                await context.bot.send_message(
                    chat_id=chat_id, text=chunk, parse_mode="Markdown"
                )
        else:
            await status_msg.edit_text(message, parse_mode="Markdown")

        # Symedia push
        if should_push_symedia:
            await _do_symedia_push(update, chat_id, results)
    else:
        fail_msg = "❌ 没有找到任何磁力链接"
        if failed_movies:
            fail_msg += f"\n\n失败原因:\n" + "\n".join(failed_movies[:10])
        await status_msg.edit_text(fail_msg, parse_mode="Markdown")


async def search_magnets_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle /search_magnets command - Get batch magnets from search results.

    Usage:
        /search_magnets 三上悠亜 all 1-2   - Search and get magnets
        /search_magnets 三上悠亜 all 1 sa  - Search, get magnets, push to Symedia
    """
    chat_id = update.effective_chat.id

    if not config.has_api_url(chat_id):
        await update.message.reply_text(
            "❌ 请先设置 API 地址",
            parse_mode="Markdown"
        )
        return

    args = context.args or []
    if len(args) < 3:
        await update.message.reply_text(
            "❌ 使用方法:\n"
            "/search_magnets 三上悠亜 all 1-2 (第1-2页)\n"
            "/search_magnets 三上 all 1 sa (获取并推送到Symedia)"
        )
        return

    # Check for symedia auto-push flag ('sa')
    should_push_symedia = False
    if args[-1].lower() == "sa":
        should_push_symedia = True
        args = args[:-1]

    # Parse arguments: keyword, 'all', page_range
    keyword = args[0]
    page_range = args[2]

    if "-" in page_range:
        start_page, end_page = map(int, page_range.split("-"))
    else:
        start_page = end_page = int(page_range)

    # Limit to max 5 pages
    end_page = min(end_page, start_page + 4)

    status_msg = await update.message.reply_text(
        f"🔄 正在搜索 `{keyword}` 第 {start_page}-{end_page} 页的磁力链接...",
        parse_mode="Markdown"
    )

    api_url = config.get_api_url(chat_id)
    client = JavBusAPIClient(api_url)

    async def fetcher(page):
        return await client.search_movies(keyword=keyword, page=page)

    async def progress(current, total, page):
        try:
            await status_msg.edit_text(
                f"🔄 搜索 `{keyword}` 第{page}页 进度: {current}个影片已处理...",
                parse_mode="Markdown"
            )
        except Exception:
            pass

    results, failed_movies = await _fetch_batch_magnets(
        client, chat_id, fetcher, start_page, end_page, progress
    )

    # Format and send results
    if results:
        message = format_batch_magnets(results)
        if failed_movies:
            message += f"\n\n⚠️ {len(failed_movies)} 个影片获取失败"
            message += "\n" + "\n".join(failed_movies[:5])
            if len(failed_movies) > 5:
                message += f"\n... 还有 {len(failed_movies) - 5} 个"

        if len(message) > 4000:
            await status_msg.edit_text(f"🧲 共获取到 {len(results)} 个磁力链接")
            chunks = []
            current_chunk = "🧲 *批量磁力链接*\n\n"
            for item in results:
                line = f"`{item['movie_id']}` {item['info']}\n`{item['magnet']}`\n\n"
                if len(current_chunk) + len(line) > 4000:
                    chunks.append(current_chunk)
                    current_chunk = ""
                current_chunk += line
            if current_chunk:
                chunks.append(current_chunk)
            for chunk in chunks:
                await context.bot.send_message(
                    chat_id=chat_id, text=chunk, parse_mode="Markdown"
                )
        else:
            await status_msg.edit_text(message, parse_mode="Markdown")

        # Symedia push
        if should_push_symedia:
            await _do_symedia_push(update, chat_id, results)
    else:
        fail_msg = "❌ 没有找到任何磁力链接"
        if failed_movies:
            fail_msg += f"\n\n失败原因:\n" + "\n".join(failed_movies[:10])
        await status_msg.edit_text(fail_msg, parse_mode="Markdown")


async def callback_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle inline keyboard callbacks."""
    query = update.callback_query
    await query.answer()

    data = query.data
    chat_id = update.effective_chat.id

    if data == "noop":
        return

    parts = data.split(":")
    action = parts[0]

    # Check API configured
    if not config.has_api_url(chat_id):
        await query.edit_message_text(
            "❌ 请先使用 `/setapi` 设置 API 地址",
            parse_mode="Markdown"
        )
        return

    api_url = config.get_api_url(chat_id)
    client = JavBusAPIClient(api_url)

    try:
        if action == "movies":
            # Pagination for movies list
            page = int(parts[1]) if len(parts) > 1 else 1
            extra = ":".join(parts[2:]) if len(parts) > 2 else ""

            movie_type = "normal"
            filter_type = None
            filter_value = None

            if extra == "uncensored":
                movie_type = "uncensored"
            elif ":" in extra:
                filter_type, filter_value = extra.split(":", 1)

            result = await client.get_movies(
                page=page,
                movie_type=movie_type,
                filter_type=filter_type,
                filter_value=filter_value
            )

            if not result or "error" in result:
                await query.edit_message_text(f"❌ 获取失败")
                return

            movies = result.get("movies", [])
            pagination = result.get("pagination", {})
            filter_info = result.get("filter")

            # Store movies for batch magnet
            context.user_data["last_movies"] = movies
            context.user_data["last_movies_type"] = "movies"
            context.user_data["last_movies_extra"] = extra

            message = format_movie_list(movies, pagination, filter_info=filter_info)
            keyboard = build_movie_list_keyboard(
                movies,
                pagination.get("currentPage", 1),
                pagination.get("hasNextPage", False),
                callback_prefix="movies",
                extra_params=extra
            )

            await query.edit_message_text(message, reply_markup=keyboard, parse_mode="Markdown")

        elif action == "search":
            # Pagination for search results
            page = int(parts[1]) if len(parts) > 1 else 1
            keyword = ":".join(parts[2:]) if len(parts) > 2 else ""

            result = await client.search_movies(keyword=keyword, page=page)

            if not result or "error" in result:
                await query.edit_message_text(f"❌ 搜索失败")
                return

            movies = result.get("movies", [])
            pagination = result.get("pagination", {})

            # Store movies for batch magnet
            context.user_data["last_movies"] = movies
            context.user_data["last_movies_type"] = "search"
            context.user_data["last_movies_keyword"] = keyword

            message = format_movie_list(movies, pagination, keyword=keyword)
            keyboard = build_search_list_keyboard(
                movies,
                pagination.get("currentPage", 1),
                pagination.get("hasNextPage", False),
                keyword=keyword
            )

            await query.edit_message_text(message, reply_markup=keyboard, parse_mode="Markdown")

        elif action == "detail":
            # Quick view movie detail
            movie_id = parts[1] if len(parts) > 1 else ""
            if not movie_id:
                return

            result = await client.get_movie_detail(movie_id)

            if not result or "error" in result:
                await query.edit_message_text(f"❌ 获取 `{movie_id}` 详情失败", parse_mode="Markdown")
                return

            # Cache gid/uc
            movie_cache = get_movie_cache()
            if chat_id not in movie_cache:
                movie_cache[chat_id] = {}
            gid = result.get("gid", "")
            uc = result.get("uc", "")
            if gid:
                movie_cache[chat_id][movie_id] = {"gid": gid, "uc": uc}

            message = format_movie_detail(result)
            await query.edit_message_text(message, parse_mode="Markdown")

        elif action == "magnet":
            # Quick view magnets
            movie_id = parts[1] if len(parts) > 1 else ""
            if not movie_id:
                return

            # Try cache first
            movie_cache = get_movie_cache()
            cached = movie_cache.get(chat_id, {}).get(movie_id)

            if not cached:
                detail = await client.get_movie_detail(movie_id)
                if not detail or "error" in detail:
                    await query.edit_message_text(f"❌ 获取 `{movie_id}` 信息失败", parse_mode="Markdown")
                    return

                gid = detail.get("gid", "")
                uc = detail.get("uc", "")
                if not gid:
                    await query.edit_message_text(f"❌ 无法获取磁力链接", parse_mode="Markdown")
                    return

                if chat_id not in movie_cache:
                    movie_cache[chat_id] = {}
                movie_cache[chat_id][movie_id] = {"gid": gid, "uc": uc}
                cached = {"gid": gid, "uc": uc}

            result = await client.get_magnets(
                movie_id=movie_id,
                gid=cached["gid"],
                uc=cached["uc"]
            )

            magnets = result if isinstance(result, list) else []
            message = format_magnets(magnets, movie_id)
            await query.edit_message_text(message, parse_mode="Markdown")

        elif action == "batch_magnets" or action == "batch_search_magnets":
            # Get batch magnets for current page
            page = int(parts[1]) if len(parts) > 1 else 1
            extra = ":".join(parts[2:]) if len(parts) > 2 else ""

            await query.edit_message_text("🔄 正在获取本页所有磁力链接...")

            # Build fetcher
            if action == "batch_magnets":
                movie_type = "normal"
                filter_type = None
                filter_value = None
                if extra == "uncensored":
                    movie_type = "uncensored"
                elif extra and ":" in extra:
                    filter_type, filter_value = extra.split(":", 1)

                async def fetcher(p):
                    return await client.get_movies(
                        page=p, movie_type=movie_type,
                        filter_type=filter_type, filter_value=filter_value
                    )
            else:
                keyword = extra
                async def fetcher(p):
                    return await client.search_movies(keyword=keyword, page=p)

            async def progress(current, total, pg):
                try:
                    await query.edit_message_text(
                        f"🔄 正在获取磁力链接... ({current}个已处理)"
                    )
                except Exception:
                    pass

            results, failed_movies = await _fetch_batch_magnets(
                client, chat_id, fetcher, page, page, progress
            )

            if results:
                message = format_batch_magnets(results)
                if failed_movies:
                    message += f"\n\n⚠️ {len(failed_movies)} 个影片获取失败"
                    if len(failed_movies) <= 5:
                        message += "\n" + "\n".join(failed_movies)
                    else:
                        message += "\n" + "\n".join(failed_movies[:5])
                        message += f"\n... 还有 {len(failed_movies) - 5} 个"

                if len(message) > 4000:
                    await query.edit_message_text(f"🧲 共获取到 {len(results)} 个磁力链接")
                    chunks = []
                    current_chunk = "🧲 *批量磁力链接*\n\n"
                    for item in results:
                        line = f"`{item['movie_id']}` {item['info']}\n`{item['magnet']}`\n\n"
                        if len(current_chunk) + len(line) > 4000:
                            chunks.append(current_chunk)
                            current_chunk = ""
                        current_chunk += line
                    if current_chunk:
                        chunks.append(current_chunk)

                    for chunk in chunks:
                        await context.bot.send_message(
                            chat_id=chat_id, text=chunk, parse_mode="Markdown"
                        )

                    if failed_movies:
                        fail_msg = f"⚠️ {len(failed_movies)} 个影片获取失败:\n"
                        fail_msg += "\n".join(failed_movies[:10])
                        if len(failed_movies) > 10:
                            fail_msg += f"\n... 还有 {len(failed_movies) - 10} 个"
                        await context.bot.send_message(
                            chat_id=chat_id, text=fail_msg, parse_mode="Markdown"
                        )
                else:
                    await query.edit_message_text(message, parse_mode="Markdown")
            else:
                fail_msg = "❌ 没有找到任何磁力链接"
                if failed_movies:
                    fail_msg += f"\n\n失败原因:\n" + "\n".join(failed_movies[:10])
                await query.edit_message_text(fail_msg, parse_mode="Markdown")

        elif action == "star_movies":
            # View star's movies
            star_id = parts[1] if len(parts) > 1 else ""
            if not star_id:
                return

            result = await client.get_movies(filter_type="star", filter_value=star_id)

            if not result or "error" in result:
                await query.edit_message_text(f"❌ 获取作品列表失败")
                return

            movies = result.get("movies", [])
            pagination = result.get("pagination", {})
            filter_info = result.get("filter")

            message = format_movie_list(movies, pagination, filter_info=filter_info)
            keyboard = build_movie_list_keyboard(
                movies,
                pagination.get("currentPage", 1),
                pagination.get("hasNextPage", False),
                callback_prefix="movies",
                extra_params=f"star:{star_id}"
            )

            await query.edit_message_text(message, reply_markup=keyboard, parse_mode="Markdown")

    except Exception as e:
        logger.error(f"Callback error: {e}")
        await query.edit_message_text(f"❌ 操作失败: {str(e)}")


async def error_handler(update: object, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle errors."""
    logger.error(f"Exception while handling update: {context.error}")


def main():
    """Run the bot."""
    if not config.BOT_TOKEN:
        print("❌ 错误: 未设置 BOT_TOKEN")
        print("请创建 .env 文件并设置 BOT_TOKEN=<your_bot_token>")
        return

    # Create application
    application = Application.builder().token(config.BOT_TOKEN).build()

    # Add command handlers
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("help", help_command))
    application.add_handler(CommandHandler("setapi", setapi_command))
    application.add_handler(CommandHandler("sleep", sleep_command))
    application.add_handler(CommandHandler("movies", movies_command))
    application.add_handler(CommandHandler("search", search_command))
    application.add_handler(CommandHandler("movie", movie_command))
    application.add_handler(CommandHandler("magnets", magnets_command))
    application.add_handler(CommandHandler("star", star_command))
    application.add_handler(CommandHandler("movies_magnets", movies_magnets_command))
    application.add_handler(CommandHandler("search_magnets", search_magnets_command))
    application.add_handler(CommandHandler("symedia", symedia_command))

    # Add callback handler
    application.add_handler(CallbackQueryHandler(callback_handler))

    # Add direct movie ID handler (must be last, catches text messages)
    application.add_handler(MessageHandler(
        filters.TEXT & ~filters.COMMAND,
        direct_movie_id_handler
    ))

    # Add error handler
    application.add_error_handler(error_handler)

    # Start polling
    logger.info("🚀 Bot starting...")
    application.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
