---
tags: [research, roclicks]
source: https://roclicks.gg/resources/tricks/ui-from-a-screenshot
retrieved: 2026-10-15
---
# Make game UI from a screenshot

Screenshot a UI you like, get a pixel-matched HTML copy, then a real Roblox ScreenGui. Two prompts, in order.

The quickest route to UI that looks finished: start from a screenshot of a UI whose style you want, have an AI rebuild it exactly in HTML, change it into your game's screens, then import it into Studio.

## Why HTML first

An AI can measure and fix HTML in seconds: it renders the page, compares it to the screenshot and adjusts until they match. Doing the same in Studio is slow and blind. So the look gets settled in HTML, and Studio only gets the finished numbers.

## The steps

1.  **Recreate it.** Give an AI coding assistant (Claude Code or similar, anything that can run code) the screenshot and [[The HTML UI prompt recreate a UI from a screenshot|the HTML UI prompt]]. It measures every colour, gradient, outline and font size from the image rather than guessing.
2.  **Make it yours.** In the same chat: "Now make my \[shop / HUD / settings / rewards\] screen in exactly this style: \[what's on it\]." Ask for every state (normal, hover, pressed, locked) and a phone layout.
3.  **Import it.** With an assistant connected to Roblox Studio (a Studio MCP server), paste [[The UI import prompt HTML to a Roblox ScreenGui|the UI import prompt]]. It uploads the art, rebuilds all text as live labels and adds the button tweens.

## Paste this between steps 1 and 2

``` text
That matches. Now design my [screen name] in exactly this style, as a new HTML page in the same folder:
- What it shows: [list the buttons, items, numbers and text]
- Every state: normal, hover, pressed, disabled/locked
- A phone layout as well as desktop
Reuse the measured colours, fonts, outlines and panel shapes from the recreation. Do not invent a new style. Render it and check it before showing me.
```

## Get the textures

Stud-style panels need a stud texture: [UI Resources](https://ui-resources.com) has it free, along with glows, frames and backgrounds. Icons should come from one icon pack you have a licence for, never emojis. The full method is in [[HTML-first UI pipeline|the HTML-first UI pipeline]].

Previous: [[Turn your game into ten thumbnail ideas]] · Next: [[Remake a map 11 from a gameplay video]]
