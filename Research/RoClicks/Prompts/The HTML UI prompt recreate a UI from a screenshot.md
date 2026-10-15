---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ai-prompts/ui-html-prompt
retrieved: 2026-10-15
---
# The HTML UI prompt: recreate a UI from a screenshot

Give an AI coding assistant a screenshot of a game UI and get a pixel-matched HTML/CSS page back, measured rather than eyeballed.

Copy the prompt with the button on its box, then paste it into your AI.

The prompt for making game UI with an AI coding assistant. Give it a screenshot of the UI you want and it rebuilds it as an HTML/CSS page that matches pixel for pixel: every position, colour, gradient, outline and font size measured from the reference with scripts, never guessed.

Use it with an assistant that can run code (Claude Code or similar). Then take the finished page into Roblox with [[The UI import prompt HTML to a Roblox ScreenGui|the UI import prompt]]. The full pipeline behind both is in [[HTML-first UI pipeline]].

## The prompt

``` text
# Task: Recreate a game UI from a reference screenshot as a 1:1 HTML/CSS page

You'll get a screenshot of a game UI (usually Roblox-style). Rebuild it as an HTML page that matches the reference pixel for pixel when laid on top of it. The person checks it side by side and notices everything: wrong colours, a missing rim, text 2px too big, a gradient that's slightly off.

## Hard rules
1. **Build everything from scratch.** Never crop, trace, overlay, or inpaint the screenshot to make the UI. The screenshot is only a measuring tape. The one exception: the game scene *behind* see-through glass panels may be derived from the screenshot, since it isn't UI.
2. **Measure, never eyeball.** Every position, size, colour, gradient stop, outline width, and corner radius comes from a number read off the reference pixels with a script (Python + PIL + numpy). If you catch yourself guessing a value, measure it.
3. **Never reproduce watermarks or designer logos** in the reference. Also treat them as noise while measuring: use low percentiles or watermark-free columns so they don't lift your colours.
4. **Text is live HTML text**, never baked into images.
5. **Icons and textures:** use the asset sources you're given (e.g. a specific icon pack, textures from ui-resources.com). Never use emojis. If the reference uses a recognisable texture (checkerboard, stud, smoke, brushed metal), find the matching one in the given source and use it rather than redrawing it.
6. **Elements of the same type share one component.** Build one shared function for buttons, cards, slots, and so on, and vary only the measured colours. If they aren't consistent, it looks wrong.

## Process

### 1. Set up
- Make a project folder and save the reference as `ref.png` (convert webp to png). Note its exact pixel size: the page is built at exactly that size with absolute px positioning.
- Serve the folder with a local static server so you can render it.

### 2. Map the layout with gridded zoom crops
- Write a small script that crops a region, scales it 3× with nearest-neighbour, and draws a grid line every 10px, labelled every 50px, in reference coordinates. Crop each quadrant or region and look at it. That's how you read coordinates and see fine details (rims, ornaments, gradient bands).
- List every element: outer frame, header, each panel, each button, card, slot, icon, text label, divider, and ornament.

### 3. Measure edges with profiles
- Take per-pixel colour profiles across each element's edges: walk inward from each side's midpoint and print every pixel's colour. That shows the structure layer by layer, e.g. `outer glow → 2px black outline → 1px antialias → 2px bright rim → body gradient`. Profile **all four sides**: top, bottom, and side rims usually differ in colour.
- Record for each element: outer box, outline width and colour, rim widths and colours per side, and corner radius.

### 4. Measure surfaces (gradients, textures, patterns)
- **Vertical gradients:** for each 1px row, take the median colour of text-free and icon-free columns. Emit a CSS `linear-gradient` with a hard stop per pixel row (`#c1 0px 1px, #c2 1px 2px, …`). Don't approximate with 3 stops.
- **Repeating patterns (checkerboards, studs, stripes):** find the lattice by brute force. High-pass the luminance (subtract each row's mean), then for each candidate cell size, x-phase, and y-phase, correlate it with a ±1 checker pattern. The best correlation gives cell size, phase, and which parity is light. Then measure pattern strength per row as `k = (light − dark) / (255 − dark)`, i.e. a white overlay at alpha k. Draw it as a white layer with per-row alpha, masked by the texture asset (CSS `mask-image`) scaled to the measured cell size and positioned at the measured phase.
- **Glass (see-through dark panels):** measure alpha from the continuity of the game world across the panel outline. The inside colour ≈ outside colour × (1 − alpha); dark game UIs are often black at ~0.75–0.8. Nested sub-panels add their own alpha on top. Never give a glass panel an opaque fill.
- **Measure only in text-free and icon-free columns.** If text crosses the columns you measure, the text outline shows up as a fake dark band or pattern in your gradient. Pick columns that avoid all text and icons for each plate.

### 5. Build the page with a generator script
- Write `build.py` that holds all measured data (or reads it from a JSON written by a separate measure script) and generates `index.html`.
- Absolute px positioning on a stage exactly the reference size. In normal view, scale the stage to fit the window; `?raw` shows it at 1:1 for screenshots.
- Layer order: world stand-in (if there's glass) → frame/glass → panels → plates (base rows, then pattern overlay, then rims as inset box-shadows) → icons → text.
- Ornamental line-work (fantasy/gothic frames, flourishes, dividers) goes in one SVG overlay. Give it a single userSpaceOnUse vertical metal gradient so every line is lit consistently top to bottom. Fading lines need their own userSpaceOnUse gradient: a bounding-box gradient on a zero-height line renders nothing.
- Add a "compare with reference" slider that fades `ref.png` over the page.

### 6. Text
- **Identify the font** by comparing glyph shapes (e.g. chunky Roblox "Gotham Black" ≈ Montserrat 800; small-caps fantasy serif ≈ Cinzel). Load it from Google Fonts with `display=block`.
- **Measure each label's box** from its fill pixels (bright/white pixels) rather than its outline. Outline-based boxes get contaminated on dark backgrounds.
- **Outlined text:** the element paints `-webkit-text-stroke` plus `text-shadow` in the outline colour, and a `::after { content: attr(data-t) }` paints the fill (a gradient via `background-clip: text`) on top. Never stroke the fill layer, since overlapping glyph contours draw lines through letters.
- **Measure text fill as a gradient**, from the top third vs bottom third of the letters. Letters are rarely flat white.
- **Auto-fit every label:** loop 4–5 times. Render each label alone on black (`?labels=KEY`), measure its rendered ink box, then adjust font-size (height), scaleX (width), and x/y offset toward the reference box. Stop when every label is within 1px.

### 7. Icons
- Compute each icon PNG's alpha bounding box, then scale and position the image so that bounding box lands on the icon's measured ink box in the reference. Don't just drop a square image in.

### 8. Verify with numbers, then iterate
- Render headless Chrome at the exact size (and at 2× device scale, which is how it's usually viewed):
  `chrome --headless=new --window-size=W,H --run-all-compositor-stages-before-draw --virtual-time-budget=10000 --screenshot=render.png "http://localhost:PORT/?raw"`
  Headless Chrome sometimes drops `<img>`s. If icons are missing, confirm in a real browser that they load (`naturalWidth > 0`) before "fixing" anything.
- Make side-by-side crops (reference | render) of each region at 2–4× zoom and compare element by element.
- Compare region colours numerically: the 30th-percentile colour of each panel, plate, and background region in the reference vs the render. Fix anything off by more than about 4 levels.
- Check siblings for consistency: all buttons get the same rim structure, all cards the same treatment.
- Repeat until every region is close. When you report, give the numbers (e.g. "all labels within 1px, panel colours within 3 levels"), what still differs, and why (e.g. a placeholder icon because the pack has no helmet).

## Learning from feedback
When the person corrects something, work out the **general rule** behind it (not "the close button was wrong" but "measure every button as rigorously as text"). Apply it to every element it touches, not only the one they pointed at, and keep a running list of these rules for future UIs.
```

Previous: [[Five art-style prompts for Roblox thumbnails]] · Next: [[The UI import prompt HTML to a Roblox ScreenGui]]
