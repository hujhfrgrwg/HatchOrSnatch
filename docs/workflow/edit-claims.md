# Studio edit claims (PC sessions)
One line per claim: script | thread title | UTC time. Re-read before writing, and delete your line when done.
Claim PLAYTEST before running a self-closing playtest (one at a time).
NOTE for HOS-EGG-002 (not a claim) | Results screen v2 (HOS-PTS-001) is live in PointsUI: the end-of-match card is now group ResultsV2 (the old Leaderboard group only shows between crossings and no longer has the egg/rewards box). Egg names unchanged: EggSlot, EggText, EggHow, PieceIcon, PieceText (fixed 250 design px box). Their parent frame is now 'EggBlock' (500x140), not 'You', so EggMini falls back to pieceText.Parent = EggBlock, which places it right. ResultsV2 fades in at about 0.55 s; EggMini, added at 0.3 s, shows before the box fades in, so delay it to 0.8 s or parent it after. | 18:55Z
ServerStorage.EOS_Assets.KnifeSkins (new folder, no scripts) | Weapon skins (HOS-WEP-001) | 20:44Z
