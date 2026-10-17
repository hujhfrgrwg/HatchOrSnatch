---
tags: [ui]
updated: 2026-10-17
ticket: HOS-RET-001
---
# Retention prompts (favorite, welcome back, event, starter pack, waiting offer)

Hunter asked for a favorites prompt at a reasonable time and a returning-player gift like the reference game's "come back tomorrow for a FREE weapon" card, then added the reference's event RSVP prompt, starter pack and waiting-round offer card. Made with `roblox-ui-maker` in the round 3 "sport" style (`ui/build.py`, pages `gift_*`, `event_rsvp`, `starter_pack`, `wait_offer*`). Review stills: `docs/ui/retention/`.

**Status:** Hunter approved 2026-10-17 ("build it all"). Code and exports done: `roblox/game/Retention*.luau`, `roblox/ui_retention/`, export config `ui_ret/rbx.json`. Install steps: [[HOS-RET-001 Install]]. Daily gift set at 250 Gold + 2 Gems. Starter pack built but off (`RetentionConfig.STARTER.enabled = false`) until Hunter sets contents and price. Event prompt off until `RetentionConfig.EVENT_ID` is set.

## When each shows
| Prompt | When | How often |
|---|---|---|
| Welcome back gift | Rejoin on a new UTC day since the last claim, a few seconds after spawning in the lobby | Once a day; CLAIM button, never auto-claimed; card then flips to the countdown |
| Come back tomorrow + favorite | Back in the lobby after the first finished match; Roblox's `AvatarEditorService:PromptSetFavorite` on top | Favorite once ever; no reward for favoriting |
| Join Event | A later lobby break, only when an event id is set in config (`SocialService:PromptRsvpToEventAsync`) | Once per event |
| Starter pack | After the first pet (economy decision 33), real 48 h window kept on the server | Once |
| Waiting offer card | Bottom-right while waiting out a Hero run; cycles VIP, 2x XP, starter pack | X hides it for the session; never to anyone crossing |

Lobby prompts: one at a time, 3+ minutes apart, never mid-match.

## Open for Hunter
- Starter pack contents and Robux price (looks only, decision 32). Not wired to a purchase until set.
- The reference's Catcher Pack sells an ability; left out (decision 32).
