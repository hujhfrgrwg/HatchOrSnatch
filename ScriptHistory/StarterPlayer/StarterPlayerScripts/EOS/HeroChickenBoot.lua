-- HOS-HOC-001: boots the Hero or Chicken client (kept out of ClientMain so other threads' edits there don't collide)
require(script.Parent:WaitForChild("Controllers"):WaitForChild("HeroChicken")).init()
