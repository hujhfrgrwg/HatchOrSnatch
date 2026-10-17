# One-time setup so a Claude cloud session (claude.ai/code) can drive Roblox Studio on THIS PC.
#
#   powershell -ExecutionPolicy Bypass -File tools\mcp\setup_cloud.ps1
#
# What it does:
#   1. Checks Node.js (npx) and installs ngrok with winget if it's missing.
#   2. Asks for your ngrok authtoken (typed here, hidden, never shown) and saves it into ngrok's config.
#   3. Asks for YOUR static ngrok domain and remembers it in %USERPROFILE%\.robloxstudio-mcp\ngrok-domain.txt
#   4. Copies the Studio connector's secret token to your clipboard and prints the two values to put
#      in your claude.ai/code cloud environment (ROBLOX_MCP_URL and ROBLOX_MCP_TOKEN).
# Never paste either token into a Claude chat.
# ASCII only on purpose: Windows PowerShell 5.1 misreads UTF-8 files without a BOM.

$ErrorActionPreference = "Stop"
$cfgDir = Join-Path $HOME ".robloxstudio-mcp"
$domainFile = Join-Path $cfgDir "ngrok-domain.txt"
$tokenFile = Join-Path $cfgDir "auth-token"

Write-Host "== 1. Tools"
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js not found. Installing Node.js LTS..."
    winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    Write-Host "Node.js installed. Close this window, open a new PowerShell, and run this script again."
    exit 1
}
Write-Host "Node.js OK: $(node --version)"
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    Write-Host "ngrok not found. Installing..."
    winget install -e --id Ngrok.Ngrok --accept-source-agreements --accept-package-agreements
    Write-Host "ngrok installed. Close this window, open a new PowerShell, and run this script again."
    exit 1
}
Write-Host "ngrok OK: $(ngrok version)"

Write-Host ""
Write-Host "== 2. ngrok account"
$ans = Read-Host "Have you already run 'ngrok config add-authtoken' on this PC? (y/n)"
if ($ans -notmatch '^[yY]') {
    Write-Host "Get your authtoken at https://dashboard.ngrok.com/get-started/your-authtoken"
    $sec = Read-Host "Paste your ngrok authtoken (hidden)" -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    ngrok config add-authtoken $plain | Out-Null
    $plain = $null
    Write-Host "Saved into ngrok's config."
}

Write-Host ""
Write-Host "== 3. Your static domain"
Write-Host "In the ngrok dashboard open Domains (https://dashboard.ngrok.com/domains) and claim your free static domain."
Write-Host "Use YOUR OWN domain, not Hunter's (mutual-native-dispense.ngrok-free.dev)."
$old = if (Test-Path $domainFile) { (Get-Content $domainFile -Raw).Trim() } else { "" }
$prompt = if ($old) { "Your domain [$old]" } else { "Your domain (e.g. something-something.ngrok-free.dev)" }
$domain = (Read-Host $prompt).Trim()
if (-not $domain) { $domain = $old }
$domain = $domain -replace '^https?://', '' -replace '/.*$', ''
if (-not $domain) { throw "No domain given." }
if ($domain -eq "mutual-native-dispense.ngrok-free.dev") { throw "That's Hunter's domain. Claim your own in the ngrok dashboard." }
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
Set-Content -Path $domainFile -Value $domain -Encoding ASCII
Write-Host "Saved: $domain"

Write-Host ""
Write-Host "== 4. Cloud environment values"
if (-not (Test-Path $tokenFile)) {
    Write-Host "No connector token yet. Open the Claude desktop app (or run start_mcp_server.ps1 once) so the"
    Write-Host "Studio connector creates $tokenFile, then run this script again."
    exit 1
}
(Get-Content $tokenFile -Raw).Trim() | Set-Clipboard
Write-Host "At claude.ai/code open your cloud environment's settings (Edit) and add two environment variables:"
Write-Host ""
Write-Host "   ROBLOX_MCP_URL   = https://$domain/mcp"
Write-Host "   ROBLOX_MCP_TOKEN = (paste: it's on your clipboard now)"
Write-Host ""
Write-Host "The token is the Studio connector's own secret; the connector rejects any request without it."
Write-Host "Done. Each time: open Roblox Studio, run start_tunnel.ps1, then start a new cloud session."
