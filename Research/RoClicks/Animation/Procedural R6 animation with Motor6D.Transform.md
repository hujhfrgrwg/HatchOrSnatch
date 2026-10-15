---
tags: [research, roclicks]
source: https://roclicks.gg/resources/animation/procedural-r6-animation
retrieved: 2026-10-15
---
# Procedural R6 animation with Motor6D.Transform

Animating characters from code with no uploaded assets, guaranteeing R6, and checking poses without a playtest.

You don't need uploaded animation assets to animate a character. Movement systems (parkour, slides, wall-runs) and crowds of units are often easier to drive entirely from code.

## Drive joints with Transform, not C0

Every frame, set each joint's `Motor6D.Transform`. Transform is the per-frame animation offset Roblox layers on top of `C0`/`C1`, which is exactly what the Animator itself writes. Leave `C0` alone: it's the rig's rest pose, and changing it permanently moves the limb.

Write Transform in `RunService.PreSimulation`, which runs **after** the Animator has posed the frame, so your pose wins for that frame. When your override ends, stop writing and the playing animations take over again.

## Newer avatars don't use Motor6D everywhere

On newer avatars, joints such as the shoulders can be `AnimationConstraint`s. You can't set their `C0`, and turning their attachments doesn't move the limb. Code written for Motor6D skips them **without an error**, so a raised-arm pose silently does nothing. Handle both:

- a Motor6D: use its Part0, C0 and C1;
- an AnimationConstraint: use `Attachment0.Parent`, `Attachment0.CFrame` and `Attachment1.CFrame` in the same maths.

## Guarantee R6 from the server

If your animation code assumes R6, don't trust the place settings. Turn `CharacterAutoLoads` off and spawn each character from the server with `Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)`. Every character is then the rig your code expects.

## Pointing a limb at a target

To aim an arm, rotate its hanging direction onto the direction to the target, both expressed in the joint's own frame. Compute the rotation between the two vectors (cross product for the axis, dot product for the angle) and apply it as the Transform.

## Check poses without a playtest

Playtest screenshots are a poor way to judge a pose. Instead, in edit mode:

1.  Lay out a "pose sheet": a row of dummy rigs, one per pose.
2.  Apply each pose, then bake it into the dummies' joint `C0`s so it stays visible without anything running. (Changing C0 is fine here: these are throwaway copies, not the real rig.)
3.  Screenshot the sheet from a fixed camera.

One edit-mode trap: `RunService.PreSimulation` and `Stepped` **don't fire in edit mode**; `Heartbeat` does. Let your animator fall back to Heartbeat when the game isn't running, so you can verify Transform values without starting a playtest.

Next: [[Rigging models that move cleanly]]
