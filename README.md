# ssh-tunnel-local-proxy

Use an **SSH reverse tunnel** so a remote server (AutoDL, cloud VM, etc.) sends outbound HTTP(S) traffic through your **local** Clash / proxy client.

```
Remote curl/pip/agent  →  127.0.0.1:7890  →  SSH -R  →  local Clash  →  Internet
```

Two scripts, run on different machines:

| Script | Where | Role |
|--------|-------|------|
| `tunnel-local.sh` | **Local** (your laptop) | `ssh -R` forwards remote `:7890` to local Clash |
| `proxy-server.sh` | **Remote** server | Sets `HTTP_PROXY` / `HTTPS_PROXY` to `127.0.0.1:7890` |

---

## Local setup (your machine)

**Requirements:** Clash (or any HTTP proxy) with **mixed-port `7890`** on `127.0.0.1`.

```bash
git clone https://github.com/TAOYUZHOU/ssh-tunnel-local-proxy.git
cd ssh-tunnel-local-proxy
chmod +x tunnel-local.sh proxy-server.sh

cp config.example config.local
# Edit config.local — copy host/port from your cloud SSH login command
```

`config.local` example:

```bash
REMOTE_HOST=region-xxx.autodl.com
REMOTE_PORT=42151
REMOTE_USER=root
LOCAL_PROXY_PORT=7890    # Clash mixed-port
REMOTE_PROXY_PORT=7890   # port opened on remote 127.0.0.1
```

Start Clash, then start the tunnel:

```bash
./tunnel-local.sh              # foreground (keep terminal open)
./tunnel-local.sh --background # background + log to tunnel-local.log
```

Equivalent manual command:

```bash
ssh -CNg -R 7890:127.0.0.1:7890 -p <PORT> root@<HOST>
```

---

## Remote setup (AutoDL / cloud VM)

Copy `proxy-server.sh` to the server (or clone the repo there).

**One-time (persist in new shells):**

```bash
chmod +x proxy-server.sh
./proxy-server.sh on --persist
./proxy-server.sh test
```

**Current shell only:**

```bash
./proxy-server.sh on
source ~/.local-proxy.env
```

**Check / disable:**

```bash
./proxy-server.sh status
./proxy-server.sh off
```

This writes `~/.local-proxy.env` and optionally appends a block to `~/.bashrc`. Tools that respect `HTTP_PROXY` / `HTTPS_PROXY` (curl, pip, npm, many agents) will use the tunnel automatically.

---

## Typical workflow

1. **Local:** start Clash → `./tunnel-local.sh`
2. **Remote:** `./proxy-server.sh on` (or `--persist` once)
3. **Remote:** `curl https://ipinfo.io/ip` — should show your **local egress IP**
4. When done: remote `./proxy-server.sh off`; local Ctrl+C tunnel (or kill background ssh)

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `7890 not reachable` on remote | Tunnel not running locally, or SSH disconnected |
| Local error “proxy not listening” | Start Clash first; confirm mixed-port is `7890` |
| curl works with `--proxy` but not in shell | Run `./proxy-server.sh on` or `source ~/.local-proxy.env` |
| Tunnel drops | Use `--background` + keepalive options (already in script) |

Remote check:

```bash
ss -tln | grep 7890
./proxy-server.sh status
```

---

## Notes

- Only **one port** (`7890` by default) is forwarded. Set `ALL_PROXY` to the same HTTP URL — do not point at a local SOCKS port unless you forward it separately.
- `NO_PROXY` skips localhost and private networks.
- `config.local` is gitignored; never commit SSH credentials.

## License

MIT
