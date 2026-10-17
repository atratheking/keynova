-- Real StringValue storage limits, chunk ownership and failure atomicity.
local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local holder=Instance.new("Folder");holder.Name="SaveParity";holder.Parent=game:GetService("ServerStorage")
local entry=Instance.new("StringValue");entry.Parent=holder
local project=Engine.newProject("Small save")
local refs=Instance.new("Folder");local target=Instance.new("ObjectValue");target.Name="Target";target.Value=workspace;target.Parent=refs
local saved,reason=Saves.write(entry,project,refs);check(saved,reason or"Native save writes")
local read,references=Saves.read(entry)
check(read.name==project.name and references.Target.Value==workspace,"Stored references retain exact native targets")
local note=Instance.new("Folder");note.Name="User Notes";note.Parent=entry
local previousFolders={};for _,child in ipairs(entry:GetChildren())do if child:GetAttribute("KeynovaSaveOwner")then table.insert(previousFolders,child)end end
project.note=string.rep("日本語🙂",50000)
local encoded=game:GetService("HttpService"):JSONEncode(project)
check(not pcall(function()local raw=Instance.new("StringValue");raw.Value=encoded;raw:Destroy()end),"Native StringValue rejects this unchunked payload")
local success,errorMessage=Saves.write(entry,project,Instance.new("Folder"));check(success,errorMessage or"Large Unicode save writes")
local header=game:GetService("HttpService"):JSONDecode(entry.Value)
check(header.parts>1 and #entry.Value<200000,"Large payload uses small versioned manifest")
local loaded=Saves.read(entry);check(loaded.note==project.note,"Unicode crossing chunk boundaries round-trips exactly")
check(note.Parent==entry,"Saving preserves unrelated attached data")
check(previousFolders[1].Parent==nil and previousFolders[2].Parent==nil,"Re-save removes only old owned chunk and reference folders")
local data=entry:FindFirstChild(header.data);local first=data:FindFirstChild("000001");first.Parent=nil;first.Parent=data
check(Saves.read(entry)~=nil,"Chunk order comes from explicit indexes rather than child insertion order")
local original=first.Value;first.Value="x"..string.sub(original,2)
local corrupt,corruptError=Saves.read(entry);check(not corrupt and string.find(corruptError,"checksum"),"Same-length chunk corruption is detected")
first.Value=original
local middle=data:FindFirstChild("000002");middle.Parent=nil
local missing,missingError=Saves.read(entry);check(not missing and string.find(missingError,"incomplete"),"Missing chunk fails closed")
middle.Parent=data
local manifest=entry.Value;local count=#entry:GetChildren();local cyclic={};cyclic.self=cyclic
local failed,writeError=Saves.write(entry,cyclic,Instance.new("Folder"))
check(not failed and type(writeError)=="string"and entry.Value==manifest and #entry:GetChildren()==count,"Encoding failure preserves the previous save atomically")
local limit=Saves.capacity;Saves.capacity=100
local tooLarge=Saves.write(entry,project,Instance.new("Folder"));Saves.capacity=limit
check(not tooLarge and entry.Value==manifest,"Capacity failure preserves the previous save")
header.parts=1000000000;entry.Value=game:GetService("HttpService"):JSONEncode(header)
check(Saves.read(entry)==nil,"Malformed declared part count is rejected before allocation")
entry.Value=manifest;data:SetAttribute("KeynovaSaveOwner","foreign")
check(Saves.read(entry)==nil,"A foreign folder cannot satisfy save ownership")
data:SetAttribute("KeynovaSaveOwner",header.id);entry.Value=game:GetService("HttpService"):JSONEncode(Engine.newProject("Legacy"))
local legacy,legacyRefs=Saves.read(entry);check(legacy.name=="Legacy"and legacyRefs==entry,"Earlier unchunked version2 JSON remains readable")
holder:Destroy()
print("KEYNOVA_SAVES_PARITY_PASS "..checks.." checks")
