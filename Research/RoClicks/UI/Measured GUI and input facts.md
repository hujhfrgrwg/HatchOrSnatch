---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ui/gui-input-facts
retrieved: 2026-10-15
---
# Measured GUI and input facts

Engine behaviour that was measured in Studio, not assumed. Roblox changes some of these between versions (one note below flipped within a month), so re-measure any rule your code depends on.

Engine behaviour that was measured in Studio, not assumed. Roblox changes some of these between versions (one note below flipped within a month), so re-measure any rule your code depends on.

## Contents

- [[#The GUI inset (58 px)]]
- [[#Screen rays: ScreenPointToRay vs ViewportPointToRay]]
- [[#Simulated clicks are offset]]
- [[#UIStroke scales with UIScale]]
- [[#TextSize facts]]
- [[#ScrollingFrame: scale rows + AutomaticCanvasSize collapse]]
- [[#BillboardGui clips its content]]
- [[#BillboardGui buttons don't get clicks under the HUD]]
- [[#Touch targets]]
- [[#Tap vs drag]]
- [[#Smaller gotchas]]

## The GUI inset (58 px)

- The top bar inset was **58 px** in the measured Studio builds. Read it at runtime with `GuiService:GetGuiInset()`; never hard-code it in game code.
- A full-screen ScreenGui with `IgnoreGuiInset = true` reports its root `AbsolutePosition` as `(0, -58)`.
- **`InputObject.Position` is in the same space as GUI `AbsolutePosition`.** So for a point relative to an IgnoreGuiInset root, use `input.Position - root.AbsolutePosition`. Don't add `GetGuiInset()` on top; that double-corrects.

## Screen rays

- `Camera:ScreenPointToRay(x, y)` takes inset-excluded (GUI-space) coordinates, which is what `input.Position` and `UserInputService:GetMouseLocation() - GetGuiInset()` give you.
- `Camera:ViewportPointToRay(x, y)` takes full-viewport coordinates (inset included).
- Feeding `input.Position` to `ViewportPointToRay` puts every world pick 58 px off. On a touch strike ability this dropped airstrikes under the ability button instead of where the kid tapped.

``` lua
local function groundAt(input: InputObject): RaycastResult?
    local ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
    return workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
end
```

Related trap: a reticle that follows the mouse in RenderStepped is stale on touch (it sits where the previous touch was, i.e. on the button). For touch input, raycast from the tap itself.

## Simulated clicks are offset

Agent tools that synthesise mouse input (Studio MCP "simulate mouse input") deliver the click 58 px higher than the y you pass when the target GUI does not ignore the inset. The click lands on whatever is above, or on nothing. It looks exactly like a dead button, and `PlayerGui:GetGuiObjectsAtPosition` agrees the button is on top, which sends you hunting a z-order bug that doesn't exist.

- Click at `AbsolutePosition + AbsoluteSize/2`, read from the running client, plus the inset on y.
- Before concluding a click path is broken, measure: arm `UserInputService.InputBegan` to record `input.Position`, fire one click, compare.
- Screenshot tools may return 2x retina images whose pixels are **not** click coordinates. Halve them, or better, read positions from the client.
- `MouseEnter`/`MouseLeave` never fire from synthetic input. Test hover by calling the handler directly.
- Studio can't synthesise multi-finger touch. Pinch and second-finger rejection can only be verified by reading the code.

## UIStroke scales with UIScale

Measured in late 2026: **UIStroke thickness now scales with an ancestor UIScale.** An older note (and older code) assumed it didn't and multiplied thickness by the zoom, which made outlines about 6x too fat at small scales. Set thickness in design units and let UIScale scale it.

If you support both behaviours, store the design thickness in an attribute (`BaseThickness`) and decide at runtime by measuring once, rather than hard-coding either assumption.

## TextSize facts

- `TextSize` is the **line height**, not the em. CSS `font-size` x **1.215** = Roblox `TextSize`.
- `TextSize` is an integer capped at **100**. Larger titles: `TextSize / f` inside a frame with `UIScale f`.
- `TextBounds` and `TextFits` are the ground truth for "does it fit". Sweep them (see [[Verifying UI|verifying-ui.md]]).
- Runs of spaces render in full (HTML collapses them). Collapse whitespace when exporting text.

## ScrollingFrame collapse

Inside a ScrollingFrame, a child's **Scale size resolves against the canvas**, not the visible window. Combine Scale-sized rows with `AutomaticCanvasSize` (canvas measured from content) and the two define each other:

- rows collapse to nothing when `rowScale * count < 1`,
- the canvas explodes when it's \> 1 (seen once at 112 million px),
- it settles at an arbitrary size near 1.

The obvious fix, "just turn on AutomaticCanvasSize", is what breaks it. Give rows **pixel** heights computed from the list's own `AbsoluteSize.Y`, convert `UIListLayout.Padding` from Scale to Offset for the same reason, then let `AutomaticCanvasSize = Y` follow. Recompute on `list:GetPropertyChangedSignal("AbsoluteSize")`. See [snippets/PixelRows.luau](https://roclicks.gg/resources/code/ui/snippets/PixelRows.luau).

Also check every pasted UI kit for rows at a tiny scale (e.g. 0.039) with `CanvasSize` = 5 scale: it renders fine but hides the last rows behind thousands of pixels of dead scroll.

## BillboardGui clips its content

A BillboardGui clips its children to its own `Size` **even with `ClipsDescendants = false`**. A label sized in studs (a 63x17 canvas) cut off the flag, name ends and badges whenever a minimum pixel size kicked in, on phones and at far zoom on PC.

- Size the BillboardGui in **pixels** (`UDim2.fromOffset`) when content has a pixel floor.
- Give the canvas about **1.5x headroom** for grow, bounce and badge animations, and centre the content.
- Billboards are also never rendered by Studio's capture tools (edit or play, even AlwaysOnTop). Missing labels in a capture are not a bug; verify billboards by property sweep (Enabled, Adornee.Parent, Size, MaxDistance).
- In one project AlwaysOnTop billboards didn't draw at all in playtests; depth-tested billboards lifted above their target did. If AlwaysOnTop misbehaves, lift instead.

## BillboardGui buttons and clicks

TextButtons inside a BillboardGui **never received clicks** while a full-screen HUD ScreenGui sat above them. Don't fight the layering. Hit-test instead:

1.  On `InputEnded` (after tap-vs-drag), project each candidate's anchor with `camera:WorldToScreenPoint` (GUI space) and build its screen rect from the billboard's pixel size.
2.  Pad the rect to a minimum tap box (56 px square on touch, 34 px on mouse, plus 12 / 4 px padding).
3.  A direct hit beats a padded hit; nearest centre breaks ties.
4.  If no plate hit, raycast the world for the object under the tap; then try the nearest candidate within a small radius (34 px touch / 16 px mouse) so roads and borders still pick.

See [snippets/WorldHitTest.luau](https://roclicks.gg/resources/code/ui/snippets/WorldHitTest.luau). Measured cost: about 0.12 ms per pick.

## Touch targets

- **Minimum 48 screen px** for any tap target, **56-60 px** for primary or frequently tapped ones (platform guidelines are 44 pt and 48 dp; kids' thumbs want more).
- Convert to design px: a landscape phone shows a 1920x1080 canvas at about 0.36x, so 48 screen px is about **130 design px**. Primary buttons 150-190 design px.
- World labels that shrink with UIScale need a floor on touch. Plates that drew 52x14 px on a phone got a 170x46 px floor; that was the difference between "can't tap countries" and "easy".
- Detect touch as `TouchEnabled and not KeyboardEnabled`, or a touch screen under 600 px tall.

## Tap vs drag

A press is a tap only if it moved less than **7 px (mouse) / 14 px or 2.5% of the short screen side (touch)**, ended within **0.5 s / 0.65 s**, never had a second finger down, and no other system claimed it (camera drag, pinch, placement). `UserInputService:GetTouchesInProgress` does not exist; count touches yourself from InputBegan/InputEnded. A claim should expire shortly (0.25 s) after the press ends.

## Smaller gotchas

- Clearing a container by destroying all children also destroys its UIScale/UIListLayout. Skip them.
- `PreloadAsync` from a plugin context reports Failure for every rbxassetid, and `IsLoaded` stays false in StarterGui. Probe ids differently in edit mode (e.g. `AssetService:CreateEditableImageAsync` in a spawned task) and judge `IsLoaded` per asset, not per instance (offscreen instances report false).
- Preloading UI art helps but doesn't remove first-open pop-in on its own; a CanvasGroup that renders before its art loads shows blank tiles. Preload templates at client init, before first use.
- Roblox clears PlayerGui on respawn (unless `ResetOnSpawn = false`); never parent game state there.
- `Font.fromEnum(Enum.Font.Arcade)` resolves to Press Start 2P.

Previous: [[Feedback patterns]] · Next: [[Verifying UI]]
