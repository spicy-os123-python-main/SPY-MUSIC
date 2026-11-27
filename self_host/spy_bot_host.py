"""SPY MUSIC Self-Host Discord Bot & Zero-Port PC Audio Streamer.

Run this on your own PC (Windows / Linux / macOS) to host your personal
Discord music bot and compress audio streams for the SPY MUSIC mobile app.
Your bot token stays strictly on your own computer.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import time
from dataclasses import dataclass, field
from typing import Any, Optional

from aiohttp import web
import discord
from discord import app_commands, ui
from discord.ext import commands
import yt_dlp


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "host_config.json")
CACHE_DIR = os.path.join(BASE_DIR, ".audio_cache")
TRYCF_RE = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")
VIDEO_ID_RE = re.compile(r"^[A-Za-z0-9_-]{6,20}$")

DEFAULT_LOGO_URL = (
    "https://raw.githubusercontent.com/spicy-os123-python-main/SPY-MUSIC/main/assets/logo/spy_music_logo.png"
)
DEFAULT_GITHUB_URL = (
    "https://github.com/spicy-os123-python-main/SPY-MUSIC/releases"
)
DEFAULT_SUPPORT_URL = "https://discord.gg/4C77NaX6y"


def load_or_setup_config() -> dict[str, Any]:
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, "r", encoding="utf-8") as fh:
            cfg = json.load(fh)
        if cfg.get("bot_token"):
            return cfg

    print("\n=== SPY MUSIC Self-Host Setup ===")
    print("Create your Bot at: https://discord.com/developers/applications")
    print("Customize bot Name, Avatar & Bio there whenever you like.\n")

    token = ""
    while not token:
        token = input("Paste your Discord Bot Token: ").strip().strip('"').strip("'")
        if "." not in token or len(token) < 30:
            print("That does not look like a valid Discord Bot Token. Try again.")
            token = ""

    port_raw = input("Local Port [8771]: ").strip()
    port = int(port_raw) if port_raw.isdigit() else 8771

    cfg = {
        "bot_token": token,
        "session_secret": f"SPYSESS-{secrets.token_urlsafe(18)}",
        "port": port,
        "presence": {"mode": "github", "text": "", "url": ""},
    }
    save_config(cfg)
    return cfg


def save_config(cfg: dict[str, Any]) -> None:
    os.makedirs(BASE_DIR, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, indent=2)
    try:
        os.chmod(CONFIG_PATH, 0o600)
    except OSError:
        pass


def get_lan_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except OSError:
        return "127.0.0.1"


@dataclass
class TrackInfo:
    video_id: str
    title: str
    artist: str
    stream_url: str
    duration_sec: int = 0
    thumbnail_url: Optional[str] = None


def format_duration(seconds: int) -> str:
    if seconds <= 0:
        return "Live"
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def build_activity(
    presence: dict[str, Any],
    now_playing: Optional[dict[str, Any]] = None,
) -> discord.BaseActivity:
    mode = str(presence.get("mode") or "github").lower()
    if mode == "now_playing" and now_playing and now_playing.get("title"):
        t = str(now_playing.get("title") or "").strip()
        a = str(now_playing.get("artist") or "").strip()
        label = f"{t} - {a}" if a else t
        return discord.Activity(type=discord.ActivityType.listening, name=label[:120])
    if mode == "custom":
        text = str(presence.get("text") or "").strip()
        url = str(presence.get("url") or "").strip()
        label = f"{text} • {url}" if (text and url) else (text or url or DEFAULT_GITHUB_URL)
        return discord.Activity(type=discord.ActivityType.listening, name=label[:120])
    return discord.Activity(type=discord.ActivityType.listening, name=DEFAULT_GITHUB_URL)


def _extract_sync(target: str) -> Optional[TrackInfo]:
    opts = {
        "format": "bestaudio/best",
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "default_search": "ytsearch1",
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(target, download=False)
        if not info:
            return None
        if "entries" in info and info["entries"]:
            info = info["entries"][0]
        if not info or not info.get("url"):
            return None
        return TrackInfo(
            video_id=str(info.get("id") or hashlib.sha1(target.encode()).hexdigest()[:11]),
            title=str(info.get("title") or "Unknown Track"),
            artist=str(info.get("artist") or info.get("uploader") or info.get("channel") or "Unknown Artist"),
            stream_url=str(info["url"]),
            duration_sec=int(info.get("duration") or 0),
            thumbnail_url=info.get("thumbnail"),
        )


class LocalAudioStreamer:
    def __init__(self, cache_dir: str) -> None:
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)
        self._sem = asyncio.Semaphore(3)
        self._inflight: dict[str, asyncio.Task[str]] = {}
        self._resolved: dict[str, tuple[float, TrackInfo]] = {}

    async def resolve(self, query_or_id: str) -> Optional[TrackInfo]:
        clean = query_or_id.strip()
        if not clean:
            return None
        if VIDEO_ID_RE.match(clean) and not clean.startswith(("sp_", "sc_", "az_")):
            target = f"https://www.youtube.com/watch?v={clean}"
        elif clean.startswith(("http://", "https://")):
            target = clean
        else:
            target = f"ytsearch1:{clean}"

        cached = self._resolved.get(target)
        if cached and time.time() - cached[0] < 1800:
            return cached[1]
        res = await asyncio.to_thread(_extract_sync, target)
        if res:
            self._resolved[target] = (time.time(), res)
        return res

    async def transcode_m4a(
        self,
        video_id: Optional[str],
        query: Optional[str],
        bitrate: int = 44,
    ) -> Optional[str]:
        br = max(24, min(96, int(bitrate)))
        lookup = (video_id or "").strip()
        if lookup.startswith("MPED"):
            lookup = lookup[4:]
        use_query = bool(query and query.strip()) and (
            not lookup or lookup.startswith(("sp_", "sc_", "az_", "dev_", "rec_"))
        )
        seed = query.strip() if use_query else lookup
        if not seed:
            return None

        cache_id = hashlib.sha256(f"{seed}:{br}".encode("utf-8")).hexdigest()[:24]
        out_path = os.path.join(self.cache_dir, f"{cache_id}.m4a")
        if os.path.exists(out_path) and os.path.getsize(out_path) > 4096:
            return out_path
        if cache_id in self._inflight:
            return await self._inflight[cache_id]

        async def _run() -> str:
            track = await self.resolve(query.strip() if use_query else lookup)
            if not track or not track.stream_url:
                raise RuntimeError("No stream resolved.")
            tmp = os.path.join(self.cache_dir, f".{cache_id}.tmp.m4a")
            async with self._sem:
                proc = await asyncio.create_subprocess_exec(
                    "ffmpeg", "-y", "-loglevel", "error",
                    "-reconnect", "1", "-reconnect_streamed", "1",
                    "-i", track.stream_url,
                    "-vn", "-c:a", "aac", "-b:a", f"{br}k",
                    "-ac", "2", "-ar", "44100", "-movflags", "+faststart",
                    "-f", "mp4", tmp,
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.PIPE,
                )
                _, err = await asyncio.wait_for(proc.communicate(), timeout=60)
                if proc.returncode != 0 or not os.path.exists(tmp):
                    raise RuntimeError(err.decode("utf-8", "ignore"))
                os.replace(tmp, out_path)
                return out_path

        task = asyncio.create_task(_run())
        self._inflight[cache_id] = task
        try:
            return await task
        except Exception:
            return None
        finally:
            self._inflight.pop(cache_id, None)


@dataclass
class GuildPlayerState:
    guild_id: int
    queue: list[TrackInfo] = field(default_factory=list)
    history: list[TrackInfo] = field(default_factory=list)
    current: Optional[TrackInfo] = None
    paused: bool = False
    loop: bool = False
    vc_name: str = "Not connected"
    panel_channel_id: Optional[int] = None
    panel_message_id: Optional[int] = None


def notice_view(title: str, body: str, *, error: bool = False) -> ui.LayoutView:
    v = ui.LayoutView(timeout=180)
    v.add_item(
        ui.Container(
            ui.TextDisplay(f"### {title}"),
            ui.TextDisplay(body),
            accent_colour=0xEF4444 if error else 0x00D2FF,
        )
    )
    return v


def queue_view(state: GuildPlayerState) -> ui.LayoutView:
    lines: list[str] = []
    if state.current:
        lines.append(f"**Now:** {state.current.title} — {state.current.artist}")
    if not state.queue:
        lines.append("_Queue is empty._")
    else:
        for i, item in enumerate(state.queue[:12], 1):
            lines.append(f"`{i}.` {item.title[:60]} — {item.artist[:30]}")
    v = ui.LayoutView(timeout=120)
    v.add_item(
        ui.Container(
            ui.TextDisplay("### Current Queue"),
            ui.Separator(),
            ui.TextDisplay("\n".join(lines)),
            accent_colour=0x00D2FF,
        )
    )
    return v


class SelfAddModal(ui.Modal, title="Add Song to Queue"):
    query = ui.TextInput(
        label="Song Name or YouTube URL",
        placeholder="e.g. Lucid Dreams - Juice WRLD",
        required=True,
        max_length=180,
    )

    def __init__(self, bot: "SelfHostBot", guild_id: int) -> None:
        super().__init__(timeout=180)
        self.bot = bot
        self.guild_id = guild_id

    async def on_submit(self, interaction: discord.Interaction) -> None:
        await interaction.response.defer(ephemeral=True)
        err, tr = await self.bot.queue_track(interaction, str(self.query.value))
        if err or tr is None:
            await interaction.followup.send(
                view=notice_view("Playback Error", err or "Track unavailable.", error=True),
                ephemeral=True,
            )
            return
        await interaction.followup.send(
            view=notice_view("Added to Queue", f"**{tr.title}**\n{tr.artist}"),
            ephemeral=True,
        )


class SelfPlayerView(ui.LayoutView):
    def __init__(self, bot: "SelfHostBot", guild_id: int, state: GuildPlayerState) -> None:
        super().__init__(timeout=None)
        self.bot = bot
        self.guild_id = guild_id
        tr = state.current
        status = "Paused" if state.paused else ("Playing" if tr else "Idle")
        title = tr.title[:95] if tr else "Nothing Playing"
        meta = f"{tr.artist} • {format_duration(tr.duration_sec)}" if tr else "Use Add Song or /play"
        thumb = (tr.thumbnail_url if tr else None) or DEFAULT_LOGO_URL
        up_next = f"Up Next ({len(state.queue)}): **{state.queue[0].title[:55]}**" if state.queue else "Queue: Empty"

        b_prev = ui.Button(label="Prev", style=discord.ButtonStyle.secondary, custom_id=f"sh:{guild_id}:prev", disabled=not state.history)
        b_tog = ui.Button(label="Resume" if state.paused else "Pause", style=discord.ButtonStyle.primary, custom_id=f"sh:{guild_id}:tog", disabled=tr is None)
        b_skip = ui.Button(label="Skip", style=discord.ButtonStyle.secondary, custom_id=f"sh:{guild_id}:skip", disabled=tr is None)
        b_loop = ui.Button(label="Loop: On" if state.loop else "Loop", style=discord.ButtonStyle.success if state.loop else discord.ButtonStyle.secondary, custom_id=f"sh:{guild_id}:loop")
        b_stop = ui.Button(label="Stop", style=discord.ButtonStyle.danger, custom_id=f"sh:{guild_id}:stop")

        b_add = ui.Button(label="Add Song", style=discord.ButtonStyle.primary, custom_id=f"sh:{guild_id}:add")
        b_q = ui.Button(label=f"Queue ({len(state.queue)})", style=discord.ButtonStyle.secondary, custom_id=f"sh:{guild_id}:q")
        b_vc = ui.Button(label="Join / Create VC", style=discord.ButtonStyle.secondary, custom_id=f"sh:{guild_id}:vc")

        b_prev.callback = self._prev
        b_tog.callback = self._tog
        b_skip.callback = self._skip
        b_loop.callback = self._loop
        b_stop.callback = self._stop
        b_add.callback = self._add
        b_q.callback = self._q
        b_vc.callback = self._vc

        self.add_item(
            ui.Container(
                ui.TextDisplay(f"### SPY MUSIC Player\n`{status}` • Voice: **{state.vc_name}**"),
                ui.Separator(),
                ui.Section(
                    ui.TextDisplay(f"**{title}**"),
                    ui.TextDisplay(meta),
                    ui.TextDisplay(up_next),
                    accessory=ui.Thumbnail(thumb),
                ),
                ui.Separator(),
                ui.ActionRow(b_prev, b_tog, b_skip, b_loop, b_stop),
                ui.ActionRow(b_add, b_q, b_vc),
                accent_colour=0x00D2FF,
            )
        )

    async def _edit(self, interaction: discord.Interaction) -> None:
        st = self.bot.state(self.guild_id)
        await interaction.response.edit_message(view=SelfPlayerView(self.bot, self.guild_id, st))

    async def _prev(self, i: discord.Interaction) -> None:
        if not await self.bot.play_prev(self.guild_id):
            await i.response.send_message(view=notice_view("Empty", "No previous track.", error=True), ephemeral=True)
            return
        await self._edit(i)

    async def _tog(self, i: discord.Interaction) -> None:
        vc = i.guild.voice_client if i.guild else None
        st = self.bot.state(self.guild_id)
        if vc and vc.is_playing():
            vc.pause()
            st.paused = True
        elif vc and vc.is_paused():
            vc.resume()
            st.paused = False
        await self._edit(i)

    async def _skip(self, i: discord.Interaction) -> None:
        vc = i.guild.voice_client if i.guild else None
        if vc and (vc.is_playing() or vc.is_paused()):
            vc.stop()
        await asyncio.sleep(0.15)
        await self._edit(i)

    async def _loop(self, i: discord.Interaction) -> None:
        st = self.bot.state(self.guild_id)
        st.loop = not st.loop
        await self._edit(i)

    async def _stop(self, i: discord.Interaction) -> None:
        await self.bot.leave_guild(self.guild_id)
        await self._edit(i)

    async def _add(self, i: discord.Interaction) -> None:
        await i.response.send_modal(SelfAddModal(self.bot, self.guild_id))

    async def _q(self, i: discord.Interaction) -> None:
        await i.response.send_message(view=queue_view(self.bot.state(self.guild_id)), ephemeral=True)

    async def _vc(self, i: discord.Interaction) -> None:
        err, _ = await self.bot.ensure_vc(i)
        if err:
            await i.response.send_message(view=notice_view("Voice Channel", err, error=True), ephemeral=True)
            return
        await self._edit(i)


class SelfHostBot(commands.Bot):
    def __init__(self, cfg: dict[str, Any], streamer: LocalAudioStreamer) -> None:
        intents = discord.Intents.default()
        intents.guilds = True
        intents.voice_states = True
        super().__init__(command_prefix="!", intents=intents)
        self.cfg = cfg
        self.streamer = streamer
        self.now_playing: Optional[dict[str, Any]] = None
        self.states: dict[int, GuildPlayerState] = {}
        self._register_commands()

    def state(self, gid: int) -> GuildPlayerState:
        return self.states.setdefault(gid, GuildPlayerState(gid))

    async def apply_presence(self) -> None:
        try:
            await self.change_presence(
                status=discord.Status.online,
                activity=build_activity(self.cfg.get("presence") or {}, self.now_playing),
            )
        except Exception:
            pass

    async def setup_hook(self) -> None:
        try:
            await self.tree.sync()
        except Exception as exc:
            print(f"[SelfHost] Slash sync error: {exc}")

    async def on_ready(self) -> None:
        await self.apply_presence()
        print(f"[SelfHost] Discord Bot online as {self.user}")

    async def ensure_vc(
        self,
        interaction: discord.Interaction,
        channel: Optional[discord.VoiceChannel] = None,
        create_name: Optional[str] = None,
    ) -> tuple[Optional[str], Optional[str]]:
        guild = interaction.guild
        if not guild:
            return "Use this command inside a Discord server.", None
        dest = channel
        if create_name and create_name.strip():
            try:
                dest = await guild.create_voice_channel(create_name.strip()[:80])
            except discord.Forbidden:
                return "Missing Manage Channels permission to create a voice channel.", None
        if dest is None and isinstance(interaction.user, discord.Member) and interaction.user.voice:
            if isinstance(interaction.user.voice.channel, discord.VoiceChannel):
                dest = interaction.user.voice.channel
        if dest is None:
            dest = discord.utils.get(guild.voice_channels, name="SPY MUSIC")
            if dest is None:
                try:
                    dest = await guild.create_voice_channel("SPY MUSIC")
                except discord.Forbidden:
                    return "Join a voice channel or grant Manage Channels permission.", None
        try:
            vc = guild.voice_client
            if vc and vc.is_connected():
                if vc.channel and vc.channel.id != dest.id:
                    await vc.move_to(dest)
            else:
                await dest.connect(timeout=15.0, reconnect=True)
            self.state(guild.id).vc_name = dest.name
            return None, dest.name
        except Exception as exc:
            return f"Failed to join `{dest.name}`: {exc}", None

    async def leave_guild(self, gid: int) -> None:
        st = self.state(gid)
        st.queue.clear()
        st.current = None
        st.paused = False
        st.vc_name = "Not connected"
        g = self.get_guild(gid)
        if g and g.voice_client:
            try:
                await g.voice_client.disconnect(force=True)
            except Exception:
                pass

    async def play_next(self, gid: int) -> None:
        st = self.state(gid)
        g = self.get_guild(gid)
        vc = g.voice_client if g else None
        if not vc or not vc.is_connected():
            return
        if st.loop and st.current:
            nxt = st.current
        elif st.queue:
            if st.current:
                st.history.append(st.current)
            nxt = st.queue.pop(0)
        else:
            st.current = None
            st.paused = False
            await self.refresh_panel(gid)
            return

        resolved = await self.streamer.resolve(nxt.video_id) or nxt
        st.current = resolved
        st.paused = False
        src = discord.FFmpegOpusAudio(
            resolved.stream_url,
            bitrate=96,
            before_options="-reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5",
            options="-vn",
        )
        vc.play(src, after=lambda e: asyncio.run_coroutine_threadsafe(self.play_next(gid), self.loop))
        if (self.cfg.get("presence") or {}).get("mode") == "now_playing":
            self.now_playing = {"title": resolved.title, "artist": resolved.artist}
            await self.apply_presence()
        await self.refresh_panel(gid)

    async def play_prev(self, gid: int) -> bool:
        st = self.state(gid)
        if not st.history:
            return False
        prev = st.history.pop()
        if st.current:
            st.queue.insert(0, st.current)
        st.current = None
        st.queue.insert(0, prev)
        g = self.get_guild(gid)
        vc = g.voice_client if g else None
        if vc and (vc.is_playing() or vc.is_paused()):
            vc.stop()
        else:
            await self.play_next(gid)
        return True

    async def refresh_panel(self, gid: int) -> None:
        st = self.state(gid)
        if not st.panel_channel_id or not st.panel_message_id:
            return
        ch = self.get_channel(st.panel_channel_id)
        if isinstance(ch, discord.abc.Messageable):
            try:
                m = await ch.fetch_message(st.panel_message_id)
                await m.edit(view=SelfPlayerView(self, gid, st))
            except Exception:
                pass

    async def queue_track(self, i: discord.Interaction, query: str) -> tuple[Optional[str], Optional[TrackInfo]]:
        if not i.guild:
            return "Server only.", None
        err, _ = await self.ensure_vc(i)
        if err:
            return err, None
        tr = await self.streamer.resolve(query)
        if not tr:
            return f"No track found for `{query}`.", None
        st = self.state(i.guild.id)
        st.queue.append(tr)
        vc = i.guild.voice_client
        if vc and not vc.is_playing() and not vc.is_paused():
            await self.play_next(i.guild.id)
        else:
            await self.refresh_panel(i.guild.id)
        return None, tr

    def _register_commands(self) -> None:
        @self.tree.command(name="vc", description="Join or create a voice channel for SPY MUSIC")
        @app_commands.allowed_contexts(guilds=True, dms=False, private_channels=False)
        @app_commands.allowed_installs(guilds=True, users=True)
        async def cmd_vc(i: discord.Interaction, channel: Optional[discord.VoiceChannel] = None, create_name: Optional[str] = None) -> None:
            await i.response.defer()
            err, _ = await self.ensure_vc(i, channel, create_name)
            if err:
                await i.followup.send(view=notice_view("Voice Channel", err, error=True), ephemeral=True)
                return
            st = self.state(i.guild_id or 0)
            msg = await i.followup.send(view=SelfPlayerView(self, i.guild_id or 0, st))
            if msg and i.channel_id:
                st.panel_channel_id, st.panel_message_id = i.channel_id, msg.id

        @self.tree.command(name="play", description="Play a track or URL in voice chat")
        @app_commands.allowed_contexts(guilds=True, dms=False, private_channels=False)
        @app_commands.allowed_installs(guilds=True, users=True)
        async def cmd_play(i: discord.Interaction, query: str) -> None:
            await i.response.defer()
            err, tr = await self.queue_track(i, query)
            if err or not tr:
                await i.followup.send(view=notice_view("Playback Error", err or "Failed.", error=True), ephemeral=True)
                return
            st = self.state(i.guild_id or 0)
            msg = await i.followup.send(view=SelfPlayerView(self, i.guild_id or 0, st))
            if msg and i.channel_id:
                st.panel_channel_id, st.panel_message_id = i.channel_id, msg.id

        @self.tree.command(name="player", description="Show interactive SPY MUSIC player card")
        @app_commands.allowed_contexts(guilds=True, dms=False, private_channels=False)
        @app_commands.allowed_installs(guilds=True, users=True)
        async def cmd_player(i: discord.Interaction) -> None:
            if not i.guild_id:
                await i.response.send_message(view=notice_view("Server Only", "Use inside a server.", error=True), ephemeral=True)
                return
            st = self.state(i.guild_id)
            await i.response.send_message(view=SelfPlayerView(self, i.guild_id, st))
            sent = await i.original_response()
            if i.channel_id:
                st.panel_channel_id, st.panel_message_id = i.channel_id, sent.id

        @self.tree.command(name="queue", description="Show current queue")
        @app_commands.allowed_contexts(guilds=True, dms=False, private_channels=False)
        @app_commands.allowed_installs(guilds=True, users=True)
        async def cmd_queue(i: discord.Interaction) -> None:
            await i.response.send_message(view=queue_view(self.state(i.guild_id or 0)), ephemeral=True)

        @self.tree.command(name="skip", description="Skip current song")
        @app_commands.allowed_contexts(guilds=True, dms=False, private_channels=False)
        @app_commands.allowed_installs(guilds=True, users=True)
        async def cmd_skip(i: discord.Interaction) -> None:
            vc = i.guild.voice_client if i.guild else None
            if vc and (vc.is_playing() or vc.is_paused()):
                vc.stop()
                await i.response.send_message(view=notice_view("Skipped", "Moved to next song."), ephemeral=True)
            else:
                await i.response.send_message(view=notice_view("Idle", "Nothing playing.", error=True), ephemeral=True)

        @self.tree.command(name="pause", description="Pause or resume playback")
        @app_commands.allowed_contexts(guilds=True, dms=False, private_channels=False)
        @app_commands.allowed_installs(guilds=True, users=True)
        async def cmd_pause(i: discord.Interaction) -> None:
            vc = i.guild.voice_client if i.guild else None
            st = self.state(i.guild_id or 0)
            if vc and vc.is_playing():
                vc.pause()
                st.paused = True
                lbl = "Paused"
            elif vc and vc.is_paused():
                vc.resume()
                st.paused = False
                lbl = "Resumed"
            else:
                lbl = "Nothing playing"
            await self.refresh_panel(i.guild_id or 0)
            await i.response.send_message(view=notice_view("Playback", lbl), ephemeral=True)

        @self.tree.command(name="leave", description="Stop playback and leave voice chat")
        @app_commands.allowed_contexts(guilds=True, dms=False, private_channels=False)
        @app_commands.allowed_installs(guilds=True, users=True)
        async def cmd_leave(i: discord.Interaction) -> None:
            await self.leave_guild(i.guild_id or 0)
            await self.refresh_panel(i.guild_id or 0)
            await i.response.send_message(view=notice_view("Disconnected", "Left voice chat."), ephemeral=True)

        @self.tree.command(name="presence", description="Customize your bot status and activity")
        @app_commands.allowed_contexts(guilds=True, dms=True, private_channels=True)
        @app_commands.allowed_installs(guilds=True, users=True)
        @app_commands.choices(
            mode=[
                app_commands.Choice(name="GitHub Releases (Default)", value="github"),
                app_commands.Choice(name="Live Current Song", value="now_playing"),
                app_commands.Choice(name="Custom Text / Link", value="custom"),
            ]
        )
        async def cmd_presence(
            i: discord.Interaction,
            mode: app_commands.Choice[str],
            text: Optional[str] = None,
            url: Optional[str] = None,
        ) -> None:
            self.cfg["presence"] = {
                "mode": mode.value,
                "text": (text or "").strip(),
                "url": (url or "").strip(),
            }
            save_config(self.cfg)
            await self.apply_presence()
            await i.response.send_message(
                view=notice_view("Presence Updated", f"Active mode: **{mode.name}**"),
                ephemeral=True,
            )

        @self.tree.command(name="help", description="List SPY MUSIC bot commands")
        @app_commands.allowed_contexts(guilds=True, dms=True, private_channels=True)
        @app_commands.allowed_installs(guilds=True, users=True)
        async def cmd_help(i: discord.Interaction) -> None:
            v = ui.LayoutView(timeout=120)
            v.add_item(
                ui.Container(
                    ui.TextDisplay("### SPY MUSIC Self-Host Bot"),
                    ui.Separator(),
                    ui.TextDisplay("`/vc` `/play` `/player` `/queue` `/skip` `/pause` `/leave` `/presence`"),
                    ui.ActionRow(
                        ui.Button(label="GitHub Releases", url=DEFAULT_GITHUB_URL),
                        ui.Button(label="Support Discord", url=DEFAULT_SUPPORT_URL),
                    ),
                    accent_colour=0x00D2FF,
                )
            )
            await i.response.send_message(view=v, ephemeral=True)


def create_app(bot: SelfHostBot, cfg: dict[str, Any]) -> web.Application:
    app = web.Application()
    secret = str(cfg.get("session_secret") or "")

    def _authorized(req: web.Request) -> bool:
        hdr = req.headers.get("X-Host-Secret", "").strip()
        return bool(secret) and secrets.compare_digest(hdr, secret)

    async def health(_: web.Request) -> web.Response:
        return web.json_response(
            {
                "ok": True,
                "mode": "self_host",
                "botUsername": str(bot.user) if bot.user else None,
            }
        )

    async def verify(req: web.Request) -> web.Response:
        if not _authorized(req):
            return web.json_response({"ok": False, "error": "Invalid session secret."}, status=401)
        return web.json_response(
            {
                "ok": True,
                "mode": "self_host",
                "hostRunning": bot.is_ready(),
                "botUsername": str(bot.user) if bot.user else None,
            }
        )

    async def update_presence(req: web.Request) -> web.Response:
        if not _authorized(req):
            return web.json_response({"ok": False, "error": "Unauthorized"}, status=401)
        body = await req.json()
        if isinstance(body.get("presence"), dict):
            bot.cfg["presence"] = body["presence"]
            save_config(bot.cfg)
        if "nowPlaying" in body:
            bot.now_playing = body.get("nowPlaying")
        await bot.apply_presence()
        return web.json_response({"ok": True})

    async def stream_audio(req: web.Request) -> web.StreamResponse:
        if not _authorized(req):
            return web.json_response({"ok": False, "error": "Unauthorized"}, status=401)
        vid = req.query.get("videoId")
        q = req.query.get("q")
        br = int(req.query.get("bitrate", "44") or "44")
        path = await bot.streamer.transcode_m4a(vid, q, bitrate=br)
        if not path or not os.path.exists(path):
            return web.json_response({"ok": False, "error": "Audio unavailable."}, status=404)
        return web.FileResponse(path, headers={"Content-Type": "audio/mp4", "Accept-Ranges": "bytes"})

    app.router.add_get("/api/health", health)
    app.router.add_post("/api/key/verify", verify)
    app.router.add_post("/api/host/presence", update_presence)
    app.router.add_get("/api/audio/stream", stream_audio)
    return app


def start_optional_tunnel(port: int) -> Optional[subprocess.Popen[str]]:
    exe = shutil.which("cloudflared") or (
        os.path.join(BASE_DIR, "cloudflared.exe")
        if os.path.exists(os.path.join(BASE_DIR, "cloudflared.exe"))
        else None
    )
    if not exe:
        return None
    return subprocess.Popen(
        [exe, "tunnel", "--no-autoupdate", "--url", f"http://127.0.0.1:{port}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )


async def main() -> None:
    cfg = load_or_setup_config()
    port = int(cfg.get("port") or 8771)
    streamer = LocalAudioStreamer(CACHE_DIR)
    bot = SelfHostBot(cfg, streamer)

    app = create_app(bot, cfg)
    runner = web.AppRunner(app)
    await runner.setup()
    await web.TCPSite(runner, "0.0.0.0", port).start()

    lan_url = f"http://{get_lan_ip()}:{port}"
    print("\n==========================================")
    print(" SPY MUSIC Self-Host Running!")
    print(f" Session Secret : {cfg['session_secret']}")
    print(f" Local Wi-Fi URL: {lan_url}")
    print("==========================================")

    tunnel_proc = start_optional_tunnel(port)
    if tunnel_proc and tunnel_proc.stdout:
        async def _watch_tunnel() -> None:
            while tunnel_proc.poll() is None:
                line = await asyncio.to_thread(tunnel_proc.stdout.readline)
                if not line:
                    break
                m = TRYCF_RE.search(line)
                if m:
                    print(f"\n[Zero-Port Tunnel URL] -> {m.group(0)}")
                    print("Paste this URL + Session Secret into SPY MUSIC Settings -> Discord Bot Host!\n")
        asyncio.create_task(_watch_tunnel())
    else:
        print("Tip: Install 'cloudflared' to stream away from home Wi-Fi with zero open ports.")

    try:
        await bot.start(str(cfg["bot_token"]))
    finally:
        if tunnel_proc and tunnel_proc.poll() is None:
            tunnel_proc.terminate()
        await runner.cleanup()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nStopped cleanly.")
