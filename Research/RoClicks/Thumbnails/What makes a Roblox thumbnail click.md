---
tags: [research, roclicks]
source: https://roclicks.gg/resources/thumbnails/what-makes-a-thumbnail-click
retrieved: 2026-10-15
---
# What makes a Roblox thumbnail click

How to make Roblox game thumbnails that get clicked: what the image has to do, a reusable prompt system for AI image models, the two generation pipelines we used (and their traps), and small tools...

How to make Roblox game thumbnails that get clicked: what the image has to do, a reusable prompt system for AI image models, the two generation pipelines we used (and their traps), and small tools for picking prompts and reviewing results.

Distilled from a few rounds of real thumbnail work: about 60 images for a strategy tycoon, plus a thumbnail-generator side project where the prompt was tuned against real user complaints.

## Contents

| File                                                                                | What it is                                                                           |
|-------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| [[What makes a Roblox thumbnail click|README.md]]                     | This page: what makes a thumbnail click, plus the rules everything else follows      |
| [[The RoClicks thumbnail prompt]]             | The prompt the RoClicks generator ran on. Paste it, then describe your thumbnail     |
| [[Thumbnail idea patterns|idea-patterns.md]]                             | 30 generic thumbnail ideas (evolution lineup, X vs Y, 1 → 1,000,000 ...)             |
| [[Generation pipelines|pipelines.md]]                                     | Google Flow driven by browser automation, Meshy text/image-to-image, and the gotchas |
| [[Reviewing thumbnail outputs|review-checklist.md]]                       | Checks for every output before it goes live                                          |
| [tools/build_picker.py](https://roclicks.gg/resources/code/thumbnails/tools/build_picker.py)           | Turns a requests file into a one-page "prompt picker" with copy buttons              |
| [tools/picker_template.html](https://roclicks.gg/resources/code/thumbnails/tools/picker_template.html) | The page the build script fills in                                                   |
| [tools/requests.example.txt](https://roclicks.gg/resources/code/thumbnails/tools/requests.example.txt) | Example requests file in the format the script reads                                 |
| [tools/contact_sheet.py](https://roclicks.gg/resources/code/thumbnails/tools/contact_sheet.py)         | PIL contact sheet, with a 256 px "squint" mode                                       |
| examples/                                                                           | Three of our own generated thumbnails, downscaled                                    |

## What makes a Roblox thumbnail click

The Discover page is a wall of small tiles. Your image is about 256 px wide next to dozens of others, and players decide in under a second. Everything below follows from that.

### 1. One clear subject

- One focal point, taking up roughly 40–60% of the frame. *Why:* a row of equal-sized characters spread evenly has no focal point and reads as noise at tile size. This was the single most common reason images were rejected.
- If the idea has a "special" character (the boss, the impostor, the max-level unit), make it obviously bigger, brighter or isolated. A special character who looks like everyone else is wasted.
- Silhouettes must not merge. Leave space around faces and around the key prop.

### 2. A low hero angle

- Put the camera low and looking up for power, scale and "epic". Parades, bosses, giant units and generals all read stronger from ground level.
- Use a high three-quarter angle only when the *map itself* is the pitch (conquest, territory, a factory floor).
- Use forced perspective when something should fly at the viewer (a ball, a missile, a crate).

### 3. Contrast, not detail

- Make the subject brighter or more saturated than the background, never mid-tone on mid-tone.
- Use saturated Roblox colours: blue sky, green baseplate, gold rewards. Muted "realistic" outfits (denim, pastels) disappear at small size.
- Use rim light on the hero. It separates the hero from a busy background more cheaply than anything else.
- **Squint test:** shrink to 256 px wide and blur. If you can't tell the subject and the action apart in one second, the image fails. `tools/contact_sheet.py --squint` does this for a whole batch.

### 4. A bold, outlined title

- Use 1–4 words in white with a thick black outline, across the top, in Roblox-style heavy rounded caps. Nearly every top performer in our batches used exactly this.
- The title states the hook, not the game name: "MAX LEVEL TANK", "RAID INCOMING!", "1 TANK VS 1,000".
- A secondary price tag or badge is fine ("\$1,000,000", "8/8", a countdown "0:10"). Never use more than two text elements. *Why:* a third one shrinks all of them below readable size.
- Text is optional. Some genres (horror, mood pieces) work better without any.

### 5. Show the mechanic

The best images *are* the game loop in one frame: a progression lineup, a before/after, a reward bursting open, a raid coming over a hill. If a player can't guess what they will *do* in the game, the click turns into a bounce. That hurts more than not getting the click, because Roblox measures what happens after the click too.

### 6. 16:9, always

- Roblox game thumbnails are 16:9 (1920×1080 is the upload target; 1376×768 or 1024×576 from generators upscales fine).
- Generate natively at 16:9. Never crop a square image down. *Why:* cropping cuts off the title or the subject's head, and models compose square images for a square frame. See [[Generation pipelines|pipelines.md]]: some endpoints silently return square output.
- Tell the model not to add letterbox or cinematic black bars. *Why:* a cover-crop can't remove them without losing the frame.

### 7. Rules that are not negotiable

- **Fictional flags only.** Every flag, banner and emblem is invented: name its colours and symbol in the prompt and add "(no real-world flags)". *Why:* real national flags are a moderation and audience risk in a kids' game. Models drift to real ones anyway (a red-and-white eagle flag and a row of recognisable national flags both showed up in our batch), so the checklist catches them.
- **Invented landmarks only.** Say "an invented domed capitol building, not a real building". *Why:* without that, "capitol" became the US Capitol and "victory arch" became the Arc de Triomphe.
- **Roblox, never LEGO.** Avatars are tall and slim, about 3× taller than wide, with a small block head and long rectangular limbs. No raised studs, no minifigure heads. *Why:* "blocky" alone collapses into LEGO minifigures, and so does "chunky".
- **Copy no one's art.** Use reference thumbnails for style (angle, lighting, title treatment, colour). Never reproduce a specific competitor composition, character or logo 1:1. Spin the *idea*: their "army parade" becomes your "tank column", "victory arch" or "paratrooper sky".

## Workflow in one screen

1.  Pick 5–10 ideas from [[Thumbnail idea patterns|idea-patterns.md]] that show *your* mechanic.
2.  Write one request per idea (prompt-system.md) into a requests file.
3.  `python3 tools/build_picker.py requests.txt` gives a page with "copy full prompt" buttons, so a collaborator can generate by hand too.
4.  Generate with reference images attached ([[Generation pipelines|pipelines.md]]). Batch 10 at a time.
5.  `python3 tools/contact_sheet.py out/ --squint` and review with [[Reviewing thumbnail outputs|review-checklist.md]].
6.  Spin variations off the winners, not off the losers. In our run the best first-round image (an endless parade, low angle, a giant fictional flag) became the template for the next 12.
7.  A/B test the top 2–3 using Roblox's thumbnail experiment, with a stable title.

## Examples

Our own outputs (Google Flow, Nano Banana Pro, 10 references attached), downscaled:

- `examples/evolution_lineup.jpg`: the "evolution lineup" pattern, with upgrade arrows between stages
- `examples/cheap_vs_rich_split.jpg`: the "\$1 vs \$1,000,000" hard split, with price tags as the secondary text
- `examples/reward_crate.jpg`: the "legendary crate" reward pattern, using a light beam, a loot spill and characters running in

## Checklist

- One subject at 40–60% of the frame, separate from the background
- Low hero angle, unless the map is the pitch
- Title of 1–4 words, white with a black outline, spelled right
- 16:9 natively, no black bars
- Only fictional flags and invented landmarks
- Roblox proportions, not LEGO
- Passes the 256 px squint test
- Shows what the player actually does in the game

Next: [[Thumbnail idea patterns]]
