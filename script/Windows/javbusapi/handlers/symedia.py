"""
Symedia push handler
Commands: /symedia

Push magnet links to Symedia's 115 cloud offline download API.
"""
import logging
import aiohttp
from telegram import Update
from telegram.ext import ContextTypes
import config

logger = logging.getLogger(__name__)

# Batch settings
BATCH_SIZE = 10
BATCH_DELAY = 1


async def push_to_symedia(cfg: dict, links: list[str]) -> dict:
    """
    Push magnet links to Symedia asynchronously.

    Args:
        cfg: Symedia config dict with url, token, api_path, cid
        links: List of magnet/ed2k links

    Returns:
        {"success": bool, "message": str, "count": int, "failed": int}
    """
    base_url = (cfg.get("url") or "").rstrip("/")
    token = cfg.get("token", "symedia")
    api_path = cfg.get("api_path", "/api/v1/plugin/cloud_helper/add_offline_urls_115")
    cid = cfg.get("cid", "0") or "0"

    if not base_url:
        return {"success": False, "message": "未配置 Symedia 地址", "count": 0, "failed": 0}
    if not links:
        return {"success": False, "message": "没有链接可推送", "count": 0, "failed": 0}

    full_url = f"{base_url}{api_path}?token={token}"
    timeout = aiohttp.ClientTimeout(total=15, connect=10)

    total = len(links)
    pushed = 0
    failed = 0

    async with aiohttp.ClientSession(timeout=timeout) as session:
        for i in range(0, total, BATCH_SIZE):
            batch = links[i:i + BATCH_SIZE]
            batch_num = i // BATCH_SIZE + 1

            try:
                async with session.post(
                    full_url,
                    json={"urls": batch, "parent_id": cid},
                    headers={"Content-Type": "application/json"},
                ) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        if data.get("success"):
                            msg = data.get("message", "")
                            if "失败" in msg:
                                logger.warning(f"批次 {batch_num}: Symedia 返回: {msg}")
                                failed += len(batch)
                            else:
                                logger.info(f"批次 {batch_num}: 推送成功 ({len(batch)} 条)")
                                pushed += len(batch)
                        else:
                            err_msg = data.get("message") or data.get("detail") or str(data)[:100]
                            logger.warning(f"批次 {batch_num}: 推送失败 — {err_msg}")
                            failed += len(batch)
                    elif resp.status == 404:
                        logger.error(f"Symedia API 路径不存在 (404): {api_path}")
                        return {
                            "success": False,
                            "message": f"API 路径不存在 (404): {api_path}",
                            "count": pushed,
                            "failed": total - pushed,
                        }
                    else:
                        body = await resp.text()
                        logger.warning(f"批次 {batch_num}: HTTP {resp.status} — {body[:120]}")
                        failed += len(batch)

            except aiohttp.ClientError as e:
                logger.warning(f"批次 {batch_num}: 网络错误 — {e}")
                failed += len(batch)
            except Exception as e:
                logger.error(f"批次 {batch_num}: 请求异常 — {e}")
                failed += len(batch)

            # Delay between batches
            if i + BATCH_SIZE < total:
                import asyncio
                await asyncio.sleep(BATCH_DELAY)

    success = failed == 0
    message = f"推送完成: {pushed}/{total} 成功" + (f", {failed} 失败" if failed else "")
    return {"success": success, "message": message, "count": pushed, "failed": failed}


