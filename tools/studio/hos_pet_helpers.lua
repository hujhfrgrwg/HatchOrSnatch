-- Pet install helpers for Studio (_G.HOS_PetHooks, _G.HOS_CheckPet, _G.HOS_FullInstall), from the Legendaries handoff.
-- Run hos_stage.lua first (HOS_InstallPet / HOS_ApplyPBR), then this file, in execute_luau after a Studio restart.

_G.HOS_PetHooks=function(o)
 local SES=game:GetService("ScriptEditorService")
 local S=game.ReplicatedStorage.EOS.Shared
 local C=game.StarterPlayer.StarterPlayerScripts.EOS.Controllers
 local out={}
 local function upd(scr,fn,label)
  local src=scr.Source
  if src:find(o.species,1,true) and label~="cos" and label~="econ2" and label~="econ1" then
   -- already present in this script for this purpose?
  end
  local new,why=fn(src)
  if not new then table.insert(out,scr.Name.." "..label..": "..tostring(why)) return end
  SES:UpdateSourceAsync(scr,function() return new end) table.insert(out,scr.Name.." "..label..": ok")
 end
 local function lineEnd(src,startPat,closePat,insert)
  local i=src:find(startPat,1,true) if not i then return nil,"no start" end
  local j,k=src:find(closePat,i,true) if not j then return nil,"no close" end
  return src:sub(1,j-1)..insert..src:sub(j)
 end
 local q='["'..o.species..'"]'
 upd(S.PetModel,function(s) if s:find(q..' = true',1,true) then return nil,"already" end return lineEnd(s,"PetModel.RIGGED =",' } :: { [string]: boolean }',', '..q..' = true') end,"rigged")
 upd(S.PetRig,function(s) if s:find('"'..o.anims..'"',1,true) then return nil,"already" end return lineEnd(s,"PetRig.MODULES = {","} :: { [string]: string }",'\t'..q..' = "'..o.anims..'", -- '..o.note..'\n') end,"rig")
 upd(C.PetBehaviors,function(s) if s:find('"'..o.ctl..'"',1,true) then return nil,"already" end return lineEnd(s,"MODULES = {","} :: { [string]: string }",'\t'..q..' = "'..o.ctl..'", -- '..o.note..'\n') end,"behav")
 if o.family then upd(S.EconomyConfig,function(s) if s:find(q..' = "'..o.family..'"',1,true) then return nil,"already" end return lineEnd(s,"EconomyConfig.EXTRA_SPECIES =",' } :: { [string]: string }',', '..q..' = "'..o.family..'"') end,"econ1") end
 upd(S.EconomyConfig,function(s) if s:find(q..' = "'..o.rarity..'"',1,true) then return nil,"already" end return lineEnd(s,"EconomyConfig.SPECIES_RARITY =",' } :: { [string]: string }',', '..q..' = "'..o.rarity..'"') end,"econ2")
 if o.vfx then
  local t={} for k,v in pairs(o.vfx) do table.insert(t,'\t\t\t'..k..' = "'..v..'",') end table.sort(t)
  local block='\t-- '..o.note..'\n\t'..q..' = {\n\t\tvfx = {\n'..table.concat(t,'\n')..'\n\t\t},\n\t},\n'
  upd(S.AbilityCosmetics,function(s) if s:find(q..' = {',1,true) then return nil,"already" end return lineEnd(s,"AbilityCosmetics.SPECIES = {","} :: { [string]: { [string]: any } }",block) end,"cos")
 end
 return table.concat(out,"\n")
end

