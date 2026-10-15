---
tags: [research, roclicks]
source: https://roclicks.gg/resources/tricks/let-your-ai-drive-flow
retrieved: 2026-10-15
---
# Let your AI agent run Google Flow for you

Hand the whole batch to Claude in Chrome: it uploads references, attaches them, sends ten ideas per message and zips the results.

Once [[Mass-produce thumbnails in Google Flow|mass-producing in Flow]] works by hand, an AI agent that can drive your browser (Claude in Chrome, or any browser agent) can do the clicking. You write the ideas; it runs the batches and hands you one zip.

## The three things that trip agents up

- **The file picker.** An agent can't use the operating system's file dialog. The fix is to stop the page opening it and set the files on the hidden file input directly. The script is in [[Generation pipelines|generation pipelines]].
- **Attaching references.** A plain click in Flow's asset picker adds one item and closes the picker. Shift-click adds many.
- **Sending.** Return adds a new line in a long message, so the agent waits forever. It has to click the send arrow.

## Your part

- Sign in to Flow yourself, in your own browser. The agent must never type a password.
- Approve the final download when it asks.

## Paste this into your agent

``` text
Use my signed-in Chrome to make thumbnails in Google Flow (flow.google.com).

Setup, once:
- In the prompt box's tune menu set model Nano Banana Pro, aspect 16:9, count x1.
- Upload the reference images in [folder] as ref_1, ref_2, ... (convert to JPEG under 10 MB first). You cannot use the native file picker: before clicking + > Upload, patch HTMLInputElement.prototype.click so a file input is captured and appended to the page instead of opening the dialog, then set the files on that input.

For every batch of 10 ideas:
- Click + in the prompt box, search "ref_", SHIFT-click every reference (a plain click adds one and closes the picker), then "Add N items to prompt".
- Paste the thumbnail prompt from [path or URL], then: "Generate images now, no questions. Make 10 SEPARATE thumbnails, one per idea below. Use all attached images as style references only." and the 10 numbered ideas.
- Click the send arrow (Return only adds a newline). Poll for new image tiles; do not sleep a fixed time.

When every batch is done:
- The gallery is virtualized. Scroll its biggest scroll container in steps, collect every img with naturalWidth 1376 (the 16:9 outputs), fetch them in the page, pack one zip and ask me before downloading it.
- Never type passwords, never buy credits, never accept new terms without asking me.

Ideas:
[paste your numbered ideas, 10 per batch]
```

## Why it works

Every rule in that brief is a failure that happened: the agent stuck at the file dialog, attaching one reference instead of ten, pressing Return and waiting forever, and grabbing only the thumbnails that happened to be on screen. Spelling them out up front saves the whole session.

Previous: [[Mass-produce thumbnails in Google Flow]] · Next: [[Turn your game into ten thumbnail ideas]]
