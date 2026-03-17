"""
Configuration management for JavBus API Telegram Bot
"""
import os
from dotenv import load_dotenv

load_dotenv()

# Bot token from BotFather
BOT_TOKEN = os.getenv("BOT_TOKEN", "")

# Default API URL (can be overridden per user)
DEFAULT_API_URL = os.getenv("DEFAULT_API_URL", "")

# Optional API authentication token
API_AUTH_TOKEN = os.getenv("API_AUTH_TOKEN", "")

# Default sleep delay between API requests (seconds)
DEFAULT_SLEEP_DELAY = 1.0

# Symedia push configuration (global defaults)
SYMEDIA_URL = os.getenv("SYMEDIA_URL", "")
SYMEDIA_TOKEN = os.getenv("SYMEDIA_TOKEN", "symedia")
SYMEDIA_API_PATH = os.getenv(
    "SYMEDIA_API_PATH",
    "/api/v1/plugin/cloud_helper/add_offline_urls_115"
)
SYMEDIA_CID = os.getenv("SYMEDIA_CID", "0")

# In-memory storage for user-specific API URLs
# Format: {chat_id: api_url}
user_api_urls: dict[int, str] = {}

# In-memory storage for user-specific sleep delays
# Format: {chat_id: delay_seconds}
user_sleep_delays: dict[int, float] = {}

# In-memory storage for user-specific Symedia overrides
# Format: {chat_id: {"url": str, "token": str, "api_path": str, "cid": str}}
user_symedia_config: dict[int, dict] = {}


def get_api_url(chat_id: int) -> str:
    """Get API URL for a specific chat, falling back to default."""
    return user_api_urls.get(chat_id, DEFAULT_API_URL)


def set_api_url(chat_id: int, url: str) -> None:
    """Set API URL for a specific chat."""
    # Remove trailing slash if present
    user_api_urls[chat_id] = url.rstrip("/")


def has_api_url(chat_id: int) -> bool:
    """Check if API URL is configured for a chat."""
    url = get_api_url(chat_id)
    return bool(url and url.strip())


def get_sleep_delay(chat_id: int) -> float:
    """Get sleep delay for a specific chat, falling back to default."""
    return user_sleep_delays.get(chat_id, DEFAULT_SLEEP_DELAY)


def set_sleep_delay(chat_id: int, delay: float) -> None:
    """Set sleep delay for a specific chat."""
    # Clamp between 0 and 5 seconds
    user_sleep_delays[chat_id] = max(0, min(5, delay))


# ── Symedia configuration ──

def get_symedia_config(chat_id: int) -> dict:
    """Get merged Symedia config: per-user overrides > env defaults."""
    base = {
        "url": SYMEDIA_URL,
        "token": SYMEDIA_TOKEN,
        "api_path": SYMEDIA_API_PATH,
        "cid": SYMEDIA_CID,
    }
    user_cfg = user_symedia_config.get(chat_id, {})
    for key in ("url", "token", "api_path", "cid"):
        if user_cfg.get(key):
            base[key] = user_cfg[key]
    return base


def has_symedia_config(chat_id: int) -> bool:
    """Check if Symedia is configured (URL must be set)."""
    cfg = get_symedia_config(chat_id)
    return bool(cfg.get("url", "").strip())


def set_symedia_field(chat_id: int, field: str, value: str) -> None:
    """Set a single Symedia config field for a user."""
    if chat_id not in user_symedia_config:
        user_symedia_config[chat_id] = {}
    user_symedia_config[chat_id][field] = value.strip()
