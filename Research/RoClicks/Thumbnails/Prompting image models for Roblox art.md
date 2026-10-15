---
tags: [research, roclicks]
source: https://roclicks.gg/resources/thumbnails/prompting-image-models
retrieved: 2026-10-15
---
# Prompting image models for Roblox art

Hard-won rules from generating thousands of Roblox thumbnails with AI image models: negation, recency, jargon, and showing instead of telling.

These came from building an AI thumbnail generator and fixing it against real user ratings. They apply to any image model you prompt for Roblox art.

## Don't name what you don't want

Image models handle negation badly. "NEVER draw toy bricks" doesn't suppress the idea, it puts it in the picture. One prompt that said the banned brand name a dozen times, plus "knob", "peg" and "brick" dozens more, produced toy-brick scenes more often the more warnings were added.

**Describe what you want instead:** "every surface is a single unbroken plane of smooth plastic, flat colour, any pattern printed flush". Where a negative is unavoidable, phrase it without the loaded noun.

## Watch for construction verbs too

Removing the banned word isn't enough if you replace it with its description. "Environments assembled from simple boxes and wedges" is a description of toy-brick construction. Describe how things **look** (each building is one solid object with a continuous smooth shell), not how they're **built**.

## Translate jargon before the model sees it

"Stud", "baseplate" and "brick" are Roblox words, but a model's strongest association for them is toy bricks. Explaining what a stud is loses to the word itself sitting in the request. Rewrite the request instead: "a stud-style table on a stud green baseplate" becomes "a classic smooth-plastic Roblox style table on a flat green Roblox ground part". Leave measurements alone ("20 studs tall").

## The end of the prompt wins

Long prompts lose their middle. Whatever the model reads **last** carries the most weight, so:

- put the hard rules after the user's request, not before it;
- end on a **short numbered list** of the few things that must be true, naming the exact failure ("never show a real hand holding a controller") rather than describing the goal;
- don't spend the final line on a minor rule.

## Show, don't tell

When a rule keeps losing after several rewrites, stop rewording it. Pin two or three **real reference images** that show the target and label them with the one job they do ("match this surface finish; do not copy its layout or subject"). Real images moved results when seven rounds of prose didn't.

And don't mute your best evidence: labelling real Roblox references as "use only for colour and mood" switches off exactly what they're best at showing.

## Don't let house rules overrule the request

Global rules ("three characters max", "blocky arms have no hands", "low camera angle") are **defaults**, never vetoes. When a user asks for six players, hands on a head, or a specific pose, the request wins. And composition rules only belong on brand-new images: appended to "just remove the chicken in the middle", they make the model re-stage a picture it was asked to leave alone.

## Read your own prompt for contradictions

A prompt that recommends "volumetric god rays and atmospheric fog" in one section and bans haze in another produces haze. Before adding a rule, search the prompt for anything that argues with it.

## Check what the model actually received

When output ignores a rule, don't guess. Log the final compiled prompt and the reference images actually attached, and read them. More than once the rule was present but buried, contradicted, or never deployed.

Previous: [[Getting Roblox avatars right]]
