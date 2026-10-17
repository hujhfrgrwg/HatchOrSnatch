# How to make UI for Hatch or Snatch (every thread)

Hunter, 2026-10-17: "all threads need to be making ui the way you built the ui here" (the retention prompts, HOS-RET-001). This is that way. The skill is RoClicks **roblox-ui-maker** (`.claude/skills/roblox-ui-maker/`, SKILL.md + LESSONS.md). Read Game-Blueprint `03_UI_Workflow.md` / `docs/Game-Blueprint Digest.md` first.

On Hunter's PC the worked example files are in `C:\HatchOrSnatch_RET`.

1. **Draw it in the live UI source, not from scratch.** Add your screens as a new section of `ui/build.py` (the file that draws every in-game EOSUI panel, "sport" style). Reuse its components: `panel_sport(...)`, `btn`, `slot`, `T` text, `icn` icons, `grp(...)` for HUD groups. Styling comes from `ui/kit.css` + `ui/styles/sport.css`. Never hand-build a look in Luau with Instance.new.
2. **Every state as an HTML page.** Add each page to `SCREENS` (claim/wait, empty/full, phone 844x390 version). Name every live label/button (`name=`); use `hid=True` for exported-but-hidden states. Check pages at 1920x1080 and phone, `?check` for overflow.
3. **Hunter approves the HTML stills** (post them in your thread). No Studio work before a yes.
4. **Export with its own config** so the main EOSUI is untouched: a folder like `ui_<feature>/rbx.json` naming your gui, screens and pages, `luau_out` -> `roblox/ui_<feature>/`. Then from that folder, with the `ui/` preview server running: `export.mjs` -> `gen.py` -> `mock.py` + `mockshot.mjs` (mean diff low; open the cmp images).
5. **Upload only new art** (`rbx/out/upload/*.png` + any new icon) with `tools/upload/upload_assets.py --list ...` on Hunter's PC; resolve decal -> image ids in Studio; write `AssetIds.luau`. Reuse icon ids already in `roblox/ui/AssetIds.luau`.
6. **Build in Studio:** `bundle.py` -> `import_rbxm` into ServerStorage -> `require(...Build.Builder).build()` -> gui Enabled, `Builder.fit()` twice, Enabled=false. Never `set_script_source`.
7. **Runtime:** your own controller module drives it via the skill's `client/UI.luau` copy (UI.open/close, juicy buttons, popups) and UIKit; one-line hook in ClientMain. Never add top-level locals to UIController.
8. **Verify:** sizes 1920x1080, 1366x768, 844x390 (phone text >= ~10 px; grow cards on phones if needed); Roblox fonts run wider than Chrome, so check every title fits its banner; one self-closing playtest at a time (claims file); screenshots next to an existing EOSUI panel.

Worked example: `ui/build.py` section "Welcome back gift + favorites prompt (HOS-RET-001)", `ui_ret/rbx.json`, `roblox/ui_retention/`, `roblox/game/RetentionController.luau`, install steps `Dev/HOS-RET-001 Install.md`.
