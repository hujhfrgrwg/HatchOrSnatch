# HOS-SKILLS-001: Install the repo skills account-wide (handoff)

For a Claude session running **on Hunter's Windows PC** (Claude desktop app with computer use, or local Claude Code). A cloud session can't do this because it has no access to Hunter's logged-in claude.ai account or his PC.

## Goal
Hunter wants all 23 skills in `HatchOrSnatch\.claude\skills\` available everywhere and used regularly:
1. **Claude Code on this PC.** Copy them into the user-level skills folder so every project sees them.
2. **claude.ai account (chats, desktop app, Cowork, other machines).** Upload each one through Settings → Skills → Add.

## Rules
- Never ask Hunter to paste passwords, cookies, tokens or API keys. Use the browser or app he's already signed into.
- Don't touch the Faceoff or HOOKED folders or Studio places.
- Don't delete, rename or edit the skills inside the repo. Whether to remove the repo copies later is Hunter's decision.
- Leave existing account skills alone (e.g. `meshlab`, the Anthropic ones). If an upload clashes with an existing name, stop and ask Hunter.

## The 23 skills
| Folder in repo | Name to upload as |
|---|---|
| agent-browser | agent-browser |
| claude-music | claude-music |
| claude-music-analyze | claude-music-analyze |
| claude-music-compose | claude-music-compose |
| claude-music-cover | claude-music-cover |
| claude-music-enhance | claude-music-enhance |
| claude-music-export | claude-music-export |
| claude-music-generate | claude-music-generate |
| claude-music-library | claude-music-library |
| claude-music-lora | claude-music-lora |
| claude-music-random | claude-music-random |
| claude-music-repaint | claude-music-repaint |
| claude-music-web | claude-music-web |
| graphify | graphify |
| humanizer | humanizer |
| jest-lua | jest-lua |
| roblox-game-pipeline | roblox-game-pipeline |
| roblox-game-score | roblox-game-score |
| roblox-trailer | roblox-trailer |
| roblox-ui-maker | roblox-ui-maker |
| roblox-vfx | roblox-vfx |
| **scrapling** | **scrapling-official** (its `SKILL.md` says `name: scrapling-official`) |
| studify | studify |

## Step 0: Get the latest repo
In Hunter's HatchOrSnatch clone (ask him for the path if you can't find it):
```powershell
git fetch origin
git status
```
The skills are on `main`. Don't switch branches if he has uncommitted work. Ask him first.

## Step 1: Claude Code user-level skills (this PC)
```powershell
$src = "<HatchOrSnatch clone>\.claude\skills"
$dst = "$HOME\.claude\skills"
New-Item -ItemType Directory -Force $dst | Out-Null
Get-ChildItem $src -Directory | ForEach-Object {
  $name = if ($_.Name -eq 'scrapling') { 'scrapling-official' } else { $_.Name }
  if (Test-Path "$dst\$name") { Write-Warning "$name already exists in $dst, skipped" }
  else { Copy-Item -Recurse $_.FullName "$dst\$name" }
}
Get-ChildItem $dst -Directory | Select-Object Name
```
Report any skipped names to Hunter rather than overwriting them.

## Step 2: Build one zip per skill
Use `tar`, which ships with Windows 10 and later. Don't use `Compress-Archive`: in Windows PowerShell 5.1 it writes backslashes into zip paths, and the upload can reject those. Each zip must contain one top-level folder named after the skill, with `SKILL.md` directly inside it.
```powershell
$stage = "$env:TEMP\hos-skill-stage"; $out = "$HOME\Downloads\hos-skill-zips"
Remove-Item -Recurse -Force $stage, $out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stage, $out | Out-Null
Get-ChildItem $src -Directory | ForEach-Object {
  $name = if ($_.Name -eq 'scrapling') { 'scrapling-official' } else { $_.Name }
  Copy-Item -Recurse $_.FullName "$stage\$name"
  Get-ChildItem "$stage\$name" -Recurse -Include '__pycache__','*.pyc','.DS_Store' -Force | Remove-Item -Recurse -Force
  tar -a -c -f "$out\$name.zip" -C $stage $name
}
Get-ChildItem $out | Select-Object Name, Length
tar -tf "$out\roblox-vfx.zip" | Select-Object -First 5   # expect roblox-vfx/SKILL.md etc.
```
You should end up with 23 zips, each under 200 KB.

## Step 3: Upload to the claude.ai account
Do this with computer use in the Claude desktop app, or have Hunter click while you guide him.
1. Settings → **Capabilities**: make sure code execution / file creation is on (skills need it).
2. Settings → **Skills** → **Add** → upload a skill → pick one zip from `Downloads\hos-skill-zips`.
3. Repeat for all 23. After each, check it appears under **Created by you** with the right name.
4. If an upload fails, note the zip and the exact error, carry on with the rest, then report.

## Step 4: Check and report back
- Skills page shows the 23 new skills plus `meshlab`.
- In a new claude.ai chat, ask "make an explosion VFX for Roblox" and confirm `roblox-vfx` is the skill that loads.
- In a new local Claude Code session outside the HatchOrSnatch folder, confirm `roblox-vfx` and `studify` are listed.
- Tell Hunter which skills were uploaded, which (if any) failed and why, and which were skipped.

## Known catch: duplicates
In the HatchOrSnatch repo, sessions will now see each skill twice: from the account or `~\.claude\skills`, and from the repo's `.claude\skills`. If the copies drift apart it's unclear which one runs. Hunter hasn't decided yet whether to delete the repo copies. Mention this and leave the decision to him. If a skill is edited later, update the other copies too (repo, `~\.claude\skills` and a re-upload).
