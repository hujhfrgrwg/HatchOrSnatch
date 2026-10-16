# Upload the new game UI's images (icons, pets, eggs, panel art) and push the asset ids back for Claude.
#
#   powershell -ExecutionPolicy Bypass -File tools\upload\upload_ui.ps1
#
# Needs HOS_ROBLOX_API_KEY and HOS_ROBLOX_GROUP_ID (or HOS_ROBLOX_USER_ID) set, like upload_assets.py.
# Safe to re-run: files that already have an id are skipped (Assets/asset_ids.json is the ledger).
# ASCII only on purpose: Windows PowerShell 5.1 misreads UTF-8 files without a BOM.
param([string]$Branch = "claude/nifty-carson-ml33ob")
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

if (git status --porcelain) { throw "This folder has uncommitted changes. Commit or stash them first, then re-run." }
git fetch origin $Branch
git checkout $Branch
git pull --ff-only origin $Branch

python tools/upload/upload_assets.py --list Assets/UI/upload_list.json
if ($LASTEXITCODE -ne 0) { throw "Upload script failed (see above)." }

git add Assets/asset_ids.json
git commit -m "UI image asset ids (upload_ui.ps1)"
git push origin $Branch
Write-Host "Done. Tell Claude the ids are pushed."
