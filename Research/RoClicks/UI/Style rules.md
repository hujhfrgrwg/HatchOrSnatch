---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ui/style-rules
retrieved: 2026-10-15
---
# Style rules

Rules that held across every project. Each one exists because breaking it got a screen rejected.

Rules that held across every project. Each one exists because breaking it got a screen rejected.

## Contents

- [[#Icons: one licensed pack, never emojis]]
- [[#Who makes what]]
- [[#Text: bold, outlined, phone-readable]]
- [[#Panels and buttons]]
- [[#Consistency]]
- [[#Less on screen (kids especially)]]
- [[#Mobile layout]]
- [[#Motion and sound]]

## Icons: one licensed pack, never emojis

- **Pick one icon pack per game and never mix packs.** A pack is one artist's line weight, corner radius, perspective and palette. Two packs side by side read as sloppy even when each icon is good alone. Generated icons next to pack icons have the same problem. Enforce it in tooling: the icon-copy script should throw on any path outside the pinned pack.
- **Never emojis.** They render differently per platform, ignore your outline style and read as cheap.
- **Search the whole pack before declaring an icon missing** (`find pack/ -iname "*crown*"`). Most "missing" icons were under a different name.
- **Read the licence.** Typical purchased packs allow commercial use in your own games but forbid resale and client work. Some explicitly **forbid AI training**: composite their files into UI, never pass them to an image model as a reference. Record the licence beside the pack path in the project.
- Don't commit the pack to a public repo. Commit the list of icon names used and a copy script.
- Close buttons are a **text "X"** (white, black outline), not an icon. It matches the font and scales.

## Who makes what

| Layer                                                 | Source                                                                   |
|-------------------------------------------------------|--------------------------------------------------------------------------|
| Backgrounds, panel frames, banner plates, card frames | CSS (or generated art) with empty interiors and no text, so they 9-slice |
| Icons and glyphs on those surfaces                    | the one icon pack                                                        |
| Every word                                            | live text (TextLabel + UIStroke), never baked into art                   |
| Textures (studs, noise, paper)                        | one texture source, tiled, phased to the stage grid                      |

Why: baked text can't be localised, resized or fixed; art with content inside can't be 9-sliced.

## Text: bold, outlined, phone-readable

- **Bold display font** for everything a player reads at a glance. Montserrat 800 gives the common "Gotham Black" Roblox look (900 reads too heavy). Fredoka One for rounder, friendlier games. Use fonts Roblox ships; check the family path exists (`rbxasset://fonts/families/<Name>.json`).
- **Thick near-black outline** on all text over art or the world: about 3 px on titles, 1.5-2.5 px on body lines, at design scale. A background-tinted outline vanishes on dark cards.
- **Minimum sizes on a phone.** A landscape phone shows a 1920x1080 design canvas at about 0.36x. Body text at least 26 design px (about 9-10 screen px), titles 40+. `UITextSizeConstraint.MinTextSize` around 14 design px, never 6: a 6 px minimum on a 0.36 scale is a 2 px smear.
- **Short strings.** Toasts under about 40 characters with one verb ("Tier 2! Upgrade your Barracks"). Shrinking a long string to fit always loses on phones. Put the detail in the screen it refers to.
- **Lines shrink to fit, never wrap** in fixed-height cards; set `TextTruncate = AtEnd` as the floor.
- Hide keyboard hints ("Press E", key-number chips) when `TouchEnabled and not KeyboardEnabled`.
- Never show raw ids or placeholders: "Capital: c_17", "Research complete: ?", "+0.6/s bread" when the resource is called "Rations". Fall back to friendly words.

## Panels and buttons

- **Dark panel bodies are see-through glass** (about 0.7-0.75 black) so the world reads through. Don't give the outer frame a fill; draw its outline only, or the glass reads opaque.
- **Every plate edge has structure**: a thin dark outline (1-2 px), a 1-2 px bright inner rim on all four sides (top/side/bottom colours differ), then the gradient, then a darker bottom band. A top-only highlight reads flat.
- **Primary action = biggest, brightest, one per screen.** Green for go, red for destructive or war, blue for neutral, grey when unaffordable (with the shortfall shown, not just greyed).
- Disabled is not invisible: an unaffordable button stays, turns grey, and tapping it says how much is missing and pulses the currency.

## Consistency

- **One style for world and UI.** A studded-plastic world with a sleek flat UI (or the reverse) was rejected. Decide the style once per game and hold it across maps, props and every GUI.
- **Same-type elements share one treatment.** All buttons studded or none, same outline, rim, band and gradient structure; vary only colour. Build one shared component (`plate(color)`) and reuse it.
- **One number format everywhere** (see [[Feedback patterns|patterns-feedback.md]]).
- **One toast style, one confirm dialog, one close button** for the whole game.

## Less on screen (kids especially)

A review of a kids' tycoon HUD counted about **30** separate readouts: 3 tabs, a subtitle, a tip card, 3 buttons each with a badge, an event timer, gems, cash, a "Friend Boost +0%", 8 hotbar slots each with a count and a key number, 2 red "OFF" upsell buttons, a ring label and 4 x/y counters. To a kid that is noise, and the fake badges trained them to ignore badges.

What replaced it:

- **Start with cash plus one "Next goal" pill.** The pill always says the single next thing to do and is tappable (see [[HUD and progression patterns|patterns.md]]).
- **Reveal pieces when they matter**: gems after the first gem, Research after the tutorial, conquest counters after the first conquest. These stay once revealed.
- **Capacity counters only while full**, as a red chip ("Need more houses!"). Never a permanent x/y.
- **Timers only while something runs.** A frozen "00:00" under an icon tells nobody anything.
- **Badges are data-driven.** A badge means "something you can act on right now" (a research can start and a slot is free; a free reward is waiting). One badge at a time, on the most useful button.
- **No permanent upsell buttons.** "Auto Sell: OFF" in red on screen forever reads as "you're doing it wrong". Show paid toggles after purchase; pitch once at a natural moment.
- **Delete dead UI.** A "+0%" boost for a feature that doesn't exist is worse than nothing.
- **Settings: four rows** (music, sound, graphics, codes). Fix sensible defaults for the rest.
- **Default to the simple choice.** "Send everyone" plus one big Attack button and an Easy / Close / Hard colour verdict, with fine controls behind a small toggle. Drop percentages kids don't use.

The same rule for immersive games (horror, parkour): no panels over the world. Objective and prompts are small outlined text on the scene; meters live on their button; show one tracked objective only.

## Mobile layout

- Draw Roblox's own controls (top bar, thumbstick, jump button) as dashed placeholders in every mobile mockup and keep clear of them.
- Primary actions under the right thumb; menus not needed every second become world stands (walk-up ProximityPrompts) instead of HUD buttons.
- On mobile the player taps the **world**, not buttons: a tap acts at the tap point. Keep on-screen buttons only for actions with no world target.
- Render a phone HUD and a PC HUD; don't assume one layout scales.
- Every action reachable on PC must be reachable on touch. A prestige button that existed only in the desktop HUD soft-locked the prestige loop for every phone player.

## Motion and sound

- Open: pop in with a Back ease (scale 0.6 -\> 1). Close: quick scale out.
- Buttons: hover grow (1.06), press sink, release spring, a click sound. Idle motion on key icons.
- Count numbers up to their new value; cancel the previous tween and land exactly on the target, or two overlapping tweens leave the wrong final number.
- Reuse one small set of UI sounds (click, hover, purchase, reward) across the game.

Previous: [[UI overview]] · Next: [[HTML-first UI pipeline]]
