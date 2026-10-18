# LobbyBillboards: spin wheel sign anchor (HOS-SPIN-001 fix, 18 Oct 2026)

`StarterPlayerScripts.EOS.Controllers.LobbyBillboards` is not in this repo. The full pre-edit copy is in Studio at `ServerStorage._Backups.HOS-SPIN-001_2026-10-18.LobbyBillboards_beforeSignFix`. This is the only change, in `makeSpin()`.

Before:
```lua
		local anchor = wheel:FindFirstChildWhichIsA("BasePart", true)
		if not anchor then
			return
		end
		local cf, size = wheel:GetBoundingBox()
		-- above the wheel's frame (its crystal sits over the wheel's top), where the old sign was
		local frame = sw:FindFirstChild("Frame")
```

After:
```lua
		local cf, size = wheel:GetBoundingBox()
		-- above the wheel's frame (its crystal sits over the wheel's top), where the old sign was
		local frame = sw:FindFirstChild("Frame")
		-- adorned to a part that never moves (HOS-SPIN-001 fix, Matthew 18 Oct: "be above the wheel not in the ground"): the
		-- Wheel model turns whenever anyone spins, so a wheel part carried the sign round with it, down to the base
		local anchor = sw:FindFirstChild("SpinSign") or (frame and frame:FindFirstChildWhichIsA("BasePart", true))
		if not (anchor and anchor:IsA("BasePart")) then
			return
		end
```
