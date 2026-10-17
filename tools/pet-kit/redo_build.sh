#!/usr/bin/env bash
# Pet redo (HOS-PET-REDO, 17 Oct; copy of reshape_build.sh with its own backup folder and superseded tag): Blender build + level / anim renders + sheets + upload list for one pet.
# usage: bash tools/pet-kit/reshape_build.sh <docs slug> <module dir> <Prefix> "<Species>" "<L2 name>" "<L3 name>" "<clips>"
# e.g.   bash tools/pet-kit/reshape_build.sh aegis_kirin kirin Kirin "Aegis Kirin" "Aegis Warden" "Celestial Aegis" "Idle:Idle,..."
# Moves the old previews / anims into docs/backups/HOS-PET-REDO_20261017/<slug>_*_old, marks the old upload ids in
# Assets/asset_ids.json as superseded, and writes Assets/<module>_redo_upload.json. Uploading stays a separate step.
set -e
SLUG=$1; MOD=$2; PFX=$3; SPECIES=$4; L2=$5; L3=$6; CLIPS=$7
ROOT=/c/HatchOrSnatch
B="/c/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe"
D="C:\\HatchOrSnatch\\docs\\pets\\$SLUG"
BK=$ROOT/docs/backups/HOS-PET-REDO_20261017
mkdir -p "$BK"
cd $ROOT/tools/pet-kit
python make_build_hos.py $MOD/$MOD.py --save-root "$D\\build" >/dev/null
"$B" --background --factory-startup --python build/${MOD}_build.py 2>&1 | grep -E "PET BUILT|Traceback|Error" || true
cd $ROOT/docs/pets/$SLUG
[ -d previews_pass1 ] && [ ! -d "$BK/${SLUG}_previews_old" ] && mv previews_pass1 "$BK/${SLUG}_previews_old"
[ -d anims_pass1 ] && [ ! -d "$BK/${SLUG}_anims_old" ] && mv anims_pass1 "$BK/${SLUG}_anims_old"
rm -rf previews_pass1 anims_pass1
for f in ${SLUG}_levels.jpg ${SLUG}_levels_pass1.jpg; do [ -f $f ] && [ ! -f "$BK/${f%.jpg}_old.jpg" ] && cp $f "$BK/${f%.jpg}_old.jpg"; done
cd $ROOT/tools/pet-kit
for L in 1 2 3; do "$B" --background --factory-startup --python render_pet_blender.py -- "$D\\build\\$MOD" "$D\\previews_pass1" $L 2>&1 | grep -E "Traceback" || true; done
"$B" --background --factory-startup --python render_pet_anims.py -- "$D\\build\\$MOD" "$D\\anims_pass1" 3 360 2>&1 | grep -E "ANIM FRAMES|Traceback" || true
cd $ROOT
python tools/pet-kit/make_sheets.py $SLUG "$SPECIES" "$L2" "$L3" "$CLIPS" 2>&1 | tail -1
python - "$SLUG" "$MOD" "$PFX" <<'EOF'
import json, os, sys
slug, mod, pfx = sys.argv[1:4]
b = 'docs/pets/%s/build/%s/%s_' % (slug, mod, pfx)
L = [b + 'Pet.fbx'] + [b + n + '.png' for n in ['Color', 'Color_L2', 'Color_L3', 'Normal', 'Roughness', 'Emit', 'Emit_L2',
                                                'Emit_L3', 'Face', 'Face_L2', 'Face_L3', 'FaceEmit', 'FaceEmit_L2', 'FaceEmit_L3']]
assert all(os.path.exists(p) for p in L), [p for p in L if not os.path.exists(p)]
ids = json.load(open('Assets/asset_ids.json'))
n = 0
for p in L:
    if p in ids:
        k, i = p + '#superseded-HOS-PET-REDO', 2
        while k in ids:
            k, i = p + '#superseded-HOS-PET-REDO-%d' % i, i + 1
        ids[k] = ids.pop(p)
        n += 1
json.dump(ids, open('Assets/asset_ids.json', 'w'), indent=1)
json.dump(L, open('Assets/%s_redo_upload.json' % mod, 'w'), indent=1)
print('upload list', len(L), 'superseded', n)
EOF
