# type: ignore[reportMissingImports]

import json
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Awaitable, Callable, Literal
from urllib.parse import urljoin

import httpx
from selectolax.parser import HTMLParser
from sqlalchemy import DateTime, String, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

logger = logging.getLogger("uvicorn")

APOD_HTML = os.getenv("APOD_SITE_URL", "http://www.star.ucl.ac.uk/~apod/apod/")
DB_URL = "sqlite+aiosqlite:///cache.db"
CACHE_EXPIRY = timedelta(hours=12)

APP_ROUTE = "api/v1/apod"

Scope = dict[str, str]
Receive = Callable[[], Awaitable[dict]]
Send = Callable[[dict], Awaitable[None]]

ApodData = dict[Literal["img", "description", "title"], str]


class CacheDbBase(DeclarativeBase):
    pass


class Cache(CacheDbBase):
    __tablename__ = "cache"

    id: Mapped[int] = mapped_column(primary_key=True)
    date: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    img: Mapped[str] = mapped_column(String(125), nullable=True)
    description: Mapped[str] = mapped_column(String(500), nullable=True)
    title: Mapped[str] = mapped_column(String(200), nullable=True)
    expire_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)


async def get_apod_data() -> ApodData:
    """Scrap data from APOD site!"""
    async with httpx.AsyncClient() as client:
        resp = await client.get(APOD_HTML)

    out_dict: ApodData = {
        "img": "",
        "description": "",
        "title": "",
    }
    tree = HTMLParser(resp.text)

    # template based parsing (can easily break)
    first_img = tree.css("img")[0] if tree.css("img") else None
    if first_img:
        out_dict["img"] = urljoin(APOD_HTML, first_img.attributes.get("src", ""))

    centers = tree.css("center")
    second_center = centers[1] if len(centers) >= 2 else None
    if second_center:
        title_part = second_center.css("b")[0] if second_center.css("b") else None
        if title_part:
            txt = title_part.text()
            txt = " ".join(txt.split())
            out_dict["title"] = txt

        current = second_center
        while current.next:
            current = current.next
            if current.tag == "p":
                txt = current.text()
                txt = " ".join(txt.split())
                out_dict["description"] = txt
                break

    return out_dict


class App:
    def __init__(self):
        self.db_engine = create_async_engine(DB_URL, echo=False)
        self.session = async_sessionmaker(self.db_engine, expire_on_commit=False)

    async def get_response(self) -> dict[str, str]:
        out_data = {
            "img": "",
            "description": "",
            "title": "",
            "date": "",
        }
        async with self.session() as session:
            result = await session.execute(select(Cache).limit(1))
            dat = result.scalar_one_or_none()
            if dat is not None:
                if dat.expire_at < datetime.now():
                    resp = await get_apod_data()
                    _time = datetime.now(tz=timezone.utc)
                    dat.img = resp["img"]
                    dat.description = resp["description"]
                    dat.title = resp["title"]
                    dat.date = _time
                    dat.expire_at = _time + CACHE_EXPIRY
                    await session.commit()
            else:
                resp = await get_apod_data()
                _time = datetime.now(tz=timezone.utc)
                dat = Cache(
                    img=resp["img"],
                    title=resp["title"],
                    description=resp["description"],
                    date=_time,
                    expire_at=_time + CACHE_EXPIRY,
                )
                session.add(dat)
                await session.commit()
            out_data["img"] = dat.img
            out_data["description"] = dat.description
            out_data["title"] = dat.title
            out_data["date"] = dat.date.strftime("%Y-%m-%d")

        return out_data

    async def lifespan_handle(self, scope: Scope, receive: Receive, send: Send):
        while True:
            msg = await receive()
            match msg["type"]:
                case "lifespan.startup":
                    await self.on_startup()
                    await send({"type": "lifespan.startup.complete"})
                case "lifespan.shutdown":
                    await self.on_shutdown()
                    await send({"type": "lifespan.shutdown.complete"})
                case _:
                    raise ValueError(f"unknown asgi msg type: {msg['type']}!")

    async def on_startup(self):
        async with self.db_engine.begin() as conn:
            await conn.run_sync(CacheDbBase.metadata.drop_all)
            await conn.run_sync(CacheDbBase.metadata.create_all)
        logger.info("[lifetime] Startup Completed!")

    async def on_shutdown(self):
        await self.db_engine.dispose()
        logger.info("[lifetime] Shutdown Completed!")

    async def serve_req(self, scope: Scope, receive: Receive, send: Send):
        if scope["method"] not in ["GET"]:
            return await self._req_error(405, "Method Not Allowed.", send)
        if scope["path"].strip("/") != APP_ROUTE:
            return await self._req_error(404, "Not Found.", send)
        try:
            resp = await self.get_response()
            await self._req_error(200, json.dumps(resp), send, "application/json")
        except Exception as exp:
            logger.error(f"GET Error: {exp}")
            logger.exception(exp)
            await self._req_error(500, "Internal Server Error", send)

    async def __call__(self, scope: Scope, receive: Receive, send: Send):
        match scope["type"]:
            case "lifespan":
                await self.lifespan_handle(scope, receive, send)
            case "http":
                await self.serve_req(scope, receive, send)
            case _:
                await self._req_error(400, "Bad Request.", send)

    async def _req_error(
        self, status: int, msg: str, send: Send, content_type: str = "text/plain"
    ):
        await send(
            {
                "type": "http.response.start",
                "status": status,
                "headers": [
                    (b"Content-Type", content_type.encode("utf-8")),
                    (b"x-server", b"apod-api"),
                ],
            }
        )
        await send(
            {
                "type": "http.response.body",
                "body": msg.encode("utf-8"),
            }
        )


app = App()