_G.HOS_CheckPet=function(species)
 local S=game.ReplicatedStorage.EOS.Shared
 local out={}
 for _,s in ipairs({S.PetModel,S.PetRig,S.EconomyConfig,S.AbilityCosmetics,game.StarterPlayer.StarterPlayerScripts.EOS.Controllers.PetBehaviors}) do
  local c=s:Clone() c.Name=s.Name.."_chk" c.Parent=s.Parent
  local ok,e=pcall(require,c) table.insert(out,s.Name..(ok and " ok" or (" ERR "..tostring(e))))
  if ok and s.Name=="PetModel" then
   for lv=1,3 do local ok2,m=pcall(e.build,species,1,lv) if ok2 then local n=0 for _,p in ipairs(m:GetChildren()) do if p:IsA("MeshPart") then n+=1 end end table.insert(out,"L"..lv.." meshes "..n) m:Destroy() else table.insert(out,"L"..lv.." ERR "..tostring(m)) end end
  end
  if ok and s.Name=="EconomyConfig" then table.insert(out,"family "..tostring(e.familyOfSpecies(species))) end
  c:Destroy()
 end
 return table.concat(out,"; ")
end

_G.HOS_FullInstall=function(o)
 local IS=game:GetService("InsertService") local P=o.prefix local I=o.ids local W=Color3.new(1,1,1)
 local m=_G.HOS_InstallPet({model=I.fbx,species=o.species,prefix=P,baseScale=o.baseScale or 0.75,tris=o.tris,tex={[P.."Body"]=I.c1,[P.."Face"]=I.f1,[P.."L2"]=I.c2,[P.."L3"]=I.c3}})
 _G.HOS_ApplyPBR(m,{[P.."Body"]={color=I.c1,normal=I.n,rough=I.r,emit=I.e1,strength=1.8,tint=W},[P.."L2"]={color=I.c2,normal=I.n,rough=I.r,emit=I.e2,strength=2.6,tint=W},[P.."L3"]={color=I.c3,normal=I.n,rough=I.r,emit=I.e3,strength=3.2,tint=W}})
 for _,p in ipairs(m:GetChildren()) do if p:IsA("MeshPart") then p.RenderFidelity=Enum.RenderFidelity.Precise p.CollisionFidelity=Enum.CollisionFidelity.Box
  local sa=p:FindFirstChildOfClass("SurfaceAppearance") if sa then sa.AlphaMode=(p.Name==P.."Face") and Enum.AlphaMode.Transparency or Enum.AlphaMode.Overlay end end end
 local function img(id) return Content.fromUri(IS:LoadAsset(id):FindFirstChildWhichIsA("Decal",true).Texture) end
 local F=m[P.."Face"]:FindFirstChildOfClass("SurfaceAppearance")
 F.EmissiveMaskContent=img(I.fe1) F.EmissiveStrength=2.6 F.EmissiveTint=W F:SetAttribute("BaseEmissive",2.6)
 local looks=m:FindFirstChild("Looks") or Instance.new("Folder") looks.Name="Looks" looks.Parent=m looks:ClearAllChildren()
 local B=m[P.."Body"].SurfaceAppearance local E2=m[P.."L2"].SurfaceAppearance local E3=m[P.."L3"].SurfaceAppearance
 local function mk(name,src,col,em,str) local sa=src:Clone() sa.Name=name if col then sa.ColorMapContent=col end if em then sa.EmissiveMaskContent=em end sa.EmissiveStrength=str sa:SetAttribute("BaseEmissive",str) sa.Parent=looks end
 mk("Body1",B,nil,nil,1.8) mk("Face1",F,nil,nil,2.6)
 mk("Body2",B,E2.ColorMapContent,E2.EmissiveMaskContent,2.3) mk("Face2",F,img(I.f2),img(I.fe2),3.1) mk("Extra2",E2,nil,nil,2.6)
 mk("Body3",B,E3.ColorMapContent,E3.EmissiveMaskContent,2.8) mk("Face3",F,img(I.f3),img(I.fe3),3.6) mk("Extra3",E3,nil,nil,3.2)
 local n=0 for _,d in ipairs(m:GetDescendants()) do if d:IsA("Bone") then n+=1 end end m:SetAttribute("Bones",n)
 return n.." bones, looks "..#looks:GetChildren()
end

return "pet helpers ready"
