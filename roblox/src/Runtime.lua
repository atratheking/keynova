local Runtime = {}
Runtime.__index = Runtime
local Http = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local function uid() return Http:GenerateGUID(false) end

function Runtime.path(object)
 local result = {}
 while object and object ~= game do
  local parent = object.Parent
  if not parent then return nil end
  local ordinal = 0
  for _,sibling in ipairs(parent:GetChildren()) do
   if sibling.Name == object.Name and sibling.ClassName == object.ClassName then ordinal=ordinal+1 end
   if sibling == object then break end
  end
  table.insert(result,1,{name=object.Name,class=object.ClassName,index=ordinal})
  object=parent
 end
 return result
end
function Runtime.resolve(path)
 if type(path)~="table" then return nil end
 local object=game
 for _,segment in ipairs(path)do
  if type(segment)~="table"or type(segment.name)~="string"or type(segment.class)~="string"or type(segment.index or 1)~="number"then return nil end
  local matches={}
  for _,child in ipairs(object:GetChildren()) do if child.Name==segment.name and child.ClassName==segment.class then table.insert(matches,child) end end
  object=matches[segment.index or 1]
  if not object then return nil end
 end
 return object
end
function Runtime.resolveName(path)
 if type(path)~="string" or path=="" then return nil end
 local object=game
 for name in string.gmatch(path,"[^%.]+") do
  local found=nil
  for _,child in ipairs(object:GetChildren()) do
   if child.Name==name then if found then return nil end;found=child end
  end
  if not found then return nil end
  object=found
 end
 return object
end
function Runtime.new()
 return setmetatable({bindings={},objects={},originals={},connections={},onionFolder=nil,attachments={},referenceMap={},errors={},actionSounds={},restMap={}},Runtime)
end
function Runtime:remember(instance,property)
 self.originals[instance]=self.originals[instance]or {}
 if self.originals[instance][property]==nil then self.originals[instance][property]=Properties.capture(instance,property)end
 local original=self.originals[instance][property]
 if type(original)=="table"and original.__keynovaSnapshot then return Properties.read(instance,property)end
 return original
end
function Runtime:restore()
 self:stopActions()
 for instance,properties in pairs(self.originals)do
  if instance.Parent then for property,value in pairs(properties)do pcall(Properties.restore,instance,property,value)end end
 end
 self.attachments={}
end
function Runtime:clearOnion()
 self.onionSnapshot=nil;self.onionFrame=nil
 if self.onionFolder then self.onionFolder:Destroy();self.onionFolder=nil end
end
function Runtime:destroy()
 self:restore();self:clearOnion()
 for _,connection in ipairs(self.connections) do connection:Disconnect() end
 self.connections={};self.bindings={};self.objects={};self.originals={};self.referenceMap={};self.errors={};self.actionSounds={};self.restMap={}
