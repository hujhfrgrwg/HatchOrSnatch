# HOS-TOPBAR-001: top bar buttons as hover-to-open squares (17 Oct 2026)

**What changed (Studio place "Hatch or Snatch", not saved or published)**
- New client ModuleScript `StarterPlayer.StarterPlayerScripts.EOS.Controllers.TopbarHover`, started by one line in `ClientMain`.
- All five lobby top-bar buttons (Quests, Incubator top-left; Servers, Stats, Settings top-right) now rest as icon squares. They keep the same plate, outline and icon, and the red ! badge sits on the square's corner.
- Mouse hover (or gamepad selection) tweens the plate out to the full pill: 0.18 s Quad Out, with the label fading and sliding in after the width. Top-left buttons grow rightward and top-right buttons grow leftward, and neighbours slide to make room. Moving the mouse off tweens it back.
- On touch screens the buttons stay square, and tapping opens the panel as before.
- Which panel opens and when the groups hide are handled by UIController, which is unchanged. StarterGui.EOSUI is not edited; every change is made at runtime on the PlayerGui copy.
- The pill art was a stretched raster, so TopbarHover switches it to 9-slice (16 px caps at 2x) to keep its ends crisp at any width.
- UI project: `ui/build.py` gets `s_topbar_states`, which builds the page `ui/hud_topbar_states.html`.
- TopbarPlus (the first plan) was added and then fully removed. Its captures are in `_dropped_topbarplus/`.

**Captures (docs/topbar/)**
- `topbar_states.jpg`: the design sheet (collapsed, Settings hovered, Quests hovered, Stats tween 0 / 50 / 100%).
- `a_pc_collapsed_topbar.jpg`: PC 1920x1080, collapsed.
- `b_settings_hovered.jpg`: Settings expanded leftward.
- `c_quests_hovered.jpg`: Quests expanded rightward.
- `d_stats_hovered.jpg`: Stats expanded, with Servers slid left.
- `e_stats_tween_3frames.jpg` + `e_stats_tween_samples.txt`: the tween. The middle frame is the design sheet's 50% row, because a capture can't land inside 0.18 s. The text file has per-frame widths measured in the playtest.
- `f_phone_844x390_topbar.jpg`: iPhone 14 landscape. Everything stays square, and a tap or select doesn't expand.

**Known limits**
- The hover shots were driven through GuiService selection, which runs the same code path as MouseEnter. The MCP can't move a real mouse, so a real mouse hover hasn't been tried yet.
- The red ! didn't show in the captures because the test profile had nothing to claim. Its position follows the plate's corner (x = plate right - 16).
- The playtest used the Studio sandbox (EOS_Sandbox), so the test player's EOS_InMatch was set to false on the server to reach the lobby HUD. The place setting was left unchanged.

Backup and undo: `docs/backups/HOS-TOPBAR-001_20261017/README.md`.
