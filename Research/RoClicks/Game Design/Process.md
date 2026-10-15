---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/process
retrieved: 2026-10-15
---
# Process

How the developer, a playtesting collaborator and AI agents work together on design changes.

How the developer, a playtesting collaborator and AI agents work together on design changes.

## Contents

- [[#Feedback loop with a playtester]]
- [[#Improvement rounds]]
- [[#Parallel reviewers, merged into a ranked list]]
- [[#Fix agents]]
- [[#Prepare-then-apply]]
- [[#Decisions that belong to the developer]]

## Feedback loop with a playtester

A collaborator who plays for hours finds what no review does ("hella fun, 2 hours in", then a list of 16 things).

- **Write the feedback down as a numbered file** (e.g. `FEEDBACK_<name>_1.md`): each item quoted in their words, then what it means in the game, then the expected fix. Group into gameplay/UI, visual, monetization, then "after the above: bug pass and balance check".
- **Quote, then interpret.** "the colours of the baseplates are ass" becomes "redesign ground palette: calmer, countries still readable; show before and after".
- **Answer every item** in the change log with a status (Fixed + how verified / Already fixed by them / Needs decision).
- **The collaborator may be editing too.** If they work live in Team Create, Studio is the source of truth: pull the current script, diff against disk, merge their edits first, then push yours with a base-compare check that refuses to overwrite a changed script.
- **Respect their areas.** If they say "I fixed lighting", don't touch lighting.
- **Turn their one-liners into measurable targets.** "battles 1.5x faster" became real-second measurements on 6 seeds per scenario; "make the first battle 100% win" became a 20/20 test matrix.

## Improvement rounds

A loop that worked well for feel problems:

1.  Play like a player for under 5 minutes per run (or watch the developer play).
2.  Rank the worst "feel" problems.
3.  Fix the top ones at the source.
4.  Verify in a playtest.
5.  Log before/after evidence (screenshots, numbers) in one append-only change log.
6.  End the round with "Next" and "On hold" lists.

Keep the playtests short and few if the developer's machine is weak. Use locks (a workspace attribute with the agent's name and a timestamp) so parallel agents don't playtest at the same time.

## Parallel reviewers, merged into a ranked list

For a full health check, run **15 read-only reviewers in parallel, one per area** (see [[Review areas|review-areas.md]]).

**Shared brief for every reviewer:**

- what the game is and who it's for ("kids; fun, smooth and simple, less friction");
- which copy of the code is the source of truth (an exact export from Studio, not a possibly stale disk copy);
- hard rules: read-only, no Studio tools, one report file as the only output;
- report format:
  1.  **Bugs**: exact file and lines, what goes wrong and how to trigger it, severity (crash / soft-lock / wrong result / visual / minor), confidence (confirmed by reading / likely / suspicion), a code-level fix. Most severe first, no style nits.
  2.  **5 to 10 kid-friendly improvements**: the friction removed, the change, impact (high/med/low), effort (S/M/L). Favour fewer steps, fewer numbers, clearer feedback, auto-doing boring things.
  3.  A one-paragraph health summary.
- under ~400 lines.

**Merge step** (one agent reads all 15 and writes `00_SUMMARY.md`):

- **P0:** data loss, soft-locks, money. A table: bug, area.
- **P1:** wrong results players will notice, grouped by area.
- Half-done or abandoned work found along the way, with options.
- **Ideas that came up in several reports**, numbered so the developer can pick ("1, 4, 7").
- **Needs the developer** (decisions, real ids, policy questions).
- Any precondition before fixing (e.g. "sync the disk copy from Studio first").

Cross-report agreement is a strong signal. "Never auto-open Robux prompts" was found independently by 3 reviewers; Easy/Close/Hard verdicts by 4.

## Fix agents

After the developer approves the P0/P1 list:

- Split the fixes among a few agents by **file ownership**. Each agent edits only its own files.
- A fix that needs someone else's file goes in "Needs another owner" with the exact change.
- Every agent pulls before editing, runs the static checker to 0 errors, pushes with base-compare, and appends to the change log (re-reading it first, since others append too).
- Report: each bug fixed (what, where, how verified), bugs skipped and why, "needs another owner", decisions for the developer, files changed.

## Prepare-then-apply

Sometimes the developer says "prepare everything for now" or "hold applying until I say go" (often because their machine can't take a playtest right now, or a collaborator is mid-change).

- Do all the work: code, tests in a headless harness, the design file.
- **Stage it, don't apply it.** Write a stage bundle (e.g. a `.rbxmx` with the new sources plus the base each was made from) and a matching apply script.
- The apply step compares each target's current source with its recorded base and **refuses on any mismatch** ("CONFLICT, nothing applied"), so a late apply can't overwrite someone's newer edit.
- Mark the change-log entry clearly: "staged, NOT applied, not live-tested", with how to apply.
- Keep a running "On hold" list at the end of every round until the developer answers.

## Decisions that belong to the developer

Ask, don't decide:

- grandfathering or refunds when something becomes paid;
- rewards that may break platform rules (likes);
- real product prices and ids, promo codes;
- changes to areas a collaborator owns;
- anything that changes the look (new UI is designed in HTML first and approved).

Previous: [[Analytics]] · Next: [[Review areas]]
