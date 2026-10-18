---
tags: [delivery, ui, icon]
ticket: HOS-ICON-001
date: 2026-10-18
requested_by: Matthew
---
# HOS-ICON-001: Emote Crate icon

Matthew: "Generate a 2d icon for the emote crate. Rn it's the default crate icon. Take inspiration from our other icon styles." Then: "fit the tune note inside the purple. so make it smaller."

![Icon and sizes](HOS-ICON-001/emote_crate_icon_preview.png)

## What it is
`docs/HOS-ICON-001/emote_crate_icon.png` is 512 × 512 with a transparent background. It's in the same family as the Weapon Crate and Dual Wield chest icons:
- a chunky 3/4-view chest with gold corner bands, top and bottom bands, rivets and a dark outline
- an open lid with light pouring out
- an emblem shield on the front

To make it read as the emote one, it has:
- a teal body
- a glossy pink double music note on the shield, sized to sit inside the purple
- cyan, pink and gold notes and white sparkles bursting from the lid

It's drawn by `tools/build/HOS-ICON-001_emote_crate_icon.py`, which builds a small 3D box-and-lid model in Python (PIL) at 4× and scales it down. No image model was used. Run it again to change anything: colours, how far the lid is open, or the size of the notes.

## Where it goes (once uploaded)
Today the emote crate shows the generic gift icon (`rbxassetid://87833590533916`) here:
- `EOSUI.Root.Shop…PageEmotes.CrateCard.CrateArt` (+ `CrateArtShadow`)
- `EOSUI.Root.Emotes…CratePage.Detail.CrateIcon` (+ `CrateIconShadow`)

The gift icon is also used elsewhere (the daily gift and other cards), so only the emote crate's images change.

## Next
The file needs uploading on Matthew's or Hunter's PC, because uploads can't be done from the cloud session. Use Studio's Asset Manager or `tools\upload\upload_assets.py`. With the image id, the two cards above get switched over.
