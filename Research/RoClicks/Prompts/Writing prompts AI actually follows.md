---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ai-prompts/writing-prompts-that-work
retrieved: 2026-10-15
---
# Writing prompts AI actually follows

The rules behind every prompt on this site, for image models and coding assistants alike. Learned by watching prompts fail.

Copy the prompt with the button on its box, then paste it into your AI.

Every prompt in this section follows the same handful of rules. They apply whether you're prompting an image model for a thumbnail or a coding assistant to build a map.

## Concrete nouns beat adjectives

"Make it look more Roblox" changes nothing. "Arms are long rectangular prisms that end flat, with no hand part; the face is a flat graphic printed on the head" changes everything. Describe shapes, sizes, materials and counts, not vibes.

## Name the failure you keep seeing

Positive instructions alone drift. Add the specific failure: "a row of same-sized evenly spaced characters has failed", "if the character could pass for a real human, the image has failed". Models avoid a named failure far more reliably than they hit a described goal.

## But don't name what you don't want to see (image models)

For image models there's a catch: the words you use appear in the picture. "Never draw toy bricks" draws toy bricks. Name the failure as a **shape or behaviour** ("raised bumps on the ground") rather than as a **thing** ("bricks"), or describe the wanted result instead.

## Show, don't tell

When a rule keeps losing after a couple of rewrites, stop rewording it. Attach two to four real reference images and say what each one is for: "match this surface finish; don't copy its layout". Real images beat paragraphs.

## The end of the prompt wins

Long prompts lose their middle. Put the user's actual request near the end, and finish with a **short numbered list** of the three to five things that must be true. Don't spend the last line on something minor.

## One change at a time

When iterating, change one thing per round and say what you changed. Three changes at once means you can't tell which one helped, and the model often half-applies all three.

## Ask for the diagnosis before the fix

Before asking for a fix, ask the AI to say what's wrong first: "Before changing anything, list what is wrong with this image and why." You'll catch it misreading the problem before it spends a round fixing the wrong thing.

## Make it check its own work

Tell a coding assistant how "done" is measured: screenshots from player height, a property sweep for text that doesn't fit, all pages returning 200. "Verify before you show me" with a concrete method works; "make sure it's good" doesn't.

## Put guardrails on anything that costs or publishes

"Ask before spending credits", "don't upload or publish anything", "don't start a playtest, give me a checklist". An assistant that knows the boundaries works faster, because you're not watching it.

## The user's words outrank house rules

If your prompt has global rules ("three characters max") and the request asks for six, the request should win. Say so explicitly at the end: "everything above is a default for what the request leaves open".

See also [[Prompting image models for Roblox art]] for the image-specific lessons in depth.

Previous: [[The UI import prompt HTML to a Roblox ScreenGui]] · Next: [[Prompts for AI 3D models]]
