# Halloween Featured store (HOS-HWN-001, 17 Oct)

Three limited pets sold outright on the Shop's Featured page until **Nov 1 2026 00:00 UTC**; buyers keep them after.
Hunter (17 Oct): "Do the mummy and the cat and the wrath, with the wrath being legendary and the other two being epic.
Put them into archetypes. Buying these pets grants the ability." This is his exception to the "Gems / Robux buy looks
only" rule (PurchaseService header, GDD 18), for these three pets only.

| Pet | Family | Rarity | Price | Item id |
|---|---|---|---|---|
| Pumpkin Wraith | Invisibility | Legendary | 399 Robux (developer product 3719178740) | `hwn_wraith` |
| Witch's Cat | Decoy | Epic | 250 Gems | `hwn_cat` |
| Mummy | Guardian | Epic | 250 Gems | `hwn_mummy` |

Prices, product id and the end date live in `ReplicatedStorage.EOS.Shared.HalloweenShop` (PETS, ENDS_AT).

## How it works
- `HalloweenShop.inject(EconomyConfig)` (one line at the end of EconomyConfig) adds the pets to `EconomyConfig.SHOP` as
  kind `"pet"` (so PurchaseService maps the Wraith's product), wraps `EconomyConfig.item`, sets EXTRA_SPECIES /
  SPECIES_RARITY / DISPLAY_NAMES / FEATURED, adds `FAMILIES.Guardian` (no species, not a launch family) and the
  `buyPet` / `grantPetPurchase` hooks.
- `ProfileLogic.buy` and `ProfileLogic.grantItemPurchase` hand kind `"pet"` to those hooks (one line each). A bought pet
  is the same record `IncubatorLogic.addPet` writes (id, family, rarity, species, n, level; equipped if nothing is), plus
  `cosmetics.owned[id] = true` so the shop shows OWNED. Gems buys stop at ENDS_AT ("ENDED"); a Robux receipt that arrives
  later still grants (Roblox retries receipts). Owning the species already = OWNED (Gems) / nothing granted (receipt).
- UI: three roblox-ui-maker cards (`ui/build.py` `hwn_card` / `s_hwn_templates`, export workspace `ui_hwn/`) built into
  `ReplicatedStorage.HalloweenUITemplates`. `Controllers.HalloweenShopUI.slots(sc)` (called from UIController's Featured
  loop, one line) clones them into PageFeatured, hides FeatA / FeatB, fills the "ENDS IN" countdown and returns the slot
  map, so the existing loop fills title, tagline, portrait, Robux / Gems / OWNED buttons and the Have line. After
  ENDS_AT it returns the old FeatA / FeatB pair. Buy confirm says "Yours to keep, with its ability." for pets.
- Original lines and every new instance: `docs/backups/HOS-HWN-001_20261017/ORIGINAL_LINES.md`.

## Checked in a solo playtest (17 Oct, memory-only data)
- Robux path (receipt function called on the server, no real purchase): Wraith granted, legendary, auto-equipped, follower shown.
- Gems path, server: Cat and Mummy bought (600 -> 100 Gems), second Cat refused OWNED, Mummy refused NOT_ENOUGH when short,
  Wraith refused BAD_WALLET for Gems.
- Gems path, real client remote in the lobby: RequestBuy("hwn_cat") -> ShopResult ok and the "UNLOCKED! Witch's Cat" reward.
- Shop Featured page live with the three cards and countdown, all OWNED (`../previews_page/store/ingame_shop_owned.jpg`).
- Not checked live: a real Robux purchase prompt (Studio can't buy), the buyable / short-on-Gems card states in the real
  gui (checked in the HTML only), the Cat and Mummy abilities inside a real match (their summons were played on the
  client), phone layout. The sandbox attribute (`workspace.EOS_Sandbox = true`, left on by another session) had to be
  switched off inside the playtest to reach the lobby shop.
