"""
JavBus API Client - Async HTTP client for all API endpoints
"""
import asyncio
import logging
import aiohttp
from typing import Optional

from config import API_AUTH_TOKEN

logger = logging.getLogger(__name__)

# Timeout: 20s total, 10s for connection
REQUEST_TIMEOUT = aiohttp.ClientTimeout(total=20, connect=10)
# Max retries for failed requests
MAX_RETRIES = 1
# Delay between retries (seconds)
RETRY_DELAY = 2


class JavBusAPIClient:
    """Async client for JavBus API"""

    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.headers = {}
        if API_AUTH_TOKEN:
            self.headers["j-auth-token"] = API_AUTH_TOKEN

    async def _request(self, endpoint: str, params: Optional[dict] = None) -> dict | list | None:
        """Make an async GET request to the API with timeout and retry."""
        url = f"{self.base_url}{endpoint}"

        for attempt in range(MAX_RETRIES + 1):
            try:
                async with aiohttp.ClientSession(
                    timeout=REQUEST_TIMEOUT
                ) as session:
                    async with session.get(
                        url, params=params, headers=self.headers
                    ) as response:
                        if response.status == 200:
                            return await response.json()
                        else:
                            error_msg = f"API returned status {response.status}"
                            if attempt < MAX_RETRIES:
                                logger.warning(
                                    f"{url} — {error_msg}, retrying in {RETRY_DELAY}s..."
                                )
                                await asyncio.sleep(RETRY_DELAY)
                                continue
                            return {"error": error_msg}

            except asyncio.TimeoutError:
                if attempt < MAX_RETRIES:
                    logger.warning(f"{url} — timeout, retrying in {RETRY_DELAY}s...")
                    await asyncio.sleep(RETRY_DELAY)
                    continue
                return {"error": "请求超时"}

            except aiohttp.ClientError as e:
                if attempt < MAX_RETRIES:
                    logger.warning(f"{url} — {e}, retrying in {RETRY_DELAY}s...")
                    await asyncio.sleep(RETRY_DELAY)
                    continue
                return {"error": f"网络请求失败: {str(e)}"}

            except Exception as e:
                return {"error": f"请求异常: {str(e)}"}

        return {"error": "请求失败"}

    async def get_movies(
        self,
        page: int = 1,
        magnet: str = "exist",
        filter_type: Optional[str] = None,
        filter_value: Optional[str] = None,
        movie_type: str = "normal"
    ) -> dict | None:
        """
        Get movie list with optional filters.

        Args:
            page: Page number (default: 1)
            magnet: "exist" for movies with magnets, "all" for all movies
            filter_type: star, genre, director, studio, label, or series
            filter_value: ID value for the filter type
            movie_type: "normal" for censored, "uncensored" for uncensored
        """
        params = {"page": page, "magnet": magnet}
        if filter_type and filter_value:
            params["filterType"] = filter_type
            params["filterValue"] = filter_value
        if movie_type == "uncensored":
            params["type"] = "uncensored"
        return await self._request("/api/movies", params)

    async def search_movies(
        self,
        keyword: str,
        page: int = 1,
        magnet: str = "exist",
        movie_type: str = "normal"
    ) -> dict | None:
        """
        Search movies by keyword.

        Args:
            keyword: Search keyword
            page: Page number (default: 1)
            magnet: "exist" for movies with magnets, "all" for all movies
            movie_type: "normal" for censored, "uncensored" for uncensored
        """
        params = {"keyword": keyword, "page": page, "magnet": magnet}
        if movie_type == "uncensored":
            params["type"] = "uncensored"
        return await self._request("/api/movies/search", params)

    async def get_movie_detail(self, movie_id: str) -> dict | None:
        """
        Get detailed information for a specific movie.

        Args:
            movie_id: Movie ID (e.g., "SSIS-406")
        """
        return await self._request(f"/api/movies/{movie_id}")

    async def get_magnets(
        self,
        movie_id: str,
        gid: str,
        uc: str,
        sort_by: str = "size",
        sort_order: str = "desc"
    ) -> list | dict | None:
        """
        Get magnet links for a movie.

        Args:
            movie_id: Movie ID
            gid: GID from movie detail
            uc: UC from movie detail
            sort_by: "date" or "size"
            sort_order: "asc" or "desc"
        """
        params = {
            "gid": gid,
            "uc": uc,
            "sortBy": sort_by,
            "sortOrder": sort_order
        }
        return await self._request(f"/api/magnets/{movie_id}", params)

    async def get_star(self, star_id: str, star_type: str = "normal") -> dict | None:
        """
        Get star/actress details.

        Args:
            star_id: Star ID (e.g., "2xi")
            star_type: "normal" for censored, "uncensored" for uncensored
        """
        params = {}
        if star_type == "uncensored":
            params["type"] = "uncensored"
        return await self._request(f"/api/stars/{star_id}", params)
