---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/input
retrieved: 2026-10-15
---
# Input

Input bugs look like "the button sometimes doesn't work" or "my airstrike landed on my own army". They come from several listeners hearing the same event, and from mixing up coordinate spaces.

Input bugs look like "the button sometimes doesn't work" or "my airstrike landed on my own army". They come from several listeners hearing the same event, and from mixing up coordinate spaces.

- [[#One click, one owner]]
- [[#Coordinate spaces]]
- [[#Touch: pinch deltas and per-finger drags]]
- [[#Watch and follow cameras]]
- [[#Modes disable what they replace]]
- [[#Testing input from an agent]]
- [[#Checklist]]

## One click, one owner

`UserInputService.InputBegan/InputEnded` deliver every world click to **every** listener. In one game the click that confirmed an ability target also hit a country plate (opening a menu mid-battle) and a building (opening its panel). None of the three handlers knew about the others.

Give world clicks a claim API:

``` lua
-- Input module
local claim = { held = false, t = -1 }
local touchesDown, lastRelease = {}, -1
UserInputService.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then touchesDown[i] = true end
end)
local function pressDown()
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or next(touchesDown) ~= nil
end
function Input.claimClick() claim.held = pressDown(); claim.t = os.clock() end
function Input.clickClaimed()
    local age = os.clock() - claim.t
    return (claim.held and age < 3 and (pressDown() or os.clock() - lastRelease < 0.25)) or age < 0.25
end
UserInputService.InputEnded:Connect(function(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.Touch then touchesDown[i] = nil end
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        lastRelease = os.clock()
        if claim.held then claim.held = false; claim.t = os.clock() end
    end
end)
```

- The handler that acts on a press (ability confirm, a real map drag) calls `claimClick()`. Every other world-click listener checks `clickClaimed()` in its `InputEnded` and skips.
- The claim lasts while the press is held and a short moment after, because listeners on the same `InputEnded` run in arbitrary order. Do not let it stick for seconds, or it swallows the next tap.
- `UserInputService` has **no** `GetTouchesInProgress`; count fingers yourself. A claim function that called it threw on every call, so no click was ever claimed.
- For a modal mode (targeting), the alternative is `ContextActionService:BindActionAtPriority(name, fn, false, priority, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)` returning `Enum.ContextActionResult.Sink` while active.
- Hotkeys that a mode repurposes (1-8 in battle) should be sunk with ContextActionService so the hotbar sees them as processed, instead of every module checking "am I in battle?".

## Coordinate spaces

- `InputObject.Position` and GUI `AbsolutePosition` share one space. With a full-screen `IgnoreGuiInset` root, `AbsolutePosition` reports (0, -58), so world picking is `input.Position - root.AbsolutePosition`; do not add `GetGuiInset()` on top.
- For world rays from input positions use `camera:ScreenPointToRay` (GUI space). Use `ViewportPointToRay` only with `UserInputService:GetMouseLocation()` (viewport space). Mixing them puts every pick 58 px off.
- **On touch, use the tap position, not a mouse-following reticle.** A reticle updated each RenderStepped from `GetMouseLocation()` still sits on the ability button when the ground tap's `InputBegan` arrives, so the strike lands under the button. Confirm with the tap point; keep the reticle as the mouse fallback only.

## Touch: pinch deltas and per-finger drags

- `TouchPinch`'s `scale` is **cumulative since the pinch began**. Applying it as a per-event factor zooms in a runaway direction and never reverses. Convert to a delta:

  ``` lua
  local pinchLast = 1
  UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
      if state == Enum.UserInputState.Begin then pinchLast = 1 end
      if processed or state ~= Enum.UserInputState.Change then return end
      local f = scale / math.max(pinchLast, 1e-3)
      pinchLast = scale
      zoomBy(1 / f) -- route through the same function as the mouse wheel
  end)
  ```

- **Key a drag on the InputObject that started it.** Store `dragging = { input = input, last = ... }`, pan only on changes from that same input, ignore new touches while dragging (pinch owns two fingers), and end the drag only when that input ends. Otherwise the second finger of a pinch makes the map jump by the distance between the fingers.

- Do not let a thumbstick touch drive anything else (e.g. drag a building ghost under the thumb).

## Watch and follow cameras

A "watch the battle" camera must not cancel itself during normal use. One version broke on *every* unprocessed key and every click, including the battle's own speed and ability hotkeys, so it undid itself constantly.

- Break only on **movement and camera input**: WASD/arrows/Space, right mouse, mouse wheel, thumbsticks, a touch that **moves** more than ~10 px (check in `InputChanged`, not `InputBegan`), or the character actually moving.
- Hotkeys, left clicks and taps (ability targeting, UI) never break it.
- Never lock the camera for events the player is not part of (AI vs AI fights). Offer Watch for their own events; any movement input hands control back.

## Modes disable what they replace

- A map/overview mode that pans with WASD must **disable character controls** (`PlayerModule` controls `:Disable()` on enter, `:Enable()` on exit and on death). Otherwise the hidden character walks across the map while the player pans, and exiting flies the camera to wherever it ended up.
- A "page open, ignore hotkeys" rule must not count the map itself as a blocking page, or map-only keys (Home / recenter) can never fire.
- A key must not mean two things in one state (X = demolish and X = ability during a battle).

## Testing input from an agent

- `simulate_mouse_input` takes GUI coordinates **plus the 58 px inset** to hit a GuiButton. Get targets from `AbsolutePosition + AbsoluteSize / 2` in a client eval, not from screenshot pixels (screenshots are 2x).
- To check an offset, arm `InputBegan` to record `input.Position`, fire one click, compare.
- `MouseEnter`/`MouseLeave` never fire from synthetic input; test hover by calling the handler.
- Real right-mouse or WASD events during an agent's playtest mean the developer is playing. Stop driving.

## Checklist

- World clicks go through a claim API; modal modes sink their keys and clicks.
- Rays from `input.Position` use `ScreenPointToRay`; from `GetMouseLocation` use `ViewportPointToRay`.
- Touch confirms use the tap point.
- Pinch applied as a delta; drags keyed on their InputObject.
- Watch breaks only on movement/camera input.
- Overview modes disable character controls.

Previous: [[Performance]] · Next: [[Open Cloud creating developer products from a script]]