async def symedia_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """
    Handle /symedia command - Manage Symedia push configuration.

    Usage:
        /symedia          - Show current config
        /symedia set <url> - Set Symedia URL
        /symedia token <t> - Set API token
        /symedia cid <id>  - Set target folder ID
        /symedia test      - Test connection
    """
    chat_id = update.effective_chat.id
    args = context.args or []

    if not args:
        # Show current config
        cfg = config.get_symedia_config(chat_id)
        url = cfg.get("url") or "未设置"
        token = cfg.get("token", "symedia")
        cid = cfg.get("cid", "0")
        api_path = cfg.get("api_path", "")
        configured = config.has_symedia_config(chat_id)
        status = "🟢 已配置" if configured else "🔴 未配置"

        await update.message.reply_text(
            f"📤 *Symedia 推送配置*\n\n"
            f"状态: {status}\n"
            f"地址: `{url}`\n"
            f"Token: `{token}`\n"
            f"CID: `{cid}`\n"
            f"API: `{api_path}`\n\n"
            f"━━━━━━━━━━━━━━━\n"
            f"设置命令:\n"
            f"• `/symedia set <url>` - 设置地址\n"
            f"• `/symedia token <token>` - 设置Token\n"
            f"• `/symedia cid <id>` - 设置目标文件夹\n"
            f"• `/symedia test` - 测试连接",
            parse_mode="Markdown"
        )
        return

    action = args[0].lower()

    if action == "set":
        if len(args) < 2:
            await update.message.reply_text("❌ 请提供 Symedia 地址\n例: `/symedia set http://192.168.1.100:8095`", parse_mode="Markdown")
            return
        url = args[1].strip()
        if not url.startswith(("http://", "https://")):
            await update.message.reply_text("❌ URL 必须以 http:// 或 https:// 开头")
            return
        config.set_symedia_field(chat_id, "url", url)
        await update.message.reply_text(f"✅ Symedia 地址已设置为:\n`{url}`", parse_mode="Markdown")

    elif action == "token":
        if len(args) < 2:
            await update.message.reply_text("❌ 请提供 Token\n例: `/symedia token mytoken`", parse_mode="Markdown")
            return
        token = args[1].strip()
        config.set_symedia_field(chat_id, "token", token)
        await update.message.reply_text(f"✅ Token 已设置为: `{token}`", parse_mode="Markdown")

    elif action == "cid":
        if len(args) < 2:
            await update.message.reply_text("❌ 请提供目标文件夹 ID\n例: `/symedia cid 2233445566`", parse_mode="Markdown")
            return
        cid = args[1].strip()
        config.set_symedia_field(chat_id, "cid", cid)
        await update.message.reply_text(f"✅ 目标文件夹 CID 已设置为: `{cid}`", parse_mode="Markdown")

    elif action == "api" or action == "path":
        if len(args) < 2:
            await update.message.reply_text("❌ 请提供 API 路径")
            return
        api_path = args[1].strip()
        config.set_symedia_field(chat_id, "api_path", api_path)
        await update.message.reply_text(f"✅ API 路径已设置为:\n`{api_path}`", parse_mode="Markdown")

    elif action == "test":
        if not config.has_symedia_config(chat_id):
            await update.message.reply_text("❌ 请先设置 Symedia 地址\n`/symedia set <url>`", parse_mode="Markdown")
            return

        await update.message.reply_text("🔄 正在测试连接...")

        cfg = config.get_symedia_config(chat_id)
        base_url = cfg["url"].rstrip("/")

        try:
            timeout = aiohttp.ClientTimeout(total=10, connect=5)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                # Test with empty push (won't actually push)
                test_url = f"{base_url}{cfg['api_path']}?token={cfg['token']}"
                async with session.post(
                    test_url,
                    json={"urls": [], "parent_id": cfg.get("cid", "0")},
                    headers={"Content-Type": "application/json"},
                ) as resp:
                    if resp.status == 200:
                        await update.message.reply_text("✅ 连接成功! Symedia 服务正常")
                    elif resp.status == 404:
                        await update.message.reply_text(f"❌ API 路径不存在 (404)\n当前路径: `{cfg['api_path']}`", parse_mode="Markdown")
                    elif resp.status == 401 or resp.status == 403:
                        await update.message.reply_text(f"❌ 认证失败 ({resp.status})\n请检查 Token 是否正确")
                    else:
                        body = await resp.text()
                        await update.message.reply_text(f"⚠️ 服务响应: HTTP {resp.status}\n{body[:200]}")
        except aiohttp.ClientConnectorError:
            await update.message.reply_text(f"❌ 无法连接到 `{base_url}`\n请检查地址是否正确", parse_mode="Markdown")
        except Exception as e:
            await update.message.reply_text(f"❌ 连接失败: {str(e)[:100]}")

    else:
        await update.message.reply_text(
            "❌ 未知操作\n\n可用: set, token, cid, test"
        )
