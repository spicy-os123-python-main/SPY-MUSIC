# SPY MUSIC — Self-Host Discord Bot & PC Audio Streamer

Host your **own Discord Bot** and **ultra-low-data PC Audio Stream** directly from your PC — completely free, no server or router port forwarding required.

## Quick Start (Click-to-Use)

1. **Create your Bot in the Discord Developer Portal**
   - Go to [discord.com/developers/applications](https://discord.com/developers/applications) -> **New Application**
   - Set **Name**, **Avatar**, and **About Me / Bio** directly in the portal
   - Open **Bot** -> click **Reset Token** and copy your Bot Token
   - Open **OAuth2 -> URL Generator**: check `bot` + `applications.commands`, select `Connect`, `Speak`, `Manage Channels`, `Send Messages`, and invite the bot to your Discord server

2. **Start the Host Script**
   - **Windows:** Double-click `start_host.bat`
   - **Linux / macOS:** Run `./start_host.sh`
   - Paste your Bot Token when asked once (saved locally in `host_config.json`, never shared anywhere).
   - *(Optional for mobile data outside home Wi-Fi)*: If [`cloudflared`](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) is installed, it automatically opens a secure zero-port tunnel URL!

3. **Pair in the SPY MUSIC App**
   - Open **Settings -> Discord Bot Host** in SPY MUSIC
   - Choose **Self-Host (Own PC)**
   - Enter the printed **Host URL** & **Session Secret**
   - To stream compressed audio from your PC (`~44 kbps`), select **Settings -> Music & Playback -> Streaming Quality -> PC Host (Under Ultra)**

## Bot Slash Commands & Player Card
- `/vc` — Join your voice channel or create one automatically
- `/play <song>` — Queue/play tracks in Voice Chat with interactive **Components v2** buttons (`Prev`, `Pause`, `Skip`, `Loop`, `Stop`, `Add Song`, `Queue`)
- `/player` — Show interactive player card anytime
- `/presence` — Switch status between GitHub Releases (default), Live Song Sync, or Custom Text/Link
