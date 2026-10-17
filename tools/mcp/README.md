# Cloud sessions to Roblox Studio

A Claude cloud session (claude.ai/code) drives Roblox Studio on a person's own PC through an ngrok
tunnel. Each person has their own tunnel and token; the repo is shared.

```
cloud session --HTTPS--> your ngrok domain --> localhost:58741 on your PC (Studio connector) --> Studio plugin
```

## How the repo finds your PC

`.mcp.json` reads two variables from the cloud environment:

| Variable | Value |
|---|---|
| `ROBLOX_MCP_URL` | `https://YOUR-DOMAIN.ngrok-free.dev/mcp` (leave unset to use Hunter's tunnel) |
| `ROBLOX_MCP_TOKEN` | the Studio connector's token from `%USERPROFILE%\.robloxstudio-mcp\auth-token` on your PC |

Set them at claude.ai/code in your cloud environment's settings. New sessions pick them up.
The connector rejects any request without its token, so the tunnel URL alone gives nobody control.

## One-time setup (each person)

```powershell
cd C:\path\to\HatchOrSnatch
powershell -ExecutionPolicy Bypass -File tools\mcp\setup_cloud.ps1
```

It installs Node.js and ngrok if needed, saves your ngrok authtoken, remembers your static domain and
copies your connector token to the clipboard for the cloud environment.

Plugin and connector versions must match: both are **3.2.1** here (`start_mcp_server.ps1` pins it).

## Every time

1. Open Roblox Studio with the place loaded.
2. The connector on port 58741: either the **Claude desktop app is open** (its Roblox Studio connector
   already serves this port), or run `powershell -ExecutionPolicy Bypass -File tools\mcp\start_mcp_server.ps1`
   in its own window. Don't run both; the script refuses if the port is busy.
3. Run `powershell -ExecutionPolicy Bypass -File tools\mcp\start_tunnel.ps1` and leave it open.
4. Start (or come back to) a cloud session on this repo.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "MCP endpoint not found" | The tunnel window is closed, or `ROBLOX_MCP_URL` points at another domain |
| Connect timeout | Nothing on port 58741: open the desktop app or run `start_mcp_server.ps1` |
| 401 / unauthorized | `ROBLOX_MCP_TOKEN` doesn't match `auth-token` on the PC; rerun `setup_cloud.ps1` and paste again (new session) |
| Connected, no Studio instances | Studio isn't open, or the plugin isn't 3.2.1 |
