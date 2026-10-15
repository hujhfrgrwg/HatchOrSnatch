---
tags: [design, decisions]
updated: 2026-10-15
---
# Evolve or Steal decisions

One line per decision, newest first. "Code" means the decision was found in the Studio place's config comments (marked "developer, Oct 15") and hasn't been confirmed in a design doc.

## 2026-10-16
- UI look: round 3 "sport" (the "Units" reference: dark panels, angled banner, white outlined text), one accent colour per screen. Approved as "looks great so far". Rounds 1 (neon) and 2 (candy, "too childish") were rejected.
- HUD layout follows Huss Valley (Hunter's layout reference).
- Pets and eggs in the UI are the FWP showroom models (Workspace.FWP_PetShowroom).
- Icons: ChatGPT-generated with `docs/ui/chatgpt_icon_prompt.md` (Hunter overrides the ui-maker "no AI icons" rule for this game).
- No gender-based UI colours; an optional "UI colour" setting is proposed instead.

## 2026-10-15
- GDD v0.4 adopted as the design baseline (`GDD/Evolve or Steal GDD v0.4.pdf`). Its section 18 sign-offs are still open; see [[Evolve or Steal GDD v0.4 Summary]].
- Code: matches end on 3 clean crossings in a row, a last-Runner solo crossing, or no Runners left (safety cap 40). **Conflicts with the GDD's fixed three crossings and 135 s cycle. Unresolved.**
- Code: the launch abilities are Decoy, Scout and Brake.
- Code: no jumping; Space is a side/back dash only (no forward dash). Catchers can't dash.
- Code: Catchers and Runners both run at 28. A stab costs a 0.7 s slow at 55%. Tag cooldown is 1.0 s (was 0.6).
- Code: a caught Runner ragdolls and stays down for the rest of the crossing.
- Code: a Runner who makes it across is locked in the safe zone until the next crossing.
- Code: Catchers (players and NPCs) are held for 0.75 s after a crossing opens.
- Code: NPCs fill matches to 20 Runners and the lobby to 5. Matches start with 1 real player, and fewer than 4 real players is an unsaved practice match.
- Code: Robux purchases stay off until Hunter approves real developer products.
