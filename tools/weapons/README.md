# Weapon skin builds (HOS-WEP-002)

Original dagger-skin blades made from scratch in Blender to replace the IP-risk models found in HOS-WEP-001 (Genshin swords, Yamato, the Korblox scythe copy). No outside meshes are used.

- `build_blades.py`: builds Stormfang Katana, Starforged Blade and Grave Crescent Scythe procedurally. One object per material, so Roblox gets one MeshPart per colour; `Glow*` parts become Neon in Studio.
- Run it headless:
  `"C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" --background --factory-startup --python build_blades.py -- <out_dir>`
- Outputs go to `out/`: `<Name>.fbx`, `<Name>.blend`, and `_front` / `_3q` renders.
- Preview sheet: `docs/HOS-WEP-001/original_blades_draft1.png`.

Status 17 Oct: draft 1 is waiting for Hunter's look. Not uploaded yet. Upload with `tools/upload/upload_assets.py` (FBX arrives turned 180 degrees and at 100x size; see CLAUDE.md). Then shrink each one to 3.0 studs and give it the Minute Dagger's grip.
