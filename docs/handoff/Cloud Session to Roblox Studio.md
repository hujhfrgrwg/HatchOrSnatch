# Handoff: connecting a Claude Code cloud session to Roblox Studio on your PC

This guide is for a person and their Claude agent. It explains how a Claude Code session running in the cloud (claude.ai/code) controls Roblox Studio on the person's own Windows PC. It is the setup Hunter uses for Hatch or Snatch. Every name and number below is real, except the parts marked **YOUR OWN**, which each person must make for themselves.

## How it fits together

```
Claude cloud session ──HTTPS──> ngrok tunnel (public URL) ──> localhost:58741 on your PC
                                                              robloxstudio-mcp server
                                                                     │
                                                              Roblox Studio plugin (same version)
                                                                     │
                                                              your open Studio place
```

- **Studio plugin:** the Roblox Studio MCP plugin runs inside Studio and talks to a small local server.
- **Local server:** `@chrrxs/robloxstudio-mcp` is an npm package that runs on the PC and listens on `http://127.0.0.1:58741`.
- **Tunnel:** a cloud session can't reach `localhost` on your PC, so **ngrok** gives that port a fixed public HTTPS address.
- **Session config:** the cloud session finds the tunnel through `.mcp.json` in the repo and sends a secret token with every request, so strangers can't drive your Studio.
- **Repos and places:** one server serves every Studio window that's open. The agent picks the right place by name or place id, so several games can share the setup.

## What the person sets up (once)

### 1. Install the tools
- **Node.js LTS**, which provides `npx`: `winget install OpenJS.NodeJS.LTS`
- **ngrok:** make a free account at ngrok.com, install it, and run `ngrok config add-authtoken <your ngrok token>` once. Type the token into your own terminal, never into a chat.
- **A static ngrok domain (YOUR OWN):** in the ngrok dashboard, open Domains and claim the one free static domain, e.g. `something-something.ngrok-free.dev`. Hunter's is `mutual-native-dispense.ngrok-free.dev`. Don't use his; each person needs their own.

### 2. Install the Studio plugin
Install the Roblox Studio MCP plugin that matches the server version. Hunter uses **3.2.1** for both. If the plugin and server versions differ, they won't talk to each other.

### 3. Add the start script to the repo
Copy `tools/mcp/start_mcp_server.ps1` from this repo. It:
- refuses to start if port 58741 is already in use, since a server is probably running already;
- runs `npx -y @chrrxs/robloxstudio-mcp@3.2.1` and restarts it if it stops.

### 4. Point the repo at your tunnel
Put `.mcp.json` at the repo root:

```json
{
  "mcpServers": {
    "roblox": {
      "type": "http",
      "url": "https://YOUR-OWN-DOMAIN.ngrok-free.dev/mcp",
      "headers": { "Authorization": "Bearer ${ROBLOX_MCP_TOKEN}" }
    }
  }
}
```

The token is not in the file. `${ROBLOX_MCP_TOKEN}` is read from the cloud environment (step 5).

### 5. Make a secret token and give it to the cloud environment
- **Make the token:** a long random string, e.g. 64 characters. In PowerShell: `-join ((48..57)+(97..122) | Get-Random -Count 64 | % {[char]$_})`
- **Give it to the cloud:** at claude.ai/code, open the session's cloud environment menu in the title bar, choose **Edit**, and add an environment variable `ROBLOX_MCP_TOKEN` with that value. Use Network secrets if that section is offered. New sessions pick it up.
- **Check it on the PC side:** whatever receives the requests must reject any request without `Authorization: Bearer <that token>`. One way is an ngrok traffic policy on the tunnel. Check the exact syntax against ngrok's current docs:

  ```yaml
  # policy.yml (YOUR OWN token in place of PASTE_TOKEN)
  on_http_request:
    - expressions:
        - "!('Bearer PASTE_TOKEN' in req.headers['authorization'])"
      actions:
        - type: deny
  ```
  Run it with `ngrok http --url=YOUR-OWN-DOMAIN.ngrok-free.dev 58741 --traffic-policy-file policy.yml`.

  Without a check, anyone who learns the URL can control your Studio.
- **Never paste the token or the ngrok authtoken into a Claude chat.** Type it only into the environment settings and your own terminal.

### 6. Permissions (optional)
`.claude/settings.json` can pre-allow `mcp__roblox`, so the agent doesn't ask before each Studio call.

## Every time you want a cloud session to use Studio

Open **two PowerShell windows** and leave both open:

```powershell
# Window 1: the local server (don't type in this window; the server reads its input from it)
cd C:\path\to\your\repo
powershell -ExecutionPolicy Bypass -File tools\mcp\start_mcp_server.ps1
```

```powershell
# Window 2: the tunnel
ngrok http --url=YOUR-OWN-DOMAIN.ngrok-free.dev 58741
# (older ngrok versions: --domain=YOUR-OWN-DOMAIN.ngrok-free.dev; add --traffic-policy-file policy.yml if you use one)
```

Then open Roblox Studio with your place loaded, and start, or come back to, the cloud session.

## Notes for the Claude agent

- **Pick the instance first.** Call `get_connected_instances` and choose the instance by place name or place id. The same server serves every open Studio window, so other games may be connected too; never edit a place that isn't yours to edit. Instance ids change whenever Studio restarts, so check again after a crash.
- **When the server can't be reached,** the error looks like "endpoint not found" or a connect timeout. Ask the person to start both windows; don't keep retrying. Never ask them to paste tokens into chat.
- **Files land on the PC.** Tools that write or read files (`export_rbxm`, image paths for `manage_monetization`, `upload_asset`) run on the person's PC, so paths are Windows paths there, like `C:\path\to\repo\...`. To use a file from the repo, ask the person to `git pull` first.
- **Large script installs** worked best as one `execute_luau` call using `ScriptEditorService:UpdateSourceAsync`, then a hash check comparing Studio's copy with the local file.
- **Import big builds from GitHub:** `import_rbxm` with a raw GitHub URL pinned to a commit sha (`https://raw.githubusercontent.com/<owner>/<repo>/<sha>/path.rbxmx`).
- **Playtests:** `solo_playtest` with `mode: "play"`, then `eval_server_runtime` / `eval_client_runtime`. `multiplayer_playtest` (up to 8 clients) tests anything that needs several real players. Screenshots work in solo tests only.
- **Mouse clicks** (`simulate_mouse_input`) take viewport pixels, not screenshot pixels. Work out targets from a GUI object's `AbsolutePosition` plus the top-bar inset. Clicks can be unreliable when Studio isn't the focused window, so prefer calling the game's code to open panels.
- **Studio can freeze or crash during long Team Tests.** Have the person relaunch Studio, then check `get_connected_instances` again.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| "MCP endpoint not found" | The ngrok window is closed, or a different domain is running | Start window 2 with the right domain |
| Connect timeout / version negotiation timed out | The server window is closed or stuck | Restart window 1; if the port is busy, close the old server first |
| Connects, but no Studio instances listed | Studio isn't open, or the plugin isn't running or is the wrong version | Open the place; match plugin and server versions |
| 401 / denied | `ROBLOX_MCP_TOKEN` is missing in the cloud environment, or doesn't match the PC-side check | Fix the variable in environment settings (new session), or fix the policy |
| `npx not found` | Node.js isn't installed | `winget install OpenJS.NodeJS.LTS` |