end
function Runtime:addRig(project,model)
 if not model or not model:IsA("Model")then return nil,"Select a rig Model in Explorer."end
 for _,item in ipairs(project.items)do if self.objects[item.id]==model then return nil,"This rig is already in the file."end end
 local joints,byTarget={},{}
 for _,joint in ipairs(model:GetDescendants())do
  if joint:IsA("Bone")or(joint:IsA("Motor6D")and joint.Part0 and joint.Part1)then
   local target=joint:IsA("Bone")and joint or joint.Part1
   if byTarget[target]then return nil,"This rig has multiple animation joints for "..target.Name end
   byTarget[target]=joint;table.insert(joints,joint)
  end
 end
 if #joints==0 then return nil,"This Model has no connected Motor6D joints or Bones."end
 local posePaths,parentJoints={},{}
 local function posePath(joint,visiting)
  if posePaths[joint]then return posePaths[joint]end
  if visiting[joint]then error("The rig joint hierarchy contains a cycle.",0)end;visiting[joint]=true
  local bone=joint:IsA("Bone");local target=bone and joint or joint.Part1;local parent=bone and joint.Parent or joint.Part0
  local owner=byTarget[parent];parentJoints[joint]=owner
  local prefix=owner and posePath(owner,visiting)or parent.Name
  visiting[joint]=nil;posePaths[joint]=prefix.."/"..target.Name;return posePaths[joint]
 end
 local ok,reason=pcall(function()local taken={};for _,joint in ipairs(joints)do local path=posePath(joint,{});assert(not taken[path],"The rig has an ambiguous animation hierarchy: "..path);taken[path]=true end end)
 if not ok then return nil,tostring(reason)end
 local item={id=uid(),name=model.Name,type="Rig",path=Runtime.path(model),expanded=true,rigExpanded=true}
 table.insert(project.items,item);self.objects[item.id]=model
 local tracksByJoint={}
 for _,joint in ipairs(joints)do
  local bone=joint:IsA("Bone");local target=bone and joint or joint.Part1;local property=bone and"Transform"or"C0"
  local track=Engine.newTrack(item.id,target.Name,"Transform","CFrame")
  track.jointType=bone and"Bone"or"Motor6D";track.targetPath=Runtime.path(joint);track.poseName=target.Name;track.posePath=posePaths[joint];track.parentPart=(bone and joint.Parent or joint.Part0).Name
  track.depth=0;for _ in string.gmatch(track.posePath,"/")do track.depth=track.depth+1 end;track.depth=math.max(0,track.depth-1)
  track.rest=Engine.encode(self:remember(joint,property),"CFrame");track.expanded=true
  table.insert(project.tracks,track);tracksByJoint[joint]=track
  self.bindings[track.id]={instance=joint,property=property,base=Engine.decode(track.rest,"CFrame"),references=self.referenceMap}
 end
 for joint,track in pairs(tracksByJoint)do local parent=tracksByJoint[parentJoints[joint]];track.parentTrackId=parent and parent.id end
 for _,face in ipairs(model:GetDescendants())do if face:IsA("FaceControls")then
  local properties=Properties.list(face);local child=self:addObject(project,face,properties)
  if child then child.rigItemId=item.id
   local parent=face.Parent;local parentJoint=byTarget[parent];local prefix=parentJoint and posePaths[parentJoint]or(parent and parent.Name or"Head")
   for _,track in ipairs(project.tracks)do if track.itemId==child.id then track.rigItemId=item.id;track.facePart=parent and parent.Name or"Head";track.posePath=prefix.."/FaceControls/"..track.property end end
  end
 end end
 return item
end
function Runtime.properties(object)return Properties.list(object)end
function Runtime.actions(object)return Properties.actions(object)end
function Runtime:addObject(project,object,properties,events)
 if not object then return nil,"Select an instance in Explorer." end
 for _,item in ipairs(project.items) do if self.objects[item.id]==object then return nil,"This object is already in the file. Use Edit Item to change tracks." end end
 local kind=object:IsA("Camera") and "Camera" or object:IsA("Model") and "Model" or object:IsA("BasePart") and "Part" or object.ClassName
 local item={id=uid(),name=object.Name,type=kind,path=Runtime.path(object),expanded=true,propertiesExpanded=true}
 self.objects[item.id]=object;table.insert(project.items,item)
 for _,property in ipairs(properties or {}) do self:addProperty(project,item,property) end
 if events then self:addProperty(project,item,"Event")end
 return item
