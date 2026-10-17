# Open the ngrok tunnel that lets a Claude cloud session reach the Studio connector on this PC.
#
#   powershell -ExecutionPolicy Bypass -File tools\mcp\start_tunnel.ps1
#
# Uses the domain saved by setup_cloud.ps1 (or pass -Domain your-domain.ngrok-free.dev).
# The connector on port 58741 must be running too: either the Claude desktop app is open (its
# Roblox Studio connector serves this port), or start_mcp_server.ps1 is running in another window.
# Leave this window open while the cloud session works.
# ASCII only on purpose: Windows PowerShell 5.1 misreads UTF-8 files without a BOM.
param([string]$Domain = "")

if (-not $Domain) {
    $f = Join-Path $HOME ".robloxstudio-mcp\ngrok-domain.txt"
    if (Test-Path $f) { $Domain = (Get-Content $f -Raw).Trim() }
}
if (-not $Domain) { throw "No domain. Run setup_cloud.ps1 first, or pass -Domain your-domain.ngrok-free.dev" }
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) { throw "ngrok not found. Run setup_cloud.ps1 first." }

# Free ngrok accounts need agent 3.20.0 or newer (ERR_NGROK_121); winget can install an older build.
$verText = (ngrok version 2>&1 | Out-String)
if ($verText -match '(\d+)\.(\d+)\.(\d+)') {
    $v = [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $Matches[3])
    if ($v -lt [version]"3.20.0") {
        Write-Host "ngrok $v is too old (free accounts need 3.20+). Updating..."
        ngrok update
        Write-Host ("ngrok is now: " + (ngrok version))
    }
}

$listening = Get-NetTCPConnection -LocalPort 58741 -State Listen -ErrorAction SilentlyContinue
if (-not $listening) {
    Write-Host "Nothing is listening on port 58741 yet: open the Claude desktop app, or run"
    Write-Host "start_mcp_server.ps1 in another window. Starting the tunnel anyway."
}

$host.UI.RawUI.WindowTitle = "ngrok tunnel for Roblox Studio (leave open)"
Write-Host "Tunnel: https://$Domain  ->  localhost:58741"
# Newer ngrok calls the static-domain flag --url; older builds (winget may install 3.3.x) use --domain.
# Try --url first; if ngrok rejects it straight away, try --domain.
Write-Host ("ngrok: " + (ngrok version))
$t0 = Get-Date
ngrok http --url=$Domain 58741
if (((Get-Date) - $t0).TotalSeconds -lt 8) {
    Write-Host ""
    Write-Host "Retrying with --domain (older ngrok)..."
    ngrok http --domain=$Domain 58741
}
