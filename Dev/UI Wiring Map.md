---
tags: [dev, ui, studio, audit]
updated: 2026-10-16
---
# UI Wiring Map

This is a read-only map of how the current in-game UI is wired to the game. It covers the **"Hatch or Snatch"** place (id 128015050187408) as it stood on 16 Oct 2026. Use it to wire a new ScreenGui without reading the old UI code again. Nothing in Studio was changed.

Scripts it describes:
- Client: `StarterPlayer.StarterPlayerScripts.EOS.ClientMain` and the controllers in `.Controllers`
- Shared: `ReplicatedStorage.EOS.Shared.*` and `ReplicatedStorage.EOS.UI.Theme` / `UIKit`
- Builder: `ServerStorage.EOSBuild.UIBuilder`
- Server: `ServerScriptService.EOS.Services.*` and `.Core.MatchLogic` / `ProfileLogic`

## 0. The short version

- The old UI is **four ScreenGuis baked into StarterGui** at edit time by `UIBuilder`: `EOS_HUD`, `EOS_Menus`, `EOS_Results` and `EOS_Overlay`. Roblox copies them into PlayerGui. `UIController.init()` finds them with `WaitForChild` and drives every element **by name**.
- **All four are `Enabled = false` in StarterGui right now.** UIController never turns them on, except for `hud.Enabled = true` when the results card closes. So in a playtest today nothing shows until the first results card is dismissed.
- All networking is **RemoteEvents** in `ReplicatedStorage.EOS_Remotes`, reached through `Net.event(name)`. There are no RemoteFunctions. Live match state is held in **attributes** on `ReplicatedStorage.EOS_State` (`Net.state()`) and on the `Player`.
- The whole profile reaches the client as one table: `ProfileState`. It fires on load, after every change, and whenever the client sends `RequestProfile`. Gold, gems, pieces, pets, quests, cosmetics, emotes, stats and settings all come from it.
- `EmoteController` owns the Emotes panel inside `EOS_Menus`. It also `require`s UIController and calls its API. That is the main thing that ties other code to the old UI.

## 1. Boot order and how the UI gets its gui

### 1.1 ClientMain (LocalScript)
`ClientMain` requires every controller, then calls `init()` on each in this order:

`Fit` → `Movement` → `CharacterAnim` → `CameraFX` → `Tag` → `WorldFX` → **`UIController`** → `NpcSkins` → `Pets` → `EmoteController` → `SlideFX` → `Outlines` → `FacePlayer` → `Ragdoll.bindLocal()`

Last, it connects a no-op `OnClientEvent` listener to every name in `Net.TO_CLIENT`, so no remote ever logs "invocation queue exhausted".

**Fragile:** `UIController.init()` calls `pg:WaitForChild("EOS_HUD")` (and the same for the other three guis) with **no timeout**. If any of the four guis is missing, UIController.init never returns, and every controller after it never starts: NpcSkins, Pets (the Q ability), EmoteController, SlideFX, Outlines, FacePlayer and the ragdoll. A new UI must either keep these names or replace the UIController call in ClientMain.

### 1.2 Where the ScreenGuis come from
- `require(game.ServerStorage.EOSBuild.UIBuilder)()` builds all four guis and parents them to **StarterGui**, in edit mode. It first **destroys any StarterGui child with the same name**. `BuildAll` does not call it, so it only runs by hand.
- `require(...UIBuilder).preview(scale)` sets every `Fit` UIScale, for screenshots in edit view.
- At runtime nothing is built. Roblox copies StarterGui into PlayerGui, and `ResetOnSpawn = false` keeps the guis alive across respawns.
- Runtime clones: toasts and feed lines are cloned from `EOS_HUD.Templates`. Pet cards, shop cards and emote cards are cloned from hidden template cards inside their grids.

| ScreenGui | DisplayOrder | ScreenInsets | Holds |
|---|---|---|---|
| `EOS_HUD` | 5 | DeviceSafeInsets (IgnoreGuiInset true) | pills, rail, status/match bar, wallet, role card, ability card, dash, touch buttons, feed, banner, hint, `Templates` |
| `EOS_Menus` | 10 | CoreUISafeInsets | `Scrim` plus the panels `Quests`, `Incubator`, `Pets`, `Shop`, `Emotes`, `Stats`, `Settings` |
| `EOS_Results` | 20 | CoreUISafeInsets | `Root` (end-of-match card) |
| `EOS_Overlay` | 30 | CoreUISafeInsets | `Toasts` (above the menus) |
| `EOS_Crosshair` (made at runtime by `CameraFX`) | 6 | IgnoreGuiInset | the 3 px centre dot, shown while the mouse is locked in a match |

Every top-level group has a `UIScale` named `Fit`. `Fit.track(gui)` scales it from a 1920x1080 design canvas, with a 1.28x boost on phones and 0.9x on desktop. A group's position is kept in its `DesignPos` attribute, plus `FitExtra` (real pixels). Layout code calls `Fit.setDesignPosition` and never writes `Position` directly.

### 1.3 UIController public API