end
function Runtime:addProperty(project,item,property)
 for _,track in ipairs(project.tracks) do if track.itemId==item.id and track.property==property then return track end end
 local object=self.objects[item.id]
 if not object then return nil end
 local virtual=property=="Event"or(property=="Action"and #Properties.actions(object)>0)or(object:IsA("Camera")and(property=="AttachToPart"or property=="LookAtPart"))
 if not virtual and not table.find(Properties.list(object),property)then return nil end
 local value,actual
 if property=="AttachToPart"or property=="LookAtPart"or property=="Event"or property=="Action"then value="";actual=property
 elseif property=="CFrame" and object:IsA("Model") then actual="Pivot";value=self:remember(object,actual)
 elseif property=="Scale" then actual="Scale";value=self:remember(object,actual)
 else actual=property;local ok;ok,value=pcall(function()return self:remember(object,actual)end);if not ok then return nil end end
 local valueType=Properties.kind(value);if not valueType then return nil end
 local track=Engine.newTrack(item.id,property=="Event"and"Events"or property=="Action"and"Actions"or property,property,valueType)
 if typeof(value)=="EnumItem"then track.enumType=string.gsub(tostring(value.EnumType),"^Enum%.","")end
 table.insert(project.tracks,track)
 local virtual=property=="AttachToPart"or property=="LookAtPart"or property=="Event"or property=="Action"
 local base=virtual and""or self:remember(object,actual)
 self.bindings[track.id]={instance=object,property=actual,base=base,references=self.referenceMap}
 if not virtual then track.rest=Engine.encode(typeof(base)=="EnumItem"and base.Name or base,valueType)end
 if object:IsA("Camera") then self:remember(object,"CameraType");self:remember(object,"CFrame");self:remember(object,"FieldOfView") end
 return track
end
function Runtime:load(project,references)
 self:restore();self:clearOnion();self.bindings={};self.objects={};self.originals={};self.referenceMap={};self.restMap={};local missing={}
 if references then for _,ref in ipairs(references:GetChildren())do if ref:IsA("ObjectValue")and string.sub(ref.Name,1,4)=="Key_"and ref.Value then self.referenceMap[string.sub(ref.Name,5)]=ref.Value end end end
 for _,item in ipairs(project.items) do
  local ref=references and references:FindFirstChild(item.id)
  local object=ref and ref:IsA("ObjectValue") and ref.Value or Runtime.resolve(item.path)
  if object then self.objects[item.id]=object else table.insert(missing,item.name) end
 end
 for _,track in ipairs(project.tracks) do
  local object=self.objects[track.itemId]
  if object then
   if track.property=="Transform"then
    local direct=references and references:FindFirstChild("Track_"..track.id)
    local found=direct and direct:IsA("ObjectValue")and direct.Value or Runtime.resolve(track.targetPath)
    if not found then for _,joint in ipairs(object:GetDescendants())do
     if(joint:IsA("Bone")and joint.Name==track.name)or(joint:IsA("Motor6D")and joint.Part1 and joint.Part1.Name==track.name)then if found then found=nil;break end;found=joint end
    end end
    if found and(found:IsA("Bone")or found:IsA("Motor6D"))then
     local property=found:IsA("Bone")and"Transform"or"C0";local base=self:remember(found,property)
     if track.rest then base=Engine.decode(track.rest,"CFrame");self.originals[found][property]=base end
     self.bindings[track.id]={instance=found,property=property,base=base,references=self.referenceMap}
    else table.insert(missing,track.name)end
   elseif track.property=="Event"or track.property=="Action"or track.property=="AttachToPart"or track.property=="LookAtPart"then self.bindings[track.id]={instance=object,property=track.property,base="",references=self.referenceMap}
   elseif table.find(Properties.list(object),track.property)then
    local actual=track.property=="CFrame"and object:IsA("Model")and"Pivot"or track.property
    local ok,base=pcall(function()return self:remember(object,actual)end)
    if ok then
     local snapshot=self.originals[object][actual]
     if type(snapshot)=="table"and snapshot.__keynovaSnapshot and track.restTargets then
      local byTarget={};for _,entry in ipairs(snapshot.values)do byTarget[entry.target]=entry end
      self.restMap[track.id]={}
      for i,saved in ipairs(track.restTargets)do
       local ref=references and references:FindFirstChild("Rest_"..track.id.."_"..i)
       local target=ref and ref:IsA("ObjectValue")and ref.Value or Runtime.resolve(saved.path)
       if target and target:IsDescendantOf(object)then
        local good,value=pcall(Engine.decode,saved.value,track.valueType)
        if good then if byTarget[target]then byTarget[target].value=value else table.insert(snapshot.values,{target=target,value=value})end;self.restMap[track.id][i]=target end
       end
      end
      if track.rest then base=Engine.decode(track.rest,track.valueType)end
     end
     if track.rest and not(type(self.originals[object][actual])=="table"and self.originals[object][actual].__keynovaSnapshot)then
      local saved=Engine.decode(track.rest,track.valueType)
      if typeof(base)=="EnumItem"and type(saved)=="string"then saved=base.EnumType[saved]end
      if saved~=nil then base=saved;self.originals[object][actual]=saved end
     end
     self.bindings[track.id]={instance=object,property=actual,base=base,references=self.referenceMap}
    else table.insert(missing,track.name)end
   else table.insert(missing,track.name)end
   if object:IsA("Camera") then self:remember(object,"CameraType");self:remember(object,"CFrame");self:remember(object,"FieldOfView") end
  end
 end
 for _,track in ipairs(project.tracks)do if track.property=="AttachToPart"or track.property=="LookAtPart"then
  for _,key in ipairs(track.keys)do local target=self.referenceMap[key.id]or Runtime.resolve(key.targetPath)or Runtime.resolveName(key.value)
   if target then self.referenceMap[key.id]=target
    if track.property=="AttachToPart"and not key.referenceOffset then self:setReference(track,key,target)end
   end
  end
 end end
 return missing
end
function Runtime:setReference(track,key,target)
 assert(target and target:IsA("BasePart"),"Choose a BasePart target")
 self.referenceMap[key.id]=target;key.targetPath=Runtime.path(target);key.value=target:GetFullName()
 local binding=self.bindings[track.id];if binding then binding.references=self.referenceMap
  if track.property=="AttachToPart"then
   local camera=binding.instance;local cf=camera.CFrame
   key.referenceCamera=Engine.encode(cf,"CFrame");key.referenceOffset=Engine.encode(target.CFrame:ToObjectSpace(cf),"CFrame")
  end
 end
end
function Runtime:refreshReferences(project)
 for _,track in ipairs(project.tracks)do for _,key in ipairs(track.keys)do local target=self.referenceMap[key.id];if target and target.Parent then key.targetPath=Runtime.path(target);key.value=target:GetFullName()end end end
 for _,item in ipairs(project.items)do local object=self.objects[item.id];if object and object.Parent then item.path=Runtime.path(object)end end
 for _,track in ipairs(project.tracks)do local binding=self.bindings[track.id]
  if binding then
   if track.property=="Transform"then track.targetPath=Runtime.path(binding.instance)end
   local snapshot=self.originals[binding.instance]and self.originals[binding.instance][binding.property]
   if type(snapshot)=="table"and snapshot.__keynovaSnapshot then
    track.restTargets={};self.restMap[track.id]={}
    for _,entry in ipairs(snapshot.values)do if entry.target.Parent then
     table.insert(track.restTargets,{path=Runtime.path(entry.target),value=Engine.encode(entry.value,track.valueType)});self.restMap[track.id][#track.restTargets]=entry.target
    end end
   end
  end
 end
end
function Runtime:read(track)
 local binding=self.bindings[track.id]
 if not binding or not binding.instance.Parent then return nil end
 local object=binding.instance
 if track.property=="Transform" then return binding.base:ToObjectSpace(object[binding.property]) end
 if track.property=="Event"then return "Event"end
 if track.property=="Action"then return Properties.actions(object)[1]or""end
 if track.property=="AttachToPart" or track.property=="LookAtPart" then local selected=Selection:Get()[1];return selected and selected:GetFullName() or "" end
 if binding.property=="Pivot" then return object:GetPivot() end
 if binding.property=="Scale" then return object:GetScale() end
 local value=Properties.read(object,binding.property)
 return typeof(value)=="EnumItem" and value.Name or value
end
function Runtime:apply(project,frame)
 if RunService:IsRunning() then return end
 local cameras={};local cameraKeys={};self.errors={}
 for _,track in ipairs(project.tracks) do
  local binding=self.bindings[track.id]
  if binding and binding.instance.Parent and track.property~="Event"and track.property~="Action"then
   local object=binding.instance
   local value=nil
   if track.enabled~=false then value=Engine.sample(track,frame)end
   if object:IsA("Camera")then
    cameras[object]=cameras[object]or {};cameras[object][track.property]=value
    if(track.property=="AttachToPart"or track.property=="LookAtPart")and value~=nil then
     local active=Engine.activeKey(track,frame)
     cameraKeys[object]=cameraKeys[object]or {};cameraKeys[object][track.property]=active
    end
   else
    -- An empty or disabled track relinquishes its last preview value.
    if value==nil then
     local original=self.originals[object]and self.originals[object][binding.property]
     if type(original)=="table"and original.__keynovaSnapshot then Properties.restore(object,binding.property,original)
     else value=track.property=="Transform"and CFrame.new()or binding.base end
    end
    if value~=nil then local ok,reason=pcall(function()
     if track.property=="Transform"then object[binding.property]=binding.base*value
     elseif binding.property=="Pivot" then object:PivotTo(value)
     elseif binding.property=="Scale" then object:ScaleTo(math.max(0.001,value))
     else Properties.write(object,binding.property,value,track)end
    end);if not ok then table.insert(self.errors,{trackId=track.id,message=tostring(reason)})end end
   end
  end
 end
 for camera,values in pairs(cameras) do
  local original=self.originals[camera]or {}
  local cf=values.CFrame or original.CFrame or camera.CFrame
  local keys=cameraKeys[camera]or {};local attachKey=keys.AttachToPart
  local attach=attachKey and(self.referenceMap[attachKey.id]or Runtime.resolve(attachKey.targetPath)or Runtime.resolveName(attachKey.value))
  if attach and attach:IsA("BasePart")then
   self.referenceMap[attachKey.id]=attach
   if not attachKey.referenceOffset then
    local targetOriginal=self.originals[attach]and self.originals[attach].CFrame or attach.CFrame
    local reference=original.CFrame or cf
    attachKey.referenceCamera=Engine.encode(reference,"CFrame");attachKey.referenceOffset=Engine.encode(targetOriginal:ToObjectSpace(reference),"CFrame")
   end
   local reference=Engine.decode(attachKey.referenceCamera,"CFrame")
   cf=attach.CFrame*Engine.decode(attachKey.referenceOffset,"CFrame")*reference:ToObjectSpace(values.CFrame or reference)
  end
  local lookKey=keys.LookAtPart
  local look=lookKey and(self.referenceMap[lookKey.id]or Runtime.resolve(lookKey.targetPath)or Runtime.resolveName(lookKey.value))
  if look and look:IsA("BasePart")and(look.Position-cf.Position).Magnitude>0.001 then cf=CFrame.lookAt(cf.Position,look.Position)end
  local active=next(values)~=nil
  camera.CameraType=active and Enum.CameraType.Scriptable or original.CameraType or camera.CameraType
  camera.CFrame=cf;camera.FieldOfView=math.clamp(values.FieldOfView or original.FieldOfView or camera.FieldOfView,1,120)
 end
end
function Runtime:onion(project,at,current)
 self:clearOnion();self:apply(project,at)
 self.onionSnapshot={};self.onionFrame=at
 for _,track in ipairs(project.tracks)do if track.property~="Event"and track.property~="Action"then local value=Engine.sample(track,at);if value==nil then value=self:read(track)end;if value~=nil then self.onionSnapshot[track.id]=value end end end
 local folder=Instance.new("Folder");folder.Name="KeynovaOnionSkin";self.onionFolder=folder
 for _,item in ipairs(project.items) do
  local object=self.objects[item.id]
  if object and (object:IsA("Model") or object:IsA("BasePart")) and object.Archivable then
   local clone=object:Clone()
   for _,desc in ipairs(clone:GetDescendants()) do
    if desc:IsA("LuaSourceContainer") or desc:IsA("Humanoid") or desc:IsA("Animator") or desc:IsA("JointInstance") or desc:IsA("Constraint") then desc:Destroy()
    elseif desc:IsA("BasePart") then desc.Anchored=true;desc.CanCollide=false;desc.CanTouch=false;desc.CanQuery=false;desc.Transparency=math.max(desc.Transparency,0.72);desc.Color=Color3.fromRGB(100,185,215) end
   end
   if clone:IsA("BasePart") then clone.Anchored=true;clone.CanCollide=false;clone.CanTouch=false;clone.CanQuery=false;clone.Transparency=0.72;clone.Color=Color3.fromRGB(100,185,215) end
   clone.Parent=folder
  end
 end
 folder.Parent=workspace;self:apply(project,current)
end
function Runtime:applyOnion(project,frame,itemId)
 if not self.onionSnapshot then return nil,"Create an onion skin first."end
 local selection={}
 for _,track in ipairs(project.tracks)do
  local value=self.onionSnapshot[track.id]
  if value~=nil and not track.locked and(not itemId or track.itemId==itemId)then
   local locked=false;for _,existing in ipairs(track.keys)do if existing.frame==frame and existing.locked then locked=true end end
   if not locked then local key=Engine.insert(track,frame,value);table.insert(selection,{trackId=track.id,keyId=key.id})end
  end
 end
 self:apply(project,frame);return selection
end
function Runtime:action(target,method,arguments)
 if Properties.isAudio(target)and not self.actionSounds[target]then self.actionSounds[target]=Properties.captureAudio(target)end
 return Properties.action(target,method,arguments)
end
function Runtime:stopActions()
 for sound,original in pairs(self.actionSounds or{})do
  if not sound.Parent then self.actionSounds[sound]=nil
  else local ok,reason=pcall(Properties.restoreAudio,sound,original);if ok then self.actionSounds[sound]=nil else table.insert(self.errors,{message=tostring(reason)})end end
 end
end
function Runtime:pauseActions()
 for sound,original in pairs(self.actionSounds or{})do if sound.Parent and sound.IsPlaying then Properties.pauseAudio(sound);original.paused=true end end
end
function Runtime:resumeActions()
 for sound,original in pairs(self.actionSounds or{})do if sound.Parent and original.paused then Properties.resumeAudio(sound);original.paused=nil end end
end
function Runtime:crossings(project,first,last,includeFirst,callback)
 if callback then for _,marker in ipairs(project.markers)do if marker.frame<=last and(marker.frame>first or(includeFirst and marker.frame==first))then callback("Marker",nil,{value=marker.name,eventValue=marker.value,frame=marker.frame},nil)end end end
 for _,track in ipairs(project.tracks)do if track.enabled~=false and(track.property=="Event"or track.property=="Action")then
  local binding=self.bindings[track.id];local target=binding and binding.instance
  for _,key in ipairs(track.keys)do
   if key.frame<=last and(key.frame>first or(includeFirst and key.frame==first))then
    if track.property=="Action"and target and target.Parent then
     local ok,reason=pcall(self.action,self,target,key.value,key.arguments);if not ok and callback then callback("Error",track,key,target,tostring(reason))end
    elseif callback then callback("Begin",track,key,target)end
   end
   if track.property=="Event"and(key.duration or 0)>0 then
    local finish=key.frame+key.duration
    if finish<=last and(finish>first or(includeFirst and finish==first))and callback then callback("End",track,key,target)end
   end
  end
 end end
end

function Runtime:createRig(kind,username)
 local Players=game:GetService("Players")
 local description=Instance.new("HumanoidDescription")
 if username and username~="" then
  local id=tonumber(username) or Players:GetUserIdFromNameAsync(username)
  description=Players:GetHumanoidDescriptionFromUserIdAsync(id)
 end
 local model=Players:CreateHumanoidModelFromDescriptionAsync(description,kind=="R15" and Enum.HumanoidRigType.R15 or Enum.HumanoidRigType.R6)
 model.Name=(username and username~="") and username or "Rig"
 local camera=workspace.CurrentCamera
 model:PivotTo(CFrame.new(camera.CFrame.Position+camera.CFrame.LookVector*12))
 model.Parent=workspace
 local root=model:FindFirstChild("HumanoidRootPart");if root then root.Anchored=true end
 Selection:Set({model});return model
end
function Runtime:weld(inPlace,kind)
 local objects=Selection:Get();kind=kind or"Weld"
 if kind~="Weld"and kind~="Motor6D"then return false,"Choose Weld or Motor6D."end
 local first=objects[1]
 local function primary(object)
  if object and object:IsA("BasePart")then return object end
  if object and object:IsA("Model")then return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart",true)end
 end
 local base=primary(first);if not base then return false,"Select a base part or Model first."end
 local parts,seen={},{}
 local function collect(object)
  if object:IsA("BasePart")then if object~=base and not seen[object]then seen[object]=true;table.insert(parts,object)end
  elseif object:IsA("Model")then for _,child in ipairs(object:GetDescendants())do if child:IsA("BasePart")then collect(child)end end end
 end
 if #objects==1 and first:IsA("Model")then collect(first)else for i=2,#objects do collect(objects[i])end end
 if #parts==0 then return false,"Select parts or a Model containing parts to join."end
 if #parts>Engine.operationCapacity then return false,"Weld exceeds the instance operation budget."end
 if kind=="Motor6D"then
  for _,part in ipairs(parts)do for _,joint in ipairs(part:GetJoints())do if joint:IsA("Motor6D")and joint.Part1==part then return false,"A selected part already has an animation joint: "..part.Name end end end
 end
 local changes={};local joints={};local models={}
 for _,part in ipairs(parts)do table.insert(changes,{part=part,cframe=part.CFrame,anchored=part.Anchored})end
 local ok,reason=pcall(function()
  if not inPlace and #objects>1 then
   for i=2,#objects do local object=objects[i]
    if object:IsA("Model")then models[object]=object:GetPivot();object:PivotTo(base.CFrame)
    elseif object:IsA("BasePart")and object~=base then object.CFrame=base.CFrame end
   end
  end
  for _,part in ipairs(parts)do
   local joint=Instance.new(kind);table.insert(joints,joint)
   joint.Name=kind=="Motor6D"and"KeynovaJoint"or"KeynovaWeld";joint.Part0=base;joint.Part1=part
   joint.C0=base.CFrame:ToObjectSpace(part.CFrame);joint.C1=CFrame.new();joint.Parent=base;part.Anchored=false
  end
 end)
 if not ok then
  for _,joint in ipairs(joints)do joint:Destroy()end
  for model,pivot in pairs(models)do if model.Parent then model:PivotTo(pivot)end end
  for _,entry in ipairs(changes)do if entry.part.Parent then entry.part.CFrame=entry.cframe;entry.part.Anchored=entry.anchored end end
  return false,tostring(reason)
 end
 return true,"Joined "..#parts.." part(s) with "..kind.."."
end
return Runtime
