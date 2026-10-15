# Keep the Roblox Studio MCP server running for cloud sessions (Hatch or Snatch; same server Faceoff uses).
#
#   powershell -ExecutionPolicy Bypass -File tools\mcp\start_mcp_server.ps1
#
# Runs @chrrxs/robloxstudio-mcp pinned to the Studio plugin's version (they must match) on
# http://127.0.0.1:58741 and restarts it if it stops. Cloud sessions reach it through the ngrok
# tunnel (https://mutual-native-dispense.ngrok-free.dev -> localhost:58741), which runs separately.
# Leave this window open and don't type in it: the server reads its MCP input from this console.
# ASCII only on purpose: Windows PowerShell 5.1 misreads UTF-8 files without a BOM.
param([string]$Version = "3.2.1")

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) { throw "npx not found. Install Node.js LTS first: winget install OpenJS.NodeJS.LTS" }

$busy = Get-NetTCPConnection -LocalPort 58741 -State Listen -ErrorAction SilentlyContinue
if ($busy) {
    Write-Host "Port 58741 is already in use by process $($busy[0].OwningProcess). An MCP server is probably already running; close it first if it's stuck."
    exit 1
}

$host.UI.RawUI.WindowTitle = "Roblox Studio MCP server (leave open)"
while ($true) {
    Write-Host ("[{0}] Starting robloxstudio-mcp {1} on port 58741..." -f (Get-Date -Format HH:mm:ss), $Version)
    & npx -y "@chrrxs/robloxstudio-mcp@$Version"
    Write-Host ("[{0}] Server stopped (exit code {1}). Restarting in 3 seconds; press Ctrl+C to quit." -f (Get-Date -Format HH:mm:ss), $LASTEXITCODE)
    Start-Sleep -Seconds 3
}
