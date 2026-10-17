# Thunder Toad: pet-kit rebuild (HOS-PET-016 v3)

**Reference:** Hunter's Tempest card (`docs/pets/concepts/thunder_toad_hunter_reference_2.png`) first, then his model sheet.

## Build
- **Mesh:** one connected 14-sided anti-prism body+head loft. The jaw/throat, legs, eye sockets and tail are buried lofts. The spikes and crest are rigid gems.
- **Face:** a mat-1 face decal of flush round eye discs, with a painted iris, pupil, two highlights and the brow lid.
- **Triangles:** L1 1,488 / L2 1,512 / L3 1,536. 18 bones.
- **Atlas:** 1024 px. Cobalt, top-lit, with a cream belly/throat and navy undersides. Big lightning bolts on the back, flanks and legs; yellow warts and cheek dots. Glossy: roughness 0.22 on the skin, 0.45–0.5 on the cream.
- **Glow:** an emissive mask on the bolts, spikes, crest and toe pads.
- **Levels:**
  - L2 adds a head bolt, crest fin and haunch spikes, with richer colour.
  - L3 adds a crest star gem and shoulder spikes, with richer colour again.

## Passes
1. **v1:** first loft. Too tall-headed, small markings, pale spots everywhere.
2. **v2:** bigger head and jaw, chunkier legs, a single crest, bigger bolts, a brow lid painted onto the eye. A floating grin tube showed up.
3. **v3:** re-seated the grin; feet raised to ground level (an ankle ring was below z=0).
4. **v4:** removed the grin tube (the blue/cream jaw line is the smile, as on the card); saturated yellow markings.
5. **Animation pass 2:** less front-leg reach in Run and Hop.

## Checks (`make_previews.py`)
- Tris, weights (≤4, normalised), lowest point = 0, toe-pad clipping into the body in every animation frame (none).
- Open edges only on the eye-socket rims, which are hidden behind the eye decal.

## Known issues
- Flat facets still show on the jaw; it would need more ring segments.
