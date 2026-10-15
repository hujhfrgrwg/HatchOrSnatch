---
tags: [research, roclicks]
source: https://roclicks.gg/resources/game-design/analytics
retrieved: 2026-10-15
---
# Analytics

Instrument onboarding so you can see exactly where new players quit. Uses Roblox AnalyticsService.

Instrument onboarding so you can see exactly where new players quit. Uses Roblox `AnalyticsService`.

## Contents

- [[#Three kinds of data]]
- [[#Onboarding funnel rules]]
- [[#Example step list]]
- [[#Per-session funnel]]
- [[#Custom events]]
- [[#Client-reported steps]]
- [[#Changing the step list]]
- [[#Studio dry run]]
- [[#Reading the dashboard]]

Code: [snippets/onboarding_funnel.luau](https://roclicks.gg/resources/code/game-design/snippets/onboarding_funnel.luau).

## Three kinds of data

| API                                                                               | Use                                                  | Counted                             |
|-----------------------------------------------------------------------------------|------------------------------------------------------|-------------------------------------|
| `LogOnboardingFunnelStepEvent(player, step, stepName)`                            | First-time experience                                | Once per user per step number, ever |
| `LogFunnelStepEvent(player, funnelName, sessionId, step, stepName, customFields)` | Repeatable flows (a tutorial *session*, a shop flow) | Per session id                      |
| `LogCustomEvent(player, eventName, value, customFields)`                          | Timings, counts, reasons                             | Every call                          |

Custom fields use the keys `CustomField01` to `CustomField03` (`Enum.AnalyticsCustomFieldKeys`).

## Onboarding funnel rules

- **Fine-grained steps.** Not "tutorial started / finished". Log every sub-action, including UI opens: "Opened Army" and "Queued units" are separate steps, so you can see "opened the menu but didn't press +1". One game went from 8 steps to 16.
- **Monotonic.** Each step logs at most once per player, ever, in order. Save the highest step logged in the player's data (`analytics.onb`).
- **Fill in skipped steps.** If the server logs step 12 and the player is at step 10, log 11 first. A player who started a war without ever opening the War screen must not create a hole in the chart.
- **Log only for fresh saves.** Step 1 is "Joined first time", logged only when the save is new.
- **A skipped tutorial stops the funnel** where it was and logs a `TutorialSkipped` custom event with the step.

## Example step list

Generic version of a 16-step funnel for a 6-step tutorial:

| \#  | Label                       | Logged by           |
|-----|-----------------------------|---------------------|
| 1   | Joined first time           | server (fresh save) |
| 2   | Intro started               | client              |
| 3   | Intro finished or skipped   | client              |
| 4   | Tutorial card shown         | client              |
| 5   | Step 1 action done          | server              |
| 6   | Opened the step 2 screen    | client              |
| 7   | Step 2 action done          | server              |
| 8   | Opened the step 3 screen    | client              |
| 9   | Step 3 action queued        | server              |
| 10  | Step 3 done                 | server              |
| 11  | Opened the step 4 screen    | client              |
| 12  | Step 4 done (fight started) | server              |
| 13  | Step 5 done (first win)     | server              |
| 14  | Opened the step 6 panel     | client              |
| 15  | Step 6 done                 | server              |
| 16  | Tutorial completed          | server              |

## Per-session funnel

The onboarding funnel counts each user once, so it hides retries. Add a named funnel (e.g. `TutorialSession`) with a **new GUID per join** (`HttpService:GenerateGUID(false)`):

- one step per tutorial step completed;
- a session that begins mid-tutorial logs steps 1..current at once;
- `CustomField01` = "New player" or "Rejoin".

Sessions per user above 1 means people rejoin mid-tutorial.

## Custom events

| Event                | Value                                       | CustomField01 |
|----------------------|---------------------------------------------|---------------|
| `TutorialStepTime`   | seconds on the step, from when it was shown | step id       |
| `TutorialSkipped`    | step number when skipped                    | step id       |
| `IntroSkipped`       | timeline seconds when skipped               | "Intro"       |
| `TutorialLowCashTip` | 1, once per session                         | step id       |

Average `TutorialStepTime` by step shows which step is slowest. `IntroSkipped` shows how far in people bail.

## Client-reported steps

Some steps only the client knows (a screen opened, the intro played). Accept them through one remote, and validate on the server:

- a fixed allow-list of ids (UI-open steps plus a few non-step events);
- only while the player's tutorial exists and isn't done;
- only if the id is **exactly the next step** (no skipping ahead from the client; only server steps fill gaps);
- rate limit (3 calls/s);
- typed `info` only (e.g. `{skipped = bool, t = number}`), clamped.

Otherwise an exploiter, or just a buggy client, can fill your funnel with garbage.

## Changing the step list

**Roblox counts each onboarding step number once per user.** If you renumber the steps, an old player at "step 7 = Built a House" would later log "step 7 = Opened Army", and the chart mixes two meanings under one bar.

- Players who finished the old tutorial log nothing new.
- Players mid-way on the old funnel get `onbLegacy = true` and log **no** onboarding steps. They still play the tutorial normally and still log session funnel and custom events.
- Only fresh saves use the new numbering.
- Read the dashboard from the date the new numbering shipped.

## Studio dry run

Don't send events from Studio. Keep a bounded in-memory record of what *would* have been sent (and of rejected client calls), with a `debugSnapshot()` you can read from a playtest. Verify: all steps arrive in order with the right labels; unknown, out-of-order, server-only and duplicate client ids are rejected; legacy and finished saves log nothing.

## Reading the dashboard

Creator Dashboard → the experience → Analytics → Funnels.

- **Onboarding:** the biggest drop between two adjacent bars is where players quit. Data can lag by about a day.
- **Custom funnels:** break down by `CustomField01`.
- **Custom events:** average value per `CustomField01`.

Previous: [[Monetization and compliance]] · Next: [[Process]]
