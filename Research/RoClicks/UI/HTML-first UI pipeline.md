---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ui/html-pipeline
retrieved: 2026-10-15
---
# HTML-first UI pipeline

Design every screen in HTML/CSS, then turn it into real Roblox GUI instances by code. Never hand-place frames in Studio, and never hand-write a builder per screen once you have more than two or three.

Design every screen in HTML/CSS, then turn it into real Roblox GUI instances by code. Never hand-place frames in Studio, and never hand-write a builder per screen once you have more than two or three.

## Contents

- [[#Why HTML first]]
- [[#Architecture]]
- [[#Step 1: the HTML source]]
- [[#Step 2: export (DOM to layout JSON + art)]]
- [[#Step 3: generate (JSON to Data modules)]]
- [[#Step 4: upload with a ledger]]
- [[#Step 5: the Builder]]
- [[#Runtime UI goes through HTML too]]
- [[#Keeping copies of the UI runtime in sync]]
- [[#Conversion facts (CSS to Roblox)]]

## Why HTML first

- An agent iterates on HTML in seconds: edit, screenshot in a browser pane, compare, repeat. Studio GUI iteration is slow and often can't be screenshotted (see [[Verifying UI|verifying-ui.md]]).
- The design can be reviewed by the developer as a page, with every state on one sheet, before any Luau exists. Approval happens on the HTML, not in Studio.
- Hand-drawn Studio GUIs and image-editor mockups looked worse every time they were tried. CSS gives exact gradients, outlines, radii and text metrics that can be measured and diffed.
- An earlier image-editor pipeline (design tokens -\> headless editor render -\> 9-slice export -\> Luau) worked, but the editor's scripting was unreliable (silent font fallback, `throw` ignored, numbers serialising as null). HTML replaced it as the drawing step.

## Architecture

    build.py (or plain .html)     one generator per screen family; source of truth for the design
       |  writes
    screens/*.html                every screen at a fixed design canvas (e.g. 1920x1080), with ?raw mode
       |  export (headless Chrome via CDP)
    out/<screen>.json             layout tree: frames, text, gradients, strokes, icons, raster nodes
    out/raw/<screen>_<id>.png     each raster piece screenshotted ALONE, transparent, at 2x
       |  generate (Python)
    out/upload/<hash>.png         deduped art (content-hash names), wide plates 3-sliced
    src/ui/Data_<Screen>.luau     one JSON tree per screen (a ModuleScript returning a string)
       |  upload + ledger
    src/ui/AssetIds.luau          art key -> rbxassetid
       |  bundle (.rbxmx) + import
    ServerStorage/<Kit>/Builder   build() instantiates every screen into StarterGui; fit() checks text

Verification runs off the same data: an offline mock renders `Data_<Screen>` with Roblox semantics and diffs it against the HTML screenshot (see [[Verifying UI|verifying-ui.md]]).

## Step 1: the HTML source

- Build at a fixed design canvas (1920x1080 is common). Everything is absolute px on that stage, so the numbers map straight to offsets.
- Wrap each exportable piece in an invisible full-stage group wrapper (`<div class="grp" data-n="Hotbar" data-anchor="bottom">`). The wrapper names the Roblox frame and its screen-edge anchor, and it never changes child coordinates. Check renders stay pixel-identical after adding wrappers.
- Name interactive nodes explicitly (`data-name="SellAllButton"`). Never name a child after a GuiObject property (`Active`, `Selected`, `Visible`, `Position`): `frame.Active` returns the boolean property, not your child. Prefix them (`StateActive`).
- Keep text as live text, never baked into art. Words stay localisable and resizable.
- Gotcha: a double quote inside an inline `style="..."` silently kills that declaration. Data-URI backgrounds and `font-family:"Some Font"` were both lost this way, three separate times. Use single quotes or unquoted `url(data:...)`, or put the value in the stylesheet.

## Step 2: export

A small Node script drives headless Chrome over the DevTools protocol (no Puppeteer needed):

1.  Set the viewport to the design canvas, load `screen.html?raw`, wait for `document.fonts.ready` and every `img.decode()`. Retry broken images: headless Chrome drops 20-40% of images at random on some runs. Judge layout from headless, judge images in a real browser pane.
2.  Inject a walker ([tools/dump_layout.js](https://roclicks.gg/resources/code/ui/tools/dump_layout.js)) that reads `getBoundingClientRect` and `getComputedStyle` for every node and emits Roblox-ready nodes: Frame, TextLabel, ImageLabel, plus gradient stops, border (UIStroke), radius (UICorner), text stroke.
3.  Anything CSS can draw that Roblox can't (stud patterns, clip-path shapes, filters, SVG clusters) becomes a `raster` node with a `data-rid`. For each one, hide every other node (`visibility:hidden`, but whitelist `pattern *` or SVG pattern fills vanish), make the target visible, and screenshot just its rect at device scale 2 on a transparent background.

## Step 3: generate

A Python script ([tools/gen_layout.py](https://roclicks.gg/resources/code/ui/tools/gen_layout.py) is the minimal shape) reads the JSON and:

- Dedupes art by content hash (fuzzy compare for antialias noise) and names files by hash, so re-exports don't re-upload unchanged art.
- Splits images wider or taller than **1024 px** (Roblox's cap). Wide patterned plates become a 3-slice: left cap that ends on a pattern-period boundary, a one-period middle tile with `ScaleType.Tile`, a right cap. The pattern never stretches.
- Converts text: **Roblox `TextSize` = CSS `font-size` x 1.215** (TextSize is line height, not em). Without it every label renders about 83% wide. Collapse runs of whitespace (HTML collapses them, Roblox draws them all; labels came out 6% wide).
- Writes one `Data_<Screen>.luau` per screen: `return [==[ <json> ]==]`. The Builder JSON-decodes it.

## Step 4: upload with a ledger

- Uploads go through whatever authenticated route you have (an MCP upload tool, Open Cloud). Batches of more than about 20 images time out, and some in a timed-out batch still uploaded.
- Keep a ledger (`uploaded.json`, art key -\> asset id). The ledger script merges each upload result and prints only what is still missing. Re-running is safe; nothing uploads twice.
- An upload that returns a **Decal** id renders nothing as `ImageLabel.Image`. Resolve to the Image id.

## Step 5: the Builder

One generic Builder module turns the data into instances:

``` lua
-- Builder.build(): every screen into one ScreenGui under a design-size root
local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false            -- off in StarterGui; the client controller enables its PlayerGui copy

local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(DESIGN_W, DESIGN_H)
root.BackgroundTransparency = 1
root.Parent = gui
Instance.new("UIScale").Parent = root   -- controller sets Scale = min(viewW/DESIGN_W, viewH/DESIGN_H)

for _, name in SCREENS do
    local data = HttpService:JSONDecode(require(folder["Data_" .. name]))
    make(data, root, assets)            -- recursive: Frame/TextLabel/ImageLabel + UIStroke/UICorner/UIGradient
end
```

- The client controller resizes `Root` to `viewport / scale` so edge-anchored groups hug the real screen edges on any aspect ratio.
- `TextSize` is an integer capped at **100**. Build at 2x and wrap big titles in a frame with its own UIScale, so fractional sizes survive rounding.
- After building, run a width-fit pass in edit mode: compare `TextBounds.X` with the HTML ink width and resize labels more than 1.5% off. Run it twice. Expect a median ratio of 1.000 with 90% within +-2.3%.
- Runtime templates (toasts, cards, bubbles, billboards) go into a `ReplicatedStorage` templates folder built by the same Builder. Game code clones templates; it never builds UI with `Instance.new` itself.

## Runtime UI goes through HTML too

Toasts, tutorial cards, build bars, billboards, touch buttons, banners: anything game code creates at runtime is designed in HTML first, the same as static screens. Keep an inventory file listing each runtime element, its purpose, states, size, position and the function that builds it. Show every state on a sheet page and each piece in context over a real game capture. Import only after approval.

Why: runtime UI written straight in Luau drifted into a second, uglier style, and nobody reviewed it.

## Keeping copies of the UI runtime in sync

The bug: the UI runtime module (screens, tweens, fitting, the client API) existed in three places:

1.  the live copy under the built ScreenGui in StarterGui,
2.  a copy inside the Builder's folder in ServerStorage, which `build()` clones into every new gui,
3.  the source tree on disk.

Fixes went into the live copy only. The Builder's copy fell 430 lines behind and missed several API functions. Re-running the Builder, the normal step when importing a new screen, would have installed the stale module, and an unguarded `UI.PageChanged:Connect` would have thrown, leaving no HUD values, no actions and no screens. A review found it by diffing the three copies; it was never seen live.

Rules:

- **Disk is the source of truth.** Edit the module on disk, then push it to every Studio location from the same file. Never hand-edit a Studio copy.
- **The Builder copies from the canonical module**, not from a private snapshot. If it must ship a copy, regenerate that copy in the same push.
- **Hash-check every copy** before and after each push ([tools/check_copies.py](https://roclicks.gg/resources/code/ui/tools/check_copies.py) for disk; a Studio-side check compares `.Source` hashes of the live and Builder copies).
- **Guard optional API calls across modules** (`if UI.PageChanged then ... end`), so a version skew degrades instead of killing init.
- Generated data has copies too: a hand fix made to the live StarterGui (hiding a badge) must also go into `Data_<Screen>.luau`, or the next rebuild undoes it.
- Push Luau as `.rbxmx` model files imported by a tool, not by pasting source through a "set script source" call; one such call mangled every `\n` in string literals.

## Conversion facts

| CSS                            | Roblox                                                                             | Note                                                                          |
|--------------------------------|------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| `font-size: 20px`              | `TextSize = 24` (x1.215)                                                           | TextSize is line height                                                       |
| `-webkit-text-stroke` + shadow | UIStroke (Contextual) + a shadow twin label                                        | stroke thickness: see UIStroke vs UIScale in gui-input-facts                  |
| `border`                       | UIStroke `ApplyStrokeMode = Border`                                                |                                                                               |
| `border-radius`                | UICorner                                                                           |                                                                               |
| `linear-gradient`              | UIGradient (ColorSequence + Rotation)                                              | UIGradient multiplies the base colour: set base to white                      |
| outer `box-shadow` on glass    | outer UIStroke ring, or a clipped crescent below                                   | CSS never paints a shadow under the box; Roblox frames would darken the glass |
| `background-size` tile         | ImageLabel `ScaleType.Tile` + `TileSize`                                           |                                                                               |
| images                         | `ScaleType.Fit`                                                                    | never Stretch, except 9-slice plates which use `Slice`                        |
| Montserrat 800                 | `Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)` | the "Gotham Black" look                                                       |

Luau gotcha from generated controllers: `(x :: T).Prop = v` on the line after one ending in `)` parses as a call ("ambiguous syntax"). Use a local. Run `luau-analyze` on every client file before importing.

Previous: [[Style rules]] · Next: [[HUD and progression patterns]]
