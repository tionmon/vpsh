"""
Message formatting utilities for Telegram bot
"""
from typing import Optional


def format_movie_list(movies: list, pagination: dict, keyword: str = None, filter_info: dict = None) -> str:
    """Format movie list for Telegram message."""
    if not movies:
        return "❌ 没有找到影片"
    
    lines = []
    
    # Header
    if keyword:
        lines.append(f"🔍 搜索: {keyword}")
    elif filter_info:
        lines.append(f"🎬 {filter_info.get('name', '')} ({filter_info.get('type', '')})")
    else:
        lines.append("🎬 影片列表")
    
    # Pagination info
    current = pagination.get("currentPage", 1)
    has_next = pagination.get("hasNextPage", False)
    lines.append(f"📄 第 {current} 页 | 共 {len(movies)} 条" + (" | 有下一页" if has_next else " | 最后一页"))
    lines.append("")
    
    # Movie list - show ALL movies
    for i, movie in enumerate(movies, 1):
        movie_id = movie.get("id", "Unknown")
        title = movie.get("title", "无标题")
        date = movie.get("date", "")
        tags = movie.get("tags", [])
        
        # Truncate title if too long
        if len(title) > 40:
            title = title[:37] + "..."
        
        tag_str = " ".join([f"[{t}]" for t in tags[:3]]) if tags else ""
        lines.append(f"{i}. `{movie_id}` {tag_str}")
        lines.append(f"   {title}")
        if date:
            lines.append(f"   📅 {date}")
        lines.append("")
    
    # Usage hints
    lines.append("━━━━━━━━━━━━━━━")
    lines.append("💡 直接发送番号可查看详情+磁力")
    
    return "\n".join(lines)


def format_movie_detail(movie: dict) -> str:
    """Format movie detail for Telegram message."""
    if "error" in movie:
        return f"❌ 错误: {movie['error']}"
    
    lines = []
    
    movie_id = movie.get("id", "Unknown")
    title = movie.get("title", "无标题")
    date = movie.get("date", "")
    duration = movie.get("videoLength", 0)
    
    lines.append(f"🎬 *{movie_id}*")
    lines.append(f"📝 {title}")
    lines.append("")
    
    if date:
        lines.append(f"📅 发行日期: {date}")
    if duration:
        lines.append(f"⏱️ 时长: {duration} 分钟")
    
    # Director
    director = movie.get("director")
    if director:
        lines.append(f"🎬 导演: {director.get('name', 'N/A')}")
    
    # Producer & Publisher
    producer = movie.get("producer")
    if producer:
        lines.append(f"🏭 制作商: {producer.get('name', 'N/A')}")
    
    publisher = movie.get("publisher")
    if publisher:
        lines.append(f"📦 发行商: {publisher.get('name', 'N/A')}")
    
    # Series
    series = movie.get("series")
    if series and series.get("name"):
        lines.append(f"📚 系列: {series.get('name')}")
    
    lines.append("")
    
    # Stars
    stars = movie.get("stars", [])
    if stars:
        star_names = [s.get("name", "") for s in stars if s.get("name")]
        if star_names:
            lines.append(f"⭐ 演员: {', '.join(star_names)}")
            # Add star IDs for quick lookup
            star_ids = [f"`{s.get('id')}`" for s in stars if s.get("id")]
            if star_ids:
                lines.append(f"   ID: {' '.join(star_ids)}")
    
    # Genres
    genres = movie.get("genres", [])
    if genres:
        genre_names = [g.get("name", "") for g in genres[:8] if g.get("name")]
        if genre_names:
            lines.append(f"🏷️ 类别: {', '.join(genre_names)}")
    
    return "\n".join(lines)


def format_magnets(magnets: list, movie_id: str) -> str:
    """Format magnet list for Telegram message."""
    if not magnets:
        return f"❌ 没有找到 `{movie_id}` 的磁力链接"
    
    if isinstance(magnets, dict) and "error" in magnets:
        return f"❌ 错误: {magnets['error']}"
    
    lines = []
    lines.append(f"🧲 *{movie_id}* 的磁力链接")
    lines.append(f"📊 共 {len(magnets)} 个链接")
    lines.append("")
    
    for i, magnet in enumerate(magnets[:5], 1):  # Limit to 5 magnets
        title = magnet.get("title", "Unknown")
        size = magnet.get("size", "N/A")
        date = magnet.get("shareDate", "")
        is_hd = magnet.get("isHD", False)
        has_sub = magnet.get("hasSubtitle", False)
        link = magnet.get("link", "")
        
        # Tags
        tags = []
        if is_hd:
            tags.append("高清")
        if has_sub:
            tags.append("字幕")
        tag_str = " ".join([f"[{t}]" for t in tags]) if tags else ""
        
        lines.append(f"*{i}. {title}* {tag_str}")
        lines.append(f"   📦 {size} | 📅 {date}")
        lines.append(f"   `{link}`")
        lines.append("")
    
    if len(magnets) > 5:
        lines.append(f"⚠️ 还有 {len(magnets) - 5} 个链接未显示")
    
    return "\n".join(lines)


