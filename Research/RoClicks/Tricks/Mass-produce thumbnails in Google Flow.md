---
tags: [research, roclicks]
source: https://roclicks.gg/resources/tricks/mass-produce-thumbnails-in-flow
retrieved: 2026-10-15
---
# Mass-produce thumbnails in Google Flow

Ten thumbnails per message, every one styled by your references. The setup that gets a whole batch of options in about two minutes.

The fastest way to get a big pile of thumbnail options to choose from. Google Flow's agent panel runs many image generations at once, so one message can return ten finished thumbnails, all matched to the style of the references you attach.

## What you need

- A Google account with Flow (the paid tier gets Nano Banana Pro).
- 4 to 10 reference thumbnails that share one style: the same render quality, title font and colour grade. Your own best thumbnails are the best references. Top-chart thumbnails are fine as private style guidance, never to copy.
- [[The RoClicks thumbnail prompt]].

## Set it up once

1.  Open Flow and the **tune icon** in the prompt box. Set the model to **Nano Banana Pro** (the lighter models garble long titles), the aspect to **16:9**, and the count to **x1**. With x2 it sometimes makes two of each idea and sometimes doesn't, which scrambles your numbering.
2.  Upload your references and name them `ref_1`, `ref_2` and so on. Convert them to JPEG under 10 MB first.

## Every batch

1.  Click **+** in the prompt box, search `ref_`, and **shift-click** every reference. A plain click adds only one and closes the picker. Then click **Add N items to prompt**. Attachments don't carry over, so do this for every message.
2.  Paste the message below, with your ten ideas filled in.
3.  Click the **send arrow**. Return only adds a new line in a long message.
4.  Wait about one to two minutes. Then pick winners with [[#the squint test]].

## Paste this

Paste the full [[The RoClicks thumbnail prompt|RoClicks thumbnail prompt]] first (delete its `[Describe your thumbnail here...]` line), then this:

``` text
Generate images now, no questions. Make 10 SEPARATE thumbnails, one per idea below. Use all attached images as style references only: match their render quality, title style and colour grade, but never copy their characters, text or logos.

Game: [one line about your game and its genre]

1. [scene, main subject and what they are doing, title text in quotes]
2. ...
3. ...
4. ...
5. ...
6. ...
7. ...
8. ...
9. ...
10. ...
```

No ideas yet? [[Turn your game into ten thumbnail ideas]] writes the list for you.

## Why it works

- **References beat words.** "Glossy Roblox Discover thumbnail" is vague. Ten example images pin down the render, the camera height, the title font and the colour grade all at once.
- **Ten is the sweet spot.** More than ten in one message started dropping or merging ideas. A batch of 35 is four messages.
- **"Generate images now, no questions"** stops the agent replying with text when one idea is ambiguous.

## Pick the winners

- Put the batch on one sheet and blur it to thumb size. Whatever still reads in one second is a candidate. The [contact sheet tool](https://roclicks.gg/resources/code/thumbnails/tools/contact_sheet.py) does both (`--squint`).
- Fix small defects with an edit in the same chat ("make the title bigger"), not a new generation.
- Once you have winners, swap them in as your references. The style converges on yours.

The full write-up, including downloading a whole gallery at once: [[Generation pipelines|generation pipelines]].

Next: [[Let your AI agent run Google Flow for you]]
