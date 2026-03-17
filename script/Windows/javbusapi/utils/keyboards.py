"""
Inline keyboard builders for Telegram bot
"""
from telegram import InlineKeyboardButton, InlineKeyboardMarkup


def build_pagination_keyboard(
    current_page: int,
    has_next: bool,
    callback_prefix: str,
    extra_params: str = ""
) -> InlineKeyboardMarkup:
    """
    Build pagination keyboard with previous/next buttons.
    
    Args:
        current_page: Current page number
        has_next: Whether there is a next page
        callback_prefix: Prefix for callback data (e.g., "movies", "search")
        extra_params: Extra parameters to append to callback data
    """
    buttons = []
    
    # Previous page button
    if current_page > 1:
        prev_data = f"{callback_prefix}:{current_page - 1}"
        if extra_params:
            prev_data += f":{extra_params}"
        buttons.append(InlineKeyboardButton("⬅️ 上一页", callback_data=prev_data))
    
    # Page indicator
    buttons.append(InlineKeyboardButton(f"📄 {current_page}", callback_data="noop"))
    
    # Next page button
    if has_next:
        next_data = f"{callback_prefix}:{current_page + 1}"
        if extra_params:
            next_data += f":{extra_params}"
        buttons.append(InlineKeyboardButton("下一页 ➡️", callback_data=next_data))
    
    return InlineKeyboardMarkup([buttons])


def build_movie_actions_keyboard(movie_id: str) -> InlineKeyboardMarkup:
    """Build action buttons for a movie."""
    buttons = [
        [
            InlineKeyboardButton("📝 详情", callback_data=f"detail:{movie_id}"),
            InlineKeyboardButton("🧲 磁力", callback_data=f"magnet:{movie_id}"),
        ]
    ]
    return InlineKeyboardMarkup(buttons)


def build_movie_list_keyboard(
    movies: list,
    current_page: int,
    has_next: bool,
    callback_prefix: str = "movies",
    extra_params: str = ""
) -> InlineKeyboardMarkup:
    """Build keyboard with movie quick actions and pagination."""
    keyboard = []
    
    # Quick action buttons for ALL movies (up to 10 to avoid too many buttons)
    for i, movie in enumerate(movies[:10]):
        movie_id = movie.get("id", "")
        if movie_id:
            keyboard.append([
                InlineKeyboardButton(f"📝 {movie_id}", callback_data=f"detail:{movie_id}"),
                InlineKeyboardButton(f"🧲 磁力", callback_data=f"magnet:{movie_id}"),
            ])
    
    # Batch magnet button
    batch_data = f"batch_magnets:{current_page}"
    if extra_params:
        batch_data += f":{extra_params}"
    keyboard.append([
        InlineKeyboardButton("📋 本页全部磁力", callback_data=batch_data)
    ])
    
    # Pagination row
    pagination_row = []
    if current_page > 1:
        prev_data = f"{callback_prefix}:{current_page - 1}"
        if extra_params:
            prev_data += f":{extra_params}"
        pagination_row.append(InlineKeyboardButton("⬅️ 上一页", callback_data=prev_data))
    
    pagination_row.append(InlineKeyboardButton(f"📄 {current_page}", callback_data="noop"))
    
    if has_next:
        next_data = f"{callback_prefix}:{current_page + 1}"
        if extra_params:
            next_data += f":{extra_params}"
        pagination_row.append(InlineKeyboardButton("下一页 ➡️", callback_data=next_data))
    
    if pagination_row:
        keyboard.append(pagination_row)
    
    return InlineKeyboardMarkup(keyboard)


def build_search_list_keyboard(
    movies: list,
    current_page: int,
    has_next: bool,
    keyword: str = ""
) -> InlineKeyboardMarkup:
    """Build keyboard for search results with movie quick actions and pagination."""
    keyboard = []
    
    # Quick action buttons for ALL movies (up to 10)
    for i, movie in enumerate(movies[:10]):
        movie_id = movie.get("id", "")
        if movie_id:
            keyboard.append([
                InlineKeyboardButton(f"📝 {movie_id}", callback_data=f"detail:{movie_id}"),
                InlineKeyboardButton(f"🧲 磁力", callback_data=f"magnet:{movie_id}"),
            ])
    
    # Batch magnet button  
    batch_data = f"batch_search_magnets:{current_page}:{keyword}"
    keyboard.append([
        InlineKeyboardButton("📋 本页全部磁力", callback_data=batch_data)
    ])
    
    # Pagination row
    pagination_row = []
    if current_page > 1:
        prev_data = f"search:{current_page - 1}:{keyword}"
        pagination_row.append(InlineKeyboardButton("⬅️ 上一页", callback_data=prev_data))
    
    pagination_row.append(InlineKeyboardButton(f"📄 {current_page}", callback_data="noop"))
    
    if has_next:
        next_data = f"search:{current_page + 1}:{keyword}"
        pagination_row.append(InlineKeyboardButton("下一页 ➡️", callback_data=next_data))
    
    if pagination_row:
        keyboard.append(pagination_row)
    
    return InlineKeyboardMarkup(keyboard)


def build_filter_keyboard() -> InlineKeyboardMarkup:
    """Build filter options keyboard."""
    keyboard = [
        [
            InlineKeyboardButton("🎭 有码", callback_data="filter:type:normal"),
            InlineKeyboardButton("🎭 无码", callback_data="filter:type:uncensored"),
        ],
        [
            InlineKeyboardButton("🧲 仅有磁力", callback_data="filter:magnet:exist"),
            InlineKeyboardButton("📋 全部", callback_data="filter:magnet:all"),
        ]
    ]
    return InlineKeyboardMarkup(keyboard)


def build_star_actions_keyboard(star_id: str) -> InlineKeyboardMarkup:
    """Build action buttons for a star."""
    buttons = [
        [
            InlineKeyboardButton("🎬 查看作品", callback_data=f"star_movies:{star_id}"),
        ]
    ]
    return InlineKeyboardMarkup(buttons)
