---
tags: [research, roclicks]
source: https://roclicks.gg/resources/thumbnails/review-checklist
retrieved: 2026-10-15
---
# Reviewing thumbnail outputs

Run this on every batch before anything is uploaded. Generate a contact sheet first so you judge images side by side at real size:

Run this on every batch before anything is uploaded. Generate a contact sheet first so you judge images side by side at real size:

``` bash
python3 tools/contact_sheet.py out/ -o sheet.jpg            # overview, filenames labelled
python3 tools/contact_sheet.py out/ -o squint.jpg --squint  # 256 px wide, slightly blurred
```

## Contents

- [[#Hard fails]]
- [[#Readability]]
- [[#Style]]
- [[#Honesty]]
- [[#Picking winners]]

## Hard fails

Reject these outright, or send an edit request to fix them.

- **Title spelling.** Read every letter: "EMPIRE" not "EMPRIE", "1,000,000" with the right number of zeros, the arrow kept. *Why:* garbled text is the first thing that looks cheap at tile size, and lighter models garble long titles.
- **Real-world flags.** Check every flag, banner and patch. Watch especially for red-and-white flags with an eagle, plain tricolours, stars in a canton, and crescents. *Why:* in our batch, prompts that named "fictional" flags still produced a flag resembling a real national one, and a "flags of every nation" idea filled a row with recognisable ones.
- **Real landmarks.** No real capitols, arches, towers or skylines.
- **Real logos or another game's characters.** Check this hardest when references were scraped.
- **Aspect ratio exactly 16:9** (for example 1376×768, 1024×576, 1920×1080). Not square, and no black bars. Check with `python3 -c "from PIL import Image; print(Image.open('x.png').size)"` or the sheet script's warning.
- **No LEGO.** No raised studs, minifigure heads, or squat bodies with stubby arms.
- **No real humans.** Every character is a Roblox avatar, including people in the background.
- **Nothing unsafe for kids.** No gore, and nothing that reads as a real-world conflict or political symbol.

## Readability

- **At 256 px, the subject and action read in one second** (the squint sheet)
- One focal point. Not a row of equal-sized characters
- Title still readable at 256 px. If not, fewer words, bigger
- Subject brighter or more saturated than the background
- Silhouettes separate. No limbs merging into the crowd
- Faces show a clear emotion
- At most one title and one badge or price tag

## Style

- Glossy 3D Roblox render, not a flat illustration or a photo
- Avatars are tall and slim with a small block head
- Consistent with the winning style if this is a variation round
- Effects don't cover faces, the title or the key prop

## Honesty

- Everything shown exists in the game: units, bosses, maps, rewards. *Why:* Roblox demotes experiences whose thumbnails and metadata don't match the game, and misled players bounce in seconds. That hurts more than a lower click rate.
- No fake UI promising free items, Robux or money
- Title matches the game's actual hook

## Picking winners

1.  Score each image 1–3 on the squint sheet alone, without looking at the full-size image.
2.  Keep the top 3. For each, write one line on *why* it won (for example "low angle, endless crowd, giant flag frame").
3.  Spin round 2 off those reasons (prompt-system.md).
4.  Fix small defects with edit requests (the thumbnail prompt's 95% rule), not regeneration.
5.  Upload 2–3 finalists to Roblox's thumbnail A/B test and let it run long enough to reach significance. Keep the game title unchanged during the test so the result reflects the image alone.

Previous: [[Generation pipelines]] · Next: [[Stopping power winning the click]]
