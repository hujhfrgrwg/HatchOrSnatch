# Hero or Chicken UI redo: renders for Hunter's check (HOS-HOC-001, 17 Oct)

Made with roblox-ui-maker in the EOSUI project (`C:\HatchOrSnatch\UI`), section "Hero or Chicken (HOS-HOC-001)"
of `UI/build.py`, using only its components (T, at, row, grp, sub, box, world, topbar) and its skin
(`UI/kit.css` + `UI/styles/candy.css` + `UI/styles/sport.css`). Style reference: the live match HUD
(`UI/cap_match_field.jpg`, crops `UI/hc_ref_header.png`, `UI/hc_ref_egg.png`) and its exported layout
(`ref_MatchHUD_Status_Egg.json`: FredokaOne, 3.51 / 1.56 UIStroke, flat white fills, .glass card).
`read_reference.py` on an in-game capture (`UI/hc_ref/`) agreed: ~2 px text outline and ~4 px plate edges at
half scale, no studs, so no new tokens were added.

- Titles use the round header treatment (22 'xs' phase / 50 'l' headline / 22 'xs' subline, no backing panel, accents as
  flat f-gold / f-red fills). Countdowns sit in the subline, like the header's "Runner · 0:21". There's no timer disc.
- The panels (HERO / CHICKEN pick cards, +200 chip) are the best-egg card (.glass) with the choice's accent on the inner ring.
- Every group is symmetric about x = 960, so it centres at any aspect ratio.
- The HERO ATTEMPT line sits right under the round header; the HERO tag over the Hero is small header-style text.

Files (all @2x): style, every beat a1-d4, phone (e1, 844x390: pick cards 1.3x), the exported screen + templates,
and `hc_compare@2x.png` (each beat beside the existing round header + egg card). `?check` overflow: none on all 15 pages.