def format_movie_with_magnets(movie: dict, magnets: list) -> str:
    """Format movie detail combined with best magnet links."""
    lines = []
    
    movie_id = movie.get("id", "Unknown")
    title = movie.get("title", "无标题")
    date = movie.get("date", "")
    duration = movie.get("videoLength", 0)
    
    lines.append(f"🎬 *{movie_id}*")
    lines.append(f"📝 {title}")
    lines.append("")
    
    if date:
        lines.append(f"📅 {date}")
    if duration:
        lines.append(f"⏱️ {duration} 分钟")
    
    # Stars
    stars = movie.get("stars", [])
    if stars:
        star_names = [s.get("name", "") for s in stars if s.get("name")]
        if star_names:
            lines.append(f"⭐ {', '.join(star_names)}")
    
    # Genres (short list)
    genres = movie.get("genres", [])
    if genres:
        genre_names = [g.get("name", "") for g in genres[:5] if g.get("name")]
        if genre_names:
            lines.append(f"🏷️ {', '.join(genre_names)}")
    
    lines.append("")
    lines.append("━━━━ 磁力链接 ━━━━")
    
    if not magnets:
        lines.append("❌ 暂无磁力链接")
    else:
        # Get best magnet using priority
        best_magnet = get_best_magnet(magnets)
        if best_magnet:
            is_hd = best_magnet.get("isHD", False)
            has_sub = best_magnet.get("hasSubtitle", False)
            tags = []
            if is_hd:
                tags.append("高清")
            if has_sub:
                tags.append("字幕")
            tag_str = " ".join([f"[{t}]" for t in tags]) if tags else ""
            
            lines.append(f"🏆 最佳: {best_magnet.get('size', 'N/A')} {tag_str}")
            lines.append(f"`{best_magnet.get('link', '')}`")
        
        # Show other magnets count
        if len(magnets) > 1:
            lines.append(f"\n📊 共 {len(magnets)} 个链接可用")
    
    return "\n".join(lines)


def get_best_magnet(magnets: list) -> dict | None:
    """
    Get the best magnet based on priority:
    1. HD + Subtitle (highest)
    2. Subtitle only
    3. HD only
    4. Largest size
    """
    if not magnets:
        return None
    
    hd_sub = []  # HD + Subtitle
    sub_only = []  # Subtitle only
    hd_only = []  # HD only
    others = []  # Others
    
    for m in magnets:
        is_hd = m.get("isHD", False)
        has_sub = m.get("hasSubtitle", False)
        
        if is_hd and has_sub:
            hd_sub.append(m)
        elif has_sub:
            sub_only.append(m)
        elif is_hd:
            hd_only.append(m)
        else:
            others.append(m)
    
    # Sort each category by size (largest first)
    # Handle None values safely by converting to 0
    def sort_by_size(items):
        return sorted(items, key=lambda x: x.get("numberSize") or 0, reverse=True)
    
    if hd_sub:
        return sort_by_size(hd_sub)[0]
    elif sub_only:
        return sort_by_size(sub_only)[0]
    elif hd_only:
        return sort_by_size(hd_only)[0]
    elif others:
        return sort_by_size(others)[0]
    
    return magnets[0] if magnets else None


def format_batch_magnets(results: list[dict]) -> str:
    """
    Format batch magnet results for Telegram message.
    
    Args:
        results: List of {"movie_id": str, "magnet": str, "info": str}
    """
    if not results:
        return "❌ 没有找到任何磁力链接"
    
    lines = []
    lines.append(f"🧲 *批量磁力链接*")
    lines.append(f"📊 共 {len(results)} 个影片")
    lines.append("")
    
    for item in results:
        movie_id = item.get("movie_id", "")
        magnet = item.get("magnet", "")
        info = item.get("info", "")
        
        if magnet:
            lines.append(f"`{movie_id}` {info}")
            lines.append(f"`{magnet}`")
            lines.append("")
    
    return "\n".join(lines)


def format_star(star: dict) -> str:
    """Format star detail for Telegram message."""
    if "error" in star:
        return f"❌ 错误: {star['error']}"
    
    lines = []
    
    name = star.get("name", "Unknown")
    star_id = star.get("id", "")
    
    lines.append(f"⭐ *{name}*")
    if star_id:
        lines.append(f"🆔 ID: `{star_id}`")
    lines.append("")
    
    # Basic info
    birthday = star.get("birthday")
    if birthday:
        lines.append(f"🎂 生日: {birthday}")
    
    age = star.get("age")
    if age:
        lines.append(f"📅 年龄: {age} 岁")
    
    height = star.get("height")
    if height:
        lines.append(f"📏 身高: {height}")
    
    birthplace = star.get("birthplace")
    if birthplace:
        lines.append(f"🏠 出生地: {birthplace}")
    
    lines.append("")
    
    # Measurements
    bust = star.get("bust")
    waist = star.get("waistline")
    hip = star.get("hipline")
    if bust or waist or hip:
        lines.append(f"📐 三围: {bust or 'N/A'} / {waist or 'N/A'} / {hip or 'N/A'}")
    
    # Hobby
    hobby = star.get("hobby")
    if hobby:
        lines.append(f"🎨 爱好: {hobby}")
    
    lines.append("")
    lines.append("━━━━━━━━━━━━━━━")
    lines.append(f"💡 查看作品: `/movies star {star_id}`")
    
    return "\n".join(lines)


def escape_markdown(text: str) -> str:
    """Escape special characters for Telegram MarkdownV2."""
    special_chars = ['_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '+', '-', '=', '|', '{', '}', '.', '!']
    for char in special_chars:
        text = text.replace(char, f'\\{char}')
    return text
