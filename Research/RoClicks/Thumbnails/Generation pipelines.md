---
tags: [research, roclicks]
source: https://roclicks.gg/resources/thumbnails/pipelines
retrieved: 2026-10-15
---
# Generation pipelines

Two pipelines produced real thumbnails. Reference images beat text-only prompting by a wide margin, so the default is Google Flow with references attached. Meshy is the scriptable fallback.

Two pipelines produced real thumbnails. **Reference images beat text-only prompting by a wide margin**, so the default is Google Flow with references attached. Meshy is the scriptable fallback.

## Contents

- [[#Result: references win]]
- [[#Pipeline A: Google Flow via browser automation]]
- [[#Pipeline B: Meshy text-to-image / image-to-image]]
- [[#Choosing references]]
- [[#Checklist]]

## Result: references win

|                                       | Flow + 10 references                                      | Meshy text-to-image (no refs)     |
|---------------------------------------|-----------------------------------------------------------|-----------------------------------|
| Style match to real Roblox thumbnails | Close: same glossy render, title treatment, camera height | Generic. Correct but "AI-looking" |
| Title spelling                        | Correct with Nano Banana Pro                              | Correct with nano-banana-pro      |
| Aspect                                | 16:9 native (1376×768)                                    | 16:9 only via text-to-image       |
| Prompt room                           | Full thumbnail prompt + request                           | 600 characters                    |
| Automation                            | Browser-driven, semi-manual                               | Clean API/MCP call                |

*Why references win:* words like "glossy Roblox Discover thumbnail" are vague. Ten example images pin down the render quality, the camera height, the title font and the colour grade all at once.

## Pipeline A: Google Flow via browser automation

Google Flow (Google's image/video studio) has a chat-agent panel that can run many image generations in parallel. We drove it with a browser-automation agent (Claude in Chrome) **in the developer's own signed-in Chrome**.

*Why the developer's own browser:* the agent must never type passwords or create accounts. The developer signs in once, with whatever plan they pay for, and the agent works inside that session.

### Settings

Open the tune icon in the prompt box and set:

- Model: **Nano Banana Pro**. It spells titles correctly. Lighter models garble long titles.
- Aspect ratio: **16:9**
- Count: **x1**. *Why:* with x2 the agent sometimes makes two of each idea and sometimes doesn't, which makes numbering unpredictable.

### Batch size: 10 ideas per message

Write one agent message: "Make 10 SEPARATE thumbnails, one per idea below. Use all attached images as style references." Then list 10 numbered requests. The agent fans them out in parallel and finishes in about 1–2 minutes. A batch of 35 took 4 messages. More than 10 per message started dropping or merging ideas.

### Uploading references without the native file picker

An automation agent can't operate the OS file dialog. So you stop the page from opening the dialog, and instead set files on the `<input type=file>` element directly.

1.  Before clicking **+ → Upload**, patch the input element so the click is captured instead of opening the picker:

``` js
// Run in the page. Captures the next file input instead of opening the native picker.
(() => {
  const grab = (input) => {
    input.id = input.id || 'agent-file-input';
    input.setAttribute('aria-label', 'agent file input');
    if (!input.isConnected) document.body.appendChild(input);
    window.__lastFileInput = input;
  };
  const origClick = HTMLInputElement.prototype.click;
  HTMLInputElement.prototype.click = function () {
    if (this.type === 'file') return grab(this);
    return origClick.call(this);
  };
  if (HTMLInputElement.prototype.showPicker) {
    HTMLInputElement.prototype.showPicker = function () {
      if (this.type === 'file') return grab(this);
    };
  }
})();
```

2.  Click **+ → Upload**. Flow creates a detached input, and the patch keeps it.
3.  Flow may detach it again. Re-append `window.__lastFileInput` to `document.body`, then `find` it by its aria-label and use the automation tool's file-upload action with local paths.
4.  Each upload call is capped at about 10 MB. **Convert references to JPEG** (quality 85, max 1600 px wide) first.
5.  Name the files `ref_1.jpg … ref_10.jpg`. The prefix is what you search for in step 2 of the next section.

### Attaching up to 10 references to every prompt

1.  Click **+** in the prompt box to open the asset picker and search `ref_`.
2.  **Shift-click every row.** A plain click adds just that one item *and closes the picker*.
3.  Click **"Add N items to prompt"**. Up to 10 references per prompt.
4.  Re-attach for every new message. Attachments don't carry over.

### Sending

- **Click the send arrow. Don't press Return.** In a long multi-line prompt, Return inserts a newline instead of sending. An agent that "pressed Enter" will wait forever.
- After sending, poll for new image tiles. Don't sleep for a fixed time.

### Downloading through an in-page zip

You need an in-page zip for two reasons. The gallery is **virtualized**, so only on-screen tiles exist in the DOM. And clicking 40 separate download buttons means 40 download prompts. Instead:

1.  Find the largest scrollable container, scroll it in steps, and collect every `<img>` whose `naturalWidth === 1376`. That width means a 16:9 output, which also skips avatars and previews.
2.  `fetch()` each src inside the page, so the session cookies apply.
3.  Pack them into one zip in memory and trigger a single download. This counts as a download, so **the developer approves it first.**

``` js
// Collect generated 16:9 images from a virtualized gallery, zip them in-page, download once.
async function zipGallery(name = 'thumbnails.zip') {
  const box = [...document.querySelectorAll('*')]
    .filter(e => e.scrollHeight > e.clientHeight + 50)
    .sort((a, b) => b.scrollHeight - a.scrollHeight)[0];
  const srcs = new Set();
  for (let y = 0; y <= box.scrollHeight; y += box.clientHeight * 0.8) {
    box.scrollTop = y;
    await new Promise(r => setTimeout(r, 400));
    document.querySelectorAll('img').forEach(i => { if (i.naturalWidth === 1376) srcs.add(i.src); });
  }
  const crcTable = [...Array(256)].map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc32 = (b) => { let c = 0xFFFFFFFF; for (const x of b) c = crcTable[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; };
  const parts = [], central = []; let offset = 0, i = 0;
  for (const src of srcs) {
    const data = new Uint8Array(await (await fetch(src)).arrayBuffer());
    const fname = new TextEncoder().encode(`img_${String(++i).padStart(2, '0')}.png`);
    const crc = crc32(data), h = new DataView(new ArrayBuffer(30));
    h.setUint32(0, 0x04034b50, true); h.setUint16(4, 20, true); h.setUint32(14, crc, true);
    h.setUint32(18, data.length, true); h.setUint32(22, data.length, true); h.setUint16(26, fname.length, true);
    parts.push(h, fname, data);
    const c = new DataView(new ArrayBuffer(46));
    c.setUint32(0, 0x02014b50, true); c.setUint16(4, 20, true); c.setUint16(6, 20, true); c.setUint32(16, crc, true);
    c.setUint32(20, data.length, true); c.setUint32(24, data.length, true); c.setUint16(28, fname.length, true);
    c.setUint32(42, offset, true); central.push(c, fname);
    offset += 30 + fname.length + data.length;
  }
  const size = central.reduce((s, p) => s + p.byteLength, 0), e = new DataView(new ArrayBuffer(22));
  e.setUint32(0, 0x06054b50, true); e.setUint16(8, i, true); e.setUint16(10, i, true);
  e.setUint32(12, size, true); e.setUint32(16, offset, true);
  const a = Object.assign(document.createElement('a'), { download: name,
    href: URL.createObjectURL(new Blob([...parts, ...central, e], { type: 'application/zip' })) });
  a.click();
  return i;
}
```

This is a store-only zip (no compression; the PNGs are already compressed) with no library, because the page's CSP may block CDN scripts. The file order is gallery order, not prompt order, so match the images back to prompts by their titles on the contact sheet.

### Flow gotchas

- An old Flow URL redirects to the new one. The new UI is an agent chat panel on the right, not a plain prompt box.
- Do the actions one at a time and take a screenshot after each. Picker positions move when the panel scrolls.
- The agent sometimes writes a text reply instead of images when a request is ambiguous. Start the message with "Generate images now, no questions."

## Pipeline B: Meshy text-to-image / image-to-image

Meshy's image endpoints (also available through its MCP server) are scriptable and cheap. Use them for quick drafts or when no browser is available.

### Credit costs (per image)

| Model               | Text-to-image | Image-to-image |
|---------------------|---------------|----------------|
| nano-banana         | 3             | 3              |
| nano-banana-2       | 6             | 6              |
| **nano-banana-pro** | **9**         | **9**          |
| gpt-image-2         | 9             | 12             |

Use **nano-banana-pro**. It spells titles correctly. Always state the total cost and get approval before a batch: 20 images × 9 = 180 credits.

### Gotchas

- **Image-to-image always returns square output (1024×1024),** even from a 16:9 reference. You can't crop it to a usable thumbnail without losing the title or the subject. *Use text-to-image for finals.*
- **Text-to-image supports `aspect_ratio: "16:9"`** and returns 1376×768.
- **Prompt cap is 600 characters.** The full thumbnail prompt doesn't fit. Put the essentials into the prompt itself, for example: `Roblox game thumbnail, glossy 3D render, tall slim blocky Roblox avatars (not LEGO), green Roblox baseplate, huge bold white title with thick black outline: "..."`.
- **Models drift to real landmarks.** "Capitol" became the US Capitol, and "victory arch" became the Arc de Triomphe. Always write "invented, not a real building".
- **"Giant" needs extreme scale wording.** "A giant commander" came out soldier-sized. "A COLOSSAL commander, 50× taller than the army, the soldiers ant-sized at his feet" worked.
- Flags drift toward real ones just as in Flow. Name the colours and the emblem, and add "fictional flag, no real-world flags".

## Choosing references

- Use 8–10 images that share **one** style: the same render quality, title font and colour grade. A mixed set averages into mush.
- Real top-chart thumbnails are fine as *private style guidance*. Don't commit them to a repo or publish them, and never ask for a reproduction.
- Once you have winners of your own, **replace scraped references with your own best outputs**. The style then converges on yours, and nothing from another game leaks in. (A scraped reference once injected a dragon nobody asked for.)
- Remove references that contain real flags, logos or legible text you don't want copied.

## Checklist

- Developer is signed in to Flow in their own browser. The agent never types credentials
- Nano Banana Pro, 16:9, x1
- References converted to JPEG under 10 MB, named `ref_N`
- All references shift-clicked into every message
- 10 ideas per message, sent with the arrow button
- Download approved by the developer, collected through the in-page zip
- Meshy: text-to-image only for finals, cost approved, prompt ≤ 600 chars with "invented" and scale numbers

Previous: [[Thumbnail idea patterns]] · Next: [[Reviewing thumbnail outputs]]