| Function / field | What it does | Called by |
|---|---|---|
| `UI.init()` | finds the guis, wires buttons and remotes, starts a 0.1 s Heartbeat `updateHUD`, fires `RequestProfile(device)` | ClientMain |
| `UI.toast(text, kind?, force?)` | toast in `EOS_Overlay.Toasts`. `kind` is `"reward"`, `"info"`, `"warn"` or `"bad"`. Repeats are merged and at most 3 show. **Dropped during a match unless `force`.** | UIController itself, `Pets.onToast`, EmoteController |
| `UI.feed(richText)` | kill/safe feed line. **Does nothing: `FEED_ENABLED = false`.** | UIController (RunnerEvolved, CaptureFeedback) |
| `UI.banner(title, sub?, color?, burstColor or false, time?)` | big centre banner. Queued, with stale ones dropped past 2. | UIController (role / caught / safe / steal / last standing) |
| `UI.open(name)` | opens a panel in `EOS_Menus` (toggles if it's already open). Refuses `Incubator`, `Shop`, `Pets` and `Emotes` during a match, with the toast "That opens between matches". | rail/pill buttons, the `OpenScreen` remote, Pets empty state |
| `UI.close()` | closes the open panel and the incubator overlays, hides the Scrim, unbinds gamepad B | close buttons, Scrim, Esc, Roblox menu, match start, EmoteController |
| `UI.openName()` | name of the open panel, or nil | EmoteController (previews run and reveals show only while `"Emotes"` is open) |
| `UI.isOpen()` | true if a panel or the results card is open | given to `Tag.isUIOpen` and `CameraFX.lockBlocked` |
| `UI.refreshPanels()` | redraws quests, incubator, pets/shop (when open), stats and settings, then calls `UI.onEmotesRefresh` | on ProfileState, open, settings toggle |
| `UI.juicy(button, fn)` | hover/press tween + click sound + `Activated` | set in `wireButtons`; EmoteController uses it (it falls back to plain `Activated`) |
| `UI.onEmotesRefresh` | callback `(profile, isEmotesOpen)` | **set by** EmoteController.init |

### 1.4 Hooks UIController plugs into other controllers (set in `UI.init`)

| Hook | Set to | Why |
|---|---|---|
| `Tag.isUIOpen` | `UI.isOpen` | no tagging or lunging while a menu or results is up |
| `Tag.onDecoy` | forced toast "THAT WAS A DECOY!" (warn) | the only toast allowed in a match |
| `Tag.onSwing` | pops `hud.TagButton` | touch feedback |
| `Pets.onToast` | `UI.toast` | "No pet yet...", "Scout: N spotted" (these get dropped in a match because they aren't forced) |
| `Pets.onUsed` | pops `hud.AbilityBar` | feedback |
| `CameraFX.lockBlocked` | `UI.isOpen() or resultsOpen` | frees the mouse lock while UI is open |
| `Movement.onDash(fn)` | plays `"swing"` at pitch 1.35 and pops `hud.DashButton` | dash feedback |
| `Sound.enabled`, `CameraFX.reduceEffects`, `WorldFX.reduceEffects` | from settings (`applySettings`) | settings take effect on the client |
| `StarterGui:SetCore("ResetButtonCallback", not inMatch)` | re-applied whenever `EOS_InMatch` changes | no resetting mid-match |

What the UI reads from other controllers:
- `Pets`: `family()`, `charge()` (0..1), `readyAt` (os.clock), `use()`
- `Tag`: `swing()`, `lunge()`, `lastSwing`, `lastLunge`, `lungeCharge()`
- `Movement`: `dash()`, `dashCharge()`, `dashReadyAt`, `blockedReason()` (returns `"OFF"`, `"CATCHER"`, `"PAUSED"`, `"COOLDOWN"` or nil), `refusedAt`, `refusedWhy` (`"FORWARD"` or `"FACING"`)
- `NpcSkins`: `nameForSlot(slot)`, `userIdForSlot(slot)`, `modelForSlot(slot)`
- `WorldFX`: `evolve(model, color)`, `capture(pos)`
- `CameraFX`: `shake(mag, dur)`, `lookToward(pos)`
- `PetModel.viewport(viewportFrame, species, yaw?)`
- `Layout.Zones[A|B].center/size` and `Layout.Arena.CENTER`

## 2. Data the UI reads and writes

### 2.1 Server → client RemoteEvents (`Net.TO_CLIENT`)

| Remote | When it fires, and to whom | Payload | What the old UI does |
|---|---|---|---|
| `MatchState` | every phase change, to all | `{ phase, endsAt, wave, maxWaves, cleanStreak, streakToWin, lastClean, finishSide, lastStanding }` | in a match only. `CROSSING` with `lastStanding == myUserId` shows the banner "LAST ONE STANDING!". `WAVE_END` turns the camera toward the next zone after 1.5 s. |
| `RoleChanged` | to that player | `{ role, cause, bankedTier, by?, byName?, bySlot?, graceUntil? }`. `cause` is `"START"`, `"CAPTURED"`, `"TIMEOUT"` or `"NEXT_ROUND"`. | START: camera faces the target and shows "YOU'RE A RUNNER" or "YOU'RE THE CATCHER". CAPTURED: "CAUGHT!" + shake. TIMEOUT: "TOO SLOW!". NEXT_ROUND: nothing. |
| `RunnerEvolved` | a Runner reaches the finish zone; to match participants | `{ userId, name, slot?, prevTier, newTier, shells, crossings }` | WorldFX.evolve on that body. If it's you: sound + banner "SAFE! LEVEL n". Otherwise a feed line (feed is off). |
| `CaptureFeedback` | a tag lands; to match participants | `{ hunterId, hunterName, hunterSlot?, victimId, victimName, victimSlot?, stolenTier, creditedTier, hunterSecured, shells, position: Vector3, runnersLeft }` | WorldFX.capture + sound + feed line (off). If you're the hunter: banner "STOLE LEVEL n!" + shake. |
| `Results` | match end, to **every** player (lobby too) | see 2.8 | shows the results card |
| `ProfileState` | load, every profile change (0.15 s debounce), `RequestProfile` | see 2.7 | stores `profile`, takes settings once, counts up the wallet, `refreshPanels()` |
| `QuestState` | **never fired** (quests come in ProfileState) | none | no-op |
| `Toast` | many server messages (list in 2.10) | `{ text, kind }` | `UI.toast` (dropped in a match) |
| `OpenScreen` | lobby ProximityPrompts | `{ name, tab? }`. Live prompts: Incubator desk `name="Incubator"`, Gold Shop `name="Shop", tab="gold"`, Gem Shop `name="Shop", tab="gems"`. A prompt with no Screen attribute sends `"Quests"`. | opens that panel. For Shop it switches the tab first (or just refreshes if Shop is already open). |
| `PracticeEvent` | practice field pads/bot | `{ kind = "crossed", pad }` or `{ kind = "tagged" }` | toast + sound. **Never fires today: `Layout.Practice.enabled = false`.** |
| `HatchResult` | after `RequestHatch` | `{ ok, reason?, pet?, plan?, royal? }` (2.9) | reveal, confirm dialog or family picker |
| `CrateResult` | after `RequestOpenCrate` (EmoteController) | `{ ok, reason?, emote?, dupe?, refund? }` | EmoteController finishes the reel and the reveal |
| `ShopResult` | after `RequestBuy` | `{ ok, reason?, itemId }`. reason is `"NOT_ENOUGH"`, `"OWNED"`, `"UNKNOWN"`, `"BAD_WALLET"` or `"NOT_LOADED"`. | on ok, plays `"reward"` (the server also sends a toast) |
| `AbilityFx` | an ability fires, to all | `{ userId, family, species, kind = "summon", pos?, gold? }` or `{ userId, family = "Decoy", kind = "poof", pos }` | handled in **Pets** (world effects only) |
| `AbilityState` | to the user, after `RequestAbility` | `{ ok = true, family, readyIn }` or `{ ok = false, reason, readyIn? }`. reason is `"LOBBY"`, `"OUT"`, `"WAIT"`, `"NO_PET"` or `"COOLDOWN"`. | **Pets** sets `Pets.readyAt` / `Pets.cooldown`, and the UI reads those. The comment in Net says `readyAt`; the real field is **`readyIn`** (seconds). |
| `ScoutPing` | to the Scout user | `{ targets = { userId... }, duration }` (Net's comment says `untilT`, which is wrong) | **Pets** highlights the targets and toasts "Scout: N spotted" |

### 2.2 Client → server RemoteEvents (`Net.TO_SERVER`)
The server validates everything and rate-limits it (`GameConfig.RateLimits`).

| Remote | Args | Sent by (old UI) | Server reply |
|---|---|---|---|
| `RequestProfile` | `(device: "pc"\|"touch"\|"gamepad"\|"console"\|"vr")` | UI.init, and again whenever the device class changes | sets `EOS_Device`, pushes `ProfileState` |
| `RequestQuestClaim` | `(questId)` | Quest card Claim button (checked on the client first) | ProfileState + Toast "+N Gold claimed!", "Already claimed today" or "Finish the quest first" |
| `RequestAFK` | `(on: boolean)` | rail `AFKToggle` (sends `not EOS_AFK`) | sets `EOS_AFK`, saves it. In a match: toast "AFK will start after this match". |
| `RequestVolunteer` | `(on: boolean)` | rail `VolunteerToggle` ("HUNT") | sets `EOS_Volunteer`, saves it. No toast. |
| `RequestSettings` | `({ sfx?, reduceEffects?, showHints? })`, booleans only, partial is OK | Settings toggles (sends one key at a time) | saved to `profile.settings`. No reply, no ProfileState echo. |
| `RequestHatch` | `(rarity: "common"\|"rare"\|"epic", family?: "Decoy"\|"Scout"\|"Brake", allowHigher?: boolean)` | Incubator Hatch / Pick / Confirm | `HatchResult` (+ toast on hard errors), ProfileState |
| `RequestEquipPet` | `(petId)`; `""` unequips | Pets card Equip | ProfileState + updated pet attributes. Toasts: "Pets can't be swapped mid-match", "You don't own that pet". |
| `RequestBuy` | `(itemId)` | Shop Buy | `ShopResult` + toast "<name> added" (consumable) or "<name> unlocked!", or an error toast |
| `RequestUseItem` | `(itemId)`, `burst` items only | Shop Use (confetti) | confetti at your head, ProfileState |
| `RequestSetCosmetic` | `(slot: "case"\|"trailNext", itemId)`; `""` clears | Shop Wear/Take off (case only). **The old UI never sends `trailNext`.** Buying a trail arms it automatically. | ProfileState, or toast "You don't have that yet" |
| `RequestAbility` | `(moveDir: Vector3?)` | **Pets.use()**: Q, gamepad Y or the touch `AbilityButton` | `AbilityState`, `AbilityFx`, `ScoutPing` |
| `RequestOpenCrate` | `()` | EmoteController, crate Open (250 gems) | `CrateResult`, ProfileState |
| `RequestEmote` | `(emoteId)`; `""` stops | EmoteController Play / PlayNow, and on moving | sets character attribute `EOS_Emote` |
| `RequestTag`, `RequestLunge`, `RequestLook` | gameplay | Tag / CharacterAnim | not UI |

### 2.3 Match state: attributes on `ReplicatedStorage.EOS_State` (`Net.state()`)

| Attribute | Type | Meaning |
|---|---|---|
| `Phase` | string | `"BOOT"`, `"WAITING"`, `"INTERMISSION"`, `"ROLE_REVEAL"`, `"CROSSING"`, `"WAVE_END"` or `"RESULTS"` |
| `PhaseEndsAt` | number | server time (`workspace:GetServerTimeNow()`) the phase ends. WAITING sets it to now. |
| `PhaseId` | number | +1 on every phase change |
| `Ready` / `Needed` | number | eligible lobby players / players needed to start (`MIN_TO_START` = 1 with NPCs on) |
| `Wave` | number | current crossing number (0 outside a match) |
| `MaxWaves` | number | 0 = no fixed number (normal play). Only a Studio solo test without NPCs sets 3. |
| `CleanStreak` / `StreakToWin` / `LastClean` | number / number / bool | crossings in a row with nobody caught (3 wins), and whether the last one was clean |
| `LastStanding` | userId or nil | a lone Runner's solo crossing |
| `StartSide` / `FinishSide` | `"A"` or `"B"` | which safe zone Runners start from and head to |
| `RunnersLeft` / `Catchers` | number | live counts |
| `InMatchCount` / `NpcCount` | number | roster size / NPCs in it |
| `MatchId`, `IsTest`, `IsSolo` | string, bool, bool | `IsTest` = fewer than 4 real players: rewards are not saved |
| `Map` / `MapTitle` | string | current arena map |
| `LastResults` | JSON string | the last results payload, without `you` (handy for a late joiner) |

Phase lengths (`GameConfig.Timing`): INTERMISSION 15, ROLE_REVEAL 5, CROSSING 30, WAVE_END 4, RESULTS 11 seconds. Crossings repeat until 3 clean in a row, the last Runner crosses alone, no Runners are left, or 40 crossings (safety cap).

### 2.4 Player attributes (on `Players.LocalPlayer`)

| Attribute | Values | Set by | UI use |
|---|---|---|---|
| `EOS_Loaded` | true once the save loads | DataService | "LOADING..." status until set |
| `EOS_LoadStatus` | string while waiting for a session lock | DataService | status sub-line |
| `EOS_InMatch` | bool | MatchService (also SandboxService) | lobby vs match layout. Closes panels on start. Reset button. |
| `EOS_Role` | `"LOBBY"`, `"RUNNER"`, `"CATCHER"`, `"CAUGHT"` (also `"PRACTICE"` in CharacterService) | CharacterService | role chip, timer label, touch Tag button, lunge vs dash |
| `EOS_Tier` | number (Runners only; nil otherwise) | CharacterService | Runner's egg level |
| `EOS_Secured` | number | MatchService | the egg level shown for non-Runners |
| `EOS_Safe` | bool | MatchService | hides the direction arrow once you're safe |
| `EOS_MatchCaptures` | number | MatchService | not shown |
| `EOS_CatcherSource` | `"START"`, `"CAPTURED"`, `"TIMEOUT"` or nil | MatchService | not shown |
| `EOS_AFK` / `EOS_Volunteer` | bool | DataService (load), PlayerService | rail toggles, AFK banner, status text |
| `EOS_IsNew` | bool (no matches finished yet) | DataService | not shown (used for picking Catchers) |
| `EOS_Gold` / `EOS_Gems` | number | DataService | not used by the UI (it uses ProfileState). Fine for a simple wallet. |
| `EOS_PetFamily` / `EOS_PetSpecies` / `EOS_PetRarity` | strings, `""` = no pet | DataService | ability card (`Pets.family()` reads `EOS_PetFamily`) |
| `EOS_Wins`, `EOS_BestTier`, `EOS_Captures`, `EOS_PetsHatched` | number | DataService | lobby boards (server). Not used by the UI. |
| `EOS_InPractice` | bool | PracticeService | "PRACTICE FIELD" status. Never set while practice is disabled. |
| `EOS_Device` | string | PlayerService | echo of `RequestProfile` |
| `EOS_Sandbox` | bool | SandboxService (Studio knife test) | Pets / CameraFX treat it as a match |

Character attributes the UI might want: `EOS_Emote` (the playing emote id), `EOS_Ragdoll`, `EOS_Held` (a Catcher held still), `EOS_SlowUntil`/`EOS_SlowFactor` (post-lunge slow). The old UI uses none of them.

### 2.5 Quests
- They come from `profile.quests`: 2 per UTC day (`QuestConfig.DAILY_COUNT`), picked from `QuestConfig.Pool`. They reset at 00:00 UTC. The old UI works out the countdown as `86400 - floor(serverNow) % 86400`.
- Row: `{ id, title, target, progress, claimed, reward }`. `reward` is Gold. Pool ids: `cross1`, `cross3`, `capture1`, `capture3`, `match1`, `match3`, `tier2`, `tier3`.
- Claimable = `not claimed and progress >= target`. That drives the red `Badge` on the Quests pill. Claim with `RequestQuestClaim(id)`.
- Progress only moves in saved matches (4+ real players).

### 2.6 Economy rules the UI shows (from `EconomyConfig`)
- Materials (egg pieces): `MATERIALS = { "common", "rare", "epic" }` (low → high). `MATERIAL_INFO[m] = { name, color, text }`. `profile.materials` also has a reserved `crowned` key (always 0).
- Recipes `RECIPES[m] = { base, focus }`: common 2/3, rare 3/4, epic 5/6. `base` hatches a random family; `focus` lets you pick the family. While `profile.firstCommonFree` is true, the first Common hatch costs `base` and includes a free family pick.
- Higher pieces can fill a lower recipe 1:1, but the server asks first (`NEEDS_HIGHER`). The old UI's "have for" count adds up tier m and every tier above it.
- Families: `LAUNCH_FAMILIES = { "Decoy", "Scout", "Brake" }`. `FAMILIES[f] = { ability, short, desc, species = {common, rare, epic}, color, cooldown, duration }`. Cooldowns are Decoy 20, Scout 18 and Brake 10 seconds. `speciesFor(family, rarity)`. (The repo's HOS-ABIL-001 plans nine families, but Studio's EconomyConfig and AbilityService still have three. Read `LAUNCH_FAMILIES`; don't hard-code the list.)
- One piece per eligible match: `MATERIAL_FOR_TIER` maps level 1 → common, 2 → rare, 3+ → epic.
- Gold per match = min(90, 25 played + 12 per crossing + 10 first steal + 15 victory). Gems per match = min(5, ...). The results payload carries the breakdown, so there's no need to recompute it.
- Shop: `EconomyConfig.SHOP`, a list of `{ id, name, wallet = "gold"|"gems", price, kind, desc, color }`. Kinds: `trail` (consumable, worn next match), `burst` (consumable, used in the lobby), `case`, `entrance`, `trailPerm`, `abilityFx`, `hatchFx` (all permanent). Look items up with `EconomyConfig.item(id)` and `isConsumable(item)`.
- Emotes: `EmoteConfig` has `CRATE_GEMS = 250`, `RARITY[r] = { name, odds, ramp, order, color }`, `DUPE_REFUND`, `LIST = { { id, name, rarity, animId, music, song } }` and `ROBUX` (no product ids).

### 2.7 `ProfileState` payload (`ProfileLogic.clientView`)
```
{
  gold: number, gems: number,
  materials: { common, rare, epic, crowned: number },
  pets: { { id: "p1", family, rarity, species, n } },   -- n = hatch order
  equippedPet: string,            -- pet id, "" = none (the first hatch auto-equips)
  firstCommonFree: boolean,
  cosmetics: { owned: {[itemId]=true}, consumables: {[itemId]=count}, case: itemId|"", trailNext: itemId|"" },
  emotes: { [emoteId] = true },
  stats: { wins, matchesCompleted, captures, successfulCrossings, lifetimeBestTier, lifetimeShellsEarned,
           timesFirstHunter, goldEarned, gemsEarned, gemsPurchased, petsHatched },
  quests: { { id, title, target, progress, claimed, reward } },
  questDate: "YYYY-MM-DD",
  afk: boolean, volunteer: boolean,
  settings: { sfx: boolean, reduceEffects: boolean, showHints: boolean },
}
```
Settings: the old UI copies `view.settings` **once** (on the first ProfileState), runs `applySettings()`, and from then on keeps its own local copy. Each toggle flips the local value, applies it at once and sends `RequestSettings({ [key] = value })`. Only those three keys are saved. `applySettings` sets `Sound.enabled = sfx`, `CameraFX.reduceEffects` and `WorldFX.reduceEffects`. `showHints` only gates the lobby hint line.

### 2.8 `Results` payload (one per player; `you` only for match participants)
```
{
  matchId, isTest: boolean, team: "RUNNERS"|"CATCHERS",
  endReason: "LAST_ONE_STANDING"|"CLEAN_STREAK"|"FINAL_WAVE"|"ALL_RUNNERS_GONE"|"SAFETY_CAP" (or an abort reason),
  wavesPlayed, maxCrossings, champion: userId?,
  topRunners: { { userId, name, npcSlot?, place 1-3, crossings, securedTier, survived } },
  topThief: { userId, name, npcSlot?, captures, bestStolenTier }?,
  nextMatchAt: serverTime,        -- now + RESULTS + INTERMISSION (an estimate)
  you?: { securedTier, eligible, source: string, nearMiss: string?, gold, goldParts: { {label, amount} },
          gems, material: "common"|"rare"|"epic"|nil, crossings, captures, runnerPlace?, win, saved: boolean },
}
```
- Names: if `npcSlot` is set, the entry is an NPC. Show `NpcSkins.nameForSlot(npcSlot)` (it's dressed as one of *this* player's friends) and `NpcSkins.userIdForSlot(npcSlot)` for the headshot (`rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150`).
- The `goldParts` labels are `"PLAYED"`, `"CROSSINGS"`, `"FIRST STEAL"` and `"VICTORY"`.
- `source` strings: `"LAST ONE STANDING"`, `"SURVIVED n CROSSINGS TO THE END"`, `"STOLE TIER n"`, `"INITIAL CATCHER"`, `"SURVIVED n CROSSING(S)"`, `"STARTING EGG"`. The server says **TIER** in `source` and in `nearMiss` (`"ONE MORE ESCAPE WOULD REACH TIER n"`). The old UI swaps TIER for LEVEL only in `nearMiss`, not in `source`.
- `eligible = false`: the old UI shows "Move, cross or tag to earn rewards". `isTest`: "PRACTICE MATCH: REWARDS SAVE WITH 4+ REAL PLAYERS".
- Order on arrival: `Results` comes first, then `ProfileState` about 0.15 s later with the new pieces. The old UI redraws the "next hatch" bar on that ProfileState.
- Auto-close: when the phase becomes `ROLE_REVEAL`, or 2 s after `nextMatchAt`. If the phase is `WAITING`, the countdown line reads "WAITING FOR PLAYERS".

### 2.9 Incubator / hatch flow
1. **Hatch** (random family) on a tier card. If you can't afford it, the client toasts "Need N X pieces (you have M)". If it's the free first Common, the family picker opens. Otherwise it sends `RequestHatch(m, nil, false)`.
2. **Pick** (choose family) checks `focus` cost, then opens the Picker. Picking a family card sends `RequestHatch(m, family, false)`.
3. `HatchResult`:
   - `ok = true`: `pet = { id, family, rarity, species, n }`, `plan`, and `royal` (owns `hatch_royal`), which gives a bigger reveal. The old UI does an egg shake (1.2 s, or 2 s when royal) → pet viewport spins → "NEW PET!" / "A ROYAL HATCH!".
   - `reason = "NEEDS_HIGHER"`: `plan = { rarity, cost, take = {[material]=n}, free, focused, usesHigher, missing }`. Show which higher pieces it would use, then on Yes resend with `allowHigher = true` (same rarity and family).
   - `reason = "CHOOSE_FAMILY"`: open the picker for `plan.rarity`.
   - Other reasons (`NOT_ENOUGH`, `BAD_FAMILY`, `BAD_RARITY`, `NOT_LOADED`) come with a server toast.
   - In a match the server only toasts "Hatch at the incubator between matches" and sends **no HatchResult**.
4. The new pet is auto-equipped if nothing was equipped. Watch for the ProfileState that follows.

### 2.10 Toasts the server sends (`Toast` remote)
EconomyService: "Hatch at the incubator between matches", the hatch errors above, "Pets can't be swapped mid-match", "You don't own that pet", "The shop opens between matches", "Not enough Gold/Gems", "You already own that", "That item isn't for sale", "<item> added", "<item> unlocked!", "That can't be used here", "Save the confetti for the lobby", "You're out of <item>: the shop has more", "You don't have that yet".
PlayerService: "AFK will start after this match", "+N Gold claimed!", "Already claimed today", "Finish the quest first".
EmoteService: "Open crates between matches", "Your save is still loading", "Not enough Gems: a crate is 250", "Can't open a crate right now", "You don't have that emote yet".
AbilityService: "No pet equipped: hatch one at the incubator", "Wait for the crossing to start", "You're out this crossing", "Abilities work in matches".
MatchService (to all): "Next map: <title>".
Remember the old UI drops every non-forced toast during a match, so the ability toasts are never seen.

### 2.11 Ability, dash and lunge (the client-side numbers)
- Ability key: **Q / gamepad Y**, bound in `Pets.init` (`ContextActionService "EOS_PetAbility"`). On touch, the HUD's round `AbilityButton` calls `Pets.use()`. Cooldown bar: `Pets.charge()`. Seconds left: `Pets.readyAt - os.clock()`. The server's answer corrects these. They reset to 0 when `EOS_InMatch` changes.
- Dash: **Space / gamepad A**, handled in Movement. `Movement.dashCharge()` and `Movement.dashReadyAt` (2 s cooldown). `blockedReason()` gives the meter text. `refusedAt` / `refusedWhy` say why a press did nothing ("SIDE OR BACK ONLY" or "NOT THE WAY YOU FACE").
- Catchers can't dash. In a match `blockedReason() == "CATCHER"`, and Space becomes the **lunge** (`Tag.lunge`, 2.5 s cooldown, `Tag.lungeCharge()`, left = `Tag.lastLunge + GameConfig.Lunge.COOLDOWN - os.clock()`).
- Tag: click, **E**, gamepad **R2** or **X** (Tag's `"EOS_Tag"` action). Touch `TagButton` → `Tag.swing()`. Cooldown is `GameConfig.Capture.TAG_COOLDOWN` (1 s) from `Tag.lastSwing`.

## 3. Screens and panels in the old UI

Keys: there are **no hotkeys that open panels** (no B or P). Panels open from buttons, lobby prompts (`OpenScreen`) or code. **Esc** closes the open panel, or the results card if no panel is open. **Gamepad B** closes a panel (bound at priority 3000 while one is open). Opening the Roblox menu closes panels. Gamepad/TV: opening a panel selects its first button, and each `Panel` is a SelectionGroup that stops at its edges.

### 3.1 HUD (`EOS_HUD`)

| Element | Shows / does | Visible when |
|---|---|---|
| `TopLeft.QuestsPill` / `TopLeft.IncubatorPill` | open Quests / Incubator. `Badge` = claimable quest / a hatch is affordable. | lobby |
| `TopRight.StatsBtn` / `TopRight.SettingsBtn` | open Stats / Settings | lobby |
| `LeftRail.ShopBtn`, `PetsBtn`, `EmotesBtn` | open Shop / Pets / Emotes | lobby (on touch only while the MENU drawer is open) |
| `LeftRail.AFKToggle` / `VolunteerToggle` | send `RequestAFK` / `RequestVolunteer`. Label "AFK: ON/OFF", "HUNT: ON/OFF"; a green edge when on. | same as the rail |
| `MenuButton.Button` | touch: opens and closes the rail drawer | touch, lobby |
| `TopCenter.StatusPill` (`Place`, `Title`, `Sub`) | lobby status (below) | lobby |
| `TopCenter.MatchBar.TimerCard` (`Timer`, `PhaseLabel`) | `Format.time(PhaseEndsAt - now)`. Red with a tick sound in the last 5 s of CROSSING. Label: ROLE_REVEAL "GET READY", WAVE_END "SIDES FLIP", then CATCHER "HUNT!", CAUGHT "YOU'RE OUT", RUNNER "CROSS!". `WaveTag`, `Streak` and `Counts` exist but are hidden. | match |
| `TopCenter.AFKBanner` | "AFK ON: you'll sit out matches..." | lobby and AFK |
| `TopCenter.ArrowHolder.Arrow` | points to the edge of the finish zone (`Layout.Zones[FinishSide]`), relative to the camera | Runner, not safe, in ROLE_REVEAL or CROSSING |
| `Wallet.GoldCard.Value` / `GemsCard.Value` | profile gold/gems with a 0.45 s count-up | lobby |
| `RolePanel` (`RoleTag`, `Card.Egg`, `Card.Line1`) | role chip (RUNNER blue / CATCHER red / CAUGHT grey) and "EGG LEVEL n" (Runner: `EOS_Tier`; others: `EOS_Secured`) with a tier-coloured egg | match |
| `AbilityBar.Card` | equipped pet viewport, ability name, "<RARITY> <SPECIES>", cooldown bar, key plate (Q / Y / seconds left) | only when a pet is equipped |
| `DashBar` | slim meter for dash (lunge for Catchers). Status text only after a refused press. | PC / gamepad |
| `DashButton`, `TagButton`, `AbilityButton` | round touch buttons with cooldown overlays (`Button.Face.Label`, `...Cooldown.Count`). The DASH label becomes LUNGE for Catchers. | touch (Tag: Catcher in a match; Ability: match + pet) |
| `Hint.Text` | first 90 s: "MATCHES START AUTOMATICALLY..."; practice tip | lobby and `showHints` |
| `Banner` (`Title`, `Sub`, `Burst`) | big moments (2.1). Hidden while results show. | queued |
| `Feed` | kill/safe feed | always hidden (feed is off) |

Lobby status text (also drawn on the world board by LobbyService):
- BOOT or not loaded: "LOADING..." / `EOS_LoadStatus`
- WAITING: "WAITING FOR PLAYERS" / "Ready / Needed READY · TRY THE PRACTICE FIELD"
- INTERMISSION: "NEXT MATCH IN m:ss" / "N PLAYERS READY", or the AFK line
- RESULTS: "MATCH OVER" / "NEXT MATCH SOON"
- During a match you're not in: "MATCH IN PROGRESS"

`Place` reads "LOBBY" (or "PRACTICE FIELD" when `EOS_InPractice`).

Match vs lobby: when `EOS_InMatch` is true, every lobby element hides (pills, rail, wallet, status), and the match bar and role panel show. Economy counters never show in a match.

### 3.2 Panels (`EOS_Menus`; each is `<Name>.Panel` with `Header`, `Close`, `Body`)

| Panel | Opens from | Shows | Sends |
|---|---|---|---|
| **Quests** | QuestsPill, prompt | `ResetTimer` ("NEW QUESTS IN 5h 12m"), `List.Quest1/Quest2`: Title, "+N GOLD", progress bar "p / t", Claim plate (CLAIM grey / CLAIM! green / CLAIMED) | `RequestQuestClaim` |
| **Incubator** | IncubatorPill, Incubator desk prompt | `Body.Tiers.Tier_common/rare/epic`: egg icon, "X PIECES", "x N", recipe line, progress n/base, `HatchRandom` + `HatchPick` ("PICK +1"; hidden for the free first pick). `FirstFree` line. Overlays inside the Panel: `Picker` (3 family cards: viewport, ability, species, desc, Pick; `Back`), `Confirm` (Body text, Yes/No), `Reveal` (Egg, View, Burst, Title, Sub, Done). | `RequestHatch` |
| **Pets** | rail PetsBtn | "EQUIPPED: SPECIES · ABILITY", a 4-wide grid of cards (viewport, name, rarity, ability, Equip/EQUIPPED), sorted by rarity then hatch order. Empty state with a Go → Incubator button. | `RequestEquipPet` |
| **Shop** | rail ShopBtn, Gold/Gem shop prompts | `GoldTab`/`GemTab`, wallet, a grid of item cards for the current wallet: swatch colour, name, kind words, desc, price (coin/gem), Buy/OWNED/WEAR/TAKE OFF, Use (confetti, when you have one). Footer text changes per tab. | `RequestBuy`, `RequestUseItem`, `RequestSetCosmetic("case", id or "")` |
| **Emotes** (EmoteController) | rail EmotesBtn | Tabs `CrateTab`/`MineTab`. Crate: odds cards (rarity · %, live avatar preview, OWNED), Open (250 gems), balance, hidden Robux row, a reel that glows across cards, then `Reveal` (Card, Title, Sub, PlayNow "DANCE!", Done). Mine: owned emote cards with Play. | `RequestOpenCrate`, `RequestEmote` |
| **Stats** | StatsBtn | rows `Wins`, `Matches`, `Crossings`, `Captures`, `BestTier` ("LEVEL n"), `Pets`, `GoldEarned`, `FirstHunter`, from `profile.stats` | none |
| **Settings** | SettingsBtn | rows `Sfx`, `ReduceEffects`, `ShowHints`, each an ON/OFF `Toggle`. `Controls` line: "RUN: WASD / stick · DASH: Space / A · TAG: click, E, R2 · PET ABILITY: Q / Y" | `RequestSettings` |

The Scrim (a full-screen TextButton) closes the open panel. Opening a panel pops it from 60% scale with a Back ease, plus the `"open"` sound.

### 3.3 Results (`EOS_Results.Root`)
- `TeamBanner` "RUNNERS WIN!" (blue) or "CATCHERS WIN!" (red), plus `Reason` text per `endReason`:
  - LAST_ONE_STANDING: "THE LAST RUNNER MADE IT ACROSS ALONE"
  - CLEAN_STREAK: "NOBODY WAS CAUGHT 3 CROSSINGS IN A ROW"
  - SAFETY_CAP: "THE MATCH RAN LONG..."
  - FINAL_WAVE: "RUNNERS SURVIVED ALL 3 CROSSINGS"
  - ALL_RUNNERS_GONE: "EVERY RUNNER WAS CAUGHT"
- `TestNote` (shown when `isTest`).
- `Podium.Place1..3`: Avatar headshot, name, "SURVIVED / LAST STANDING / n CROSSINGS · LEVEL n".
- `Thief`: avatar, name, "n CAPTURES · STOLE LEVEL n".
- `You`: piece headline ("RARE EGG PIECE!" or "NO EGG PIECE THIS MATCH"), Source, NearMiss, `Recipe` bar ("RARE 1 / 3 · NEXT HATCH" or "READY TO HATCH!"), `Gold.Total` + `Gold.Lines`, `Gems.Total` (hidden at 0).
- `NextMatch` countdown and a `Continue` button.
- While it's open the HUD is disabled (`hud.Enabled = false`) and banners are cleared. It closes on Continue, Esc or auto-close (2.8), which sets `hud.Enabled = true`.

### 3.4 Overlay
`EOS_Overlay.Toasts` is a vertical list of up to 3 toasts cloned from `EOS_HUD.Templates.Toast`, each with a coloured `Accent` per kind. A toast lasts 3.5 s (6 s if the text is over 50 characters).

## 4. Helpers worth keeping

### Theme (`ReplicatedStorage.EOS.UI.Theme`)
- Colours: `ink`, `textOutline`, `panel`, `glass`, `white`, `mutedText`, `gold`, `goldText`, `gemText`, `badge`, `edge`; transparencies `panelT`, `windowT`, `hudGlassT`, `edgeT`, `studT`, `studSolidT`.
- `Theme.ramps[name] = { ol, rim, top, mid, bot, lip, lip2 }` for blue, green, red, yellow, orange, purple, grey, dark, gold and pink.
- Fonts: `Theme.font` (Montserrat ExtraBold) and `Theme.fontBody` (Bold).
- Images `Theme.img`: `stud`, `studRaw`, `sunburst`, `sparkle`, `shine`, `ring`, `twinkleFlip`.
- Motion `Theme.motion`: `openFrom 0.6`, `openTime 0.34`, `closeTime 0.16`, `hoverScale 1.05`, `pressScale 0.93`, `countUp 0.45`.
- `Theme.sounds`: `click`, `open`, `reward`, `capture`, `swing`, `evolve`, `tick` and `caught`, all built-in `rbxasset://sounds/...` files.

### Sound (client controller)
- `Sound.play(name, pitch?)` uses the names in `Theme.sounds`. It blocks repeats within 60 ms and respects `Sound.enabled`.
- `capture` volume is 0 (muted, Oct 15). Everything is preloaded at require time.
- These are Roblox client sounds, not synthesised ones, so they're fine under the audio rule.

### Format (`Shared.Format`)
- `Format.full(n)` → "12,345"
- `Format.short(n)` → "12.3K" (exact below 10,000)
- `Format.time(sec)` → "1:15" or "1:02:05"
- `Format.duration(sec)` → "1h 2m", "2m 5s" or "5s"
- `Format.plural(n, one, many?)` → "3 CAPTURES" (keeps upper case)

### UIKit (`ReplicatedStorage.EOS.UI.UIKit`), for building at runtime or edit time
- `UIKit.new(class, props, parent)`, `corner(parent, radius)`, `stroke(parent, color, thickness, mode?)`, `vgrad(parent, top, mid?, bot)`
- `UIKit.text(parent, o)`: an outlined TextLabel. `o`: Name, Text, TextSize, Color, Size, Position, AnchorPoint, Align, YAlign, Scaled, Stroke, Wrapped, RichText, ZIndex, LayoutOrder, Font, Visible, MinTextSize.
- `UIKit.plate(parent, o) -> (root, face, label)`: a button or tag. `o`: Ramp, Solid, Button, Accent, Studs, Radius, TileSize, AccentHeight. Element names are `Face`, `Face.Label`, `Face.Edge`, `Face.Fill`, `Face.Accent`. **`UIKit.setRamp(root, rampName)`** recolours it.
- `UIKit.panel(parent, o) -> (root, body, close)`: a window with `Header.Title`, a red X `Close` and `Body`.
- `UIKit.card(parent, o)` (Tint, Studs, Outline), `UIKit.bar(parent, o) -> (track, fill, label)`, `UIKit.studs(parent, transparency?, tile?, radius?)`
- `UIKit.glyph(parent, kind, o)`: shape icons. kind is `coin`, `gem`, `bag`, `bars`, `paw`, `list`, `zz`, `target`, `gear`, `note`, `speaker` or `egg`.
- `UIKit.eggIcon(parent, o)` + **`UIKit.setEggIcon(icon, tier)`**: an egg drawn in the tier's colours (`TierConfig.get(tier)`).
- `UIKit.arrow(parent, o)`: a direction arrow; rotate its root.
- `UIKit.fit(group, base?)`: adds the `Fit` UIScale and the `EOS_Fit` tag.

### Other client helpers
- `Fit.track(gui)`, `Fit.scaleFor(g)`, `Fit.setDesignPosition(g, anchor, pos, extra?)`, `Fit.refreshAll()`
- `PetModel.viewport(vp, species, yaw?)` fills a ViewportFrame with a voxel pet. `PetModel.build(species, scale?)` returns a Model.
- `TierConfig.get(level)` returns `{ name, shell, spot, text, ... }`; use `.text` for level-coloured text. `TierConfig.CATCHER_TIER_CAP = 3`. Levels are open-ended (groups Common 1, Rare 3, Epic 5, Legendary 7, Cosmic 10).
- Code inside UIController worth copying:
  - `juicy(button, fn)`: hover 1.05, press 0.93, Back spring, click sound
  - `pop(group, from?)`: tween `Fit` from 60% with a Back ease
  - `setWallet` count-up
  - `deviceClass()`: `"touch"`, `"console"`, `"gamepad"` or `"pc"`
  - `costFor(m, focused)`, `haveFor(m)` and `hatchReady()` for incubator maths

## 5. Fragile: names other code looks up

| Who | Looks up | Effect if the name is gone |
|---|---|---|
| `UIController.init` | `PlayerGui:WaitForChild("EOS_HUD" / "EOS_Menus" / "EOS_Results" / "EOS_Overlay")`, no timeout | **infinite yield**: every controller after UIController never inits (1.1) |
| UIController (everywhere) | dot-paths into those guis, e.g. `hud.TopCenter.MatchBar.TimerCard.Timer`, `menus.Incubator.Panel.Picker`, `results.Root.You.Recipe` | errors in `updateHUD`, which is pcall'd and warns once per message, or at wiring time (not pcall'd: init stops) |
| `EmoteController.init` | `PlayerGui:WaitForChild("EOS_Menus"):WaitForChild("Emotes"):WaitForChild("Panel")`, then `Body.Tabs.CrateTab/MineTab`, `Body.Crate.Grid.OddsCard`, `Body.Crate.Open` (`Face.Label`), `Body.Crate.Balance`, `Body.Crate.Robux`, `Body.Mine.Grid.MineCard` (`View`, `Rarity`, `EmoteName`, `Song`, `Note`, `Play`, `Edge`), `Body.Mine.Empty.Go`, `Body.Wallet.Gems.Amount`, `Panel.Reveal` (`Card.View/Edge/Rarity/EmoteName/Song`, `Burst`, `Title`, `Sub`, `PlayNow`, `Done`), `Panel.Header`, `Panel.Close` | infinite yield / init error: no emote playback, no songs |
| `EmoteController` | `require(script.Parent.UIController)`: `UI.toast`, `UI.close`, `UI.openName() == "Emotes"`, `UI.juicy`, sets `UI.onEmotesRefresh` | must keep these functions (or point EmoteController at the new UI module) |
| `ClientMain` | `require(Controllers.UIController)` + `UIController.init()` | swap in the new controller here |
| `Tag`, `CameraFX`, `Pets`, `Movement` | the hook fields in 1.4 (defaults are no-ops) | without them: you can tag through open menus, the mouse stays locked under menus, and there's no decoy/scout toast |
| `UIBuilder()` | destroys StarterGui children named `EOS_HUD`, `EOS_Menus`, `EOS_Results` or `EOS_Overlay` before rebuilding | if the new UI reuses those names, **running UIBuilder wipes it**. Retire UIBuilder or use new names. |
| Server `OpenScreen` | panel names `"Incubator"`, `"Shop"` (+ `tab` `"gold"`/`"gems"`), default `"Quests"` (from the `Screen` attribute on `EOS_Prompt`-tagged parts) | the new UI must accept these names. The old UI ignores names not in its `PANELS` list. |
| `NpcSkins` | `PlayerGui.EOS_FriendSkins` (the server puts friend avatar models there) | don't clear PlayerGui wholesale |
| `CameraFX` | makes `PlayerGui.EOS_Crosshair` (DisplayOrder 6) | keep match HUD DisplayOrders sensible around it |
| Old StarterGui guis | all four are `Enabled = false` today | remove them or keep them disabled; UIController only ever sets `hud.Enabled` |

Stale comments in `Net` (trust the server code): `AbilityState` sends `readyIn`, not `readyAt`. `ScoutPing` sends `duration`, not `untilT`. `RequestProfile` takes `device`. `HatchResult` also has `royal`. `QuestState` is never fired. `RoleChanged` also carries `byName`, `bySlot` and `graceUntil`.

Other gotchas:
- NPCs: in `RunnerEvolved`, `CaptureFeedback` and `Results`, NPC entries carry a slot (`slot`, `hunterSlot`, `victimSlot`, `npcSlot`). Their `userId`/`name` are server stand-ins. Always prefer `NpcSkins.nameForSlot(slot)`.
- `Results` reaches lobby players too, without `you`. Decide whether spectators should see the card. (The old UI shows it to everyone.)
- `EOS_Tier` is nil for non-Runners. Fall back to `EOS_Secured`, then 1.
- Server time: always count down against `workspace:GetServerTimeNow()`, never `os.clock()`. (Ability, dash and lunge cooldowns are the exception: they use `os.clock()` locally.)

## 6. Feature flags and switched-off UI

| Switch | Where | Value | Effect on UI |
|---|---|---|---|
| `GameConfig.Features.SHOP_PURCHASES` | GameConfig | false | No Robux Gem packs. `EconomyConfig.GEM_PACKS` all have `productId = nil`. **No client code reads the flag.** The old UI has no Robux shop at all. Gate any new Robux UI on the flag **and** a real `productId`. There is no `ProcessReceipt` handler yet. |
| `GameConfig.Features.ABILITIES / PETS / HATCHING / COSMETICS` | GameConfig | true | not read by the client today |
| `GameConfig.Features.PRACTICE_BOT` | GameConfig | true | but `Layout.Practice.enabled = false`, so practice never runs and `EOS_InPractice` / `PracticeEvent` never happen |
| `EmoteConfig.ROBUX[*].productId` | EmoteConfig | nil | the Robux crate row (`Crate.Robux`) stays hidden until **all three** have ids |
| `FEED_ENABLED` | UIController local | false | kill feed off ("minimal HUD") |
| Minimal-HUD hides | UIController | hard-coded | MatchBar `WaveTag`, `Streak`, `Counts`; RolePanel `Line2`, `Objective`; `ArrowLabel`; DashBar `Key`/`Tip`; no hint text in a match; no AbilityBar without a pet; no non-forced toasts in a match |
| `GameConfig.Dash.CATCHER_DASH` | GameConfig | false | Catchers get the lunge instead (meter/button relabelled) |
| `GameConfig.Dash.ENABLED`, `Lunge.ENABLED` | GameConfig | true | `blockedReason() == "OFF"` hides the dash cooldown text |

## 7. Checklist for a replacement UI

1. Make a new client controller with `init()`, and call it from `ClientMain` in place of `UIController.init()`. Or keep the module name `UIController` and its API (1.3) so EmoteController keeps working.
2. Keep or rewrite EmoteController's panel lookups (section 5). The emote playback and songs live in the same module, so don't drop it.
3. Set the hooks in 1.4: `Tag.isUIOpen`, `CameraFX.lockBlocked`, `Tag.onDecoy`, `Pets.onToast`, `Pets.onUsed`, `Movement.onDash`, settings → `Sound.enabled` / `CameraFX.reduceEffects` / `WorldFX.reduceEffects`, and the ResetButtonCallback.
4. On init, fire `RequestProfile(deviceClass)`, and fire it again when the input type changes.
5. Listen to: `ProfileState`, `Toast`, `OpenScreen`, `HatchResult`, `ShopResult`, `Results`, `RoleChanged`, `RunnerEvolved`, `CaptureFeedback`, `MatchState`. Pets already handles `AbilityState`, `AbilityFx` and `ScoutPing`; EmoteController handles `CrateResult`. ClientMain's no-op listeners stay.
6. Poll or watch `EOS_State` (`Phase`, `PhaseEndsAt`, `Ready`, `Needed`, `FinishSide`, `Wave`, `CleanStreak`) and the player attributes in 2.4 for the HUD.
7. Retire the four `EOS_*` StarterGui guis and UIBuilder, or rename the new guis (section 5).
