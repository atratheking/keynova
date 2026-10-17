-- Independently authored Keynova exporters. Engine is supplied by the plugin bundle.
-- Nothing returned here is parented or published; the caller owns the artifact.
local Export = {}
local ExportHttp = game:GetService("HttpService")
local MAX_FRAMES, MAX_POSES = 9007199254740991, 120000

local function copy(value)
 if type(value) ~= "table" then return value end
 local result = {}
 for key, child in pairs(value) do result[key] = copy(child) end
 return result
end

local function finite(value)
 return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function timing(project)
 local fps, duration = project.fps, project.duration
 assert(finite(fps) and fps > 0, "Export FPS must be a positive finite number.")
 assert(finite(duration) and duration >= 0 and duration % 1 == 0 and duration <= MAX_FRAMES,
  "Export length must be a nonnegative exactly representable whole frame.")
 return fps, duration
end

local function rigTracks(project, item)
 local result = {}
 for _, track in ipairs(project.tracks or {}) do
  if track.itemId == item.id and track.property == "Transform" then table.insert(result, track) end
 end
 return result
end

-- A single pose tree owns both physical binding interpretation and export layout.
-- posePath metadata is preferred; old version-2 Motor tracks remain supported.
local function layout(project, item, bindings)
 local tracks, motors, nodes, roots = rigTracks(project,item), {}, {}, {}
 for _,track in ipairs(tracks) do
  local binding=bindings[track.id]
  local target=binding and binding.instance
  assert(target and (target:IsA("Motor6D") or target:IsA("Bone")),"Rig track is not bound to a Motor6D or Bone: "..tostring(track.name))
  if target:IsA("Motor6D") then
   assert(target.Part0 and target.Part1,"Rig joint is disconnected: "..target.Name)
   assert(not motors[target.Part1],"Two joints animate the same rig part.")
   motors[target.Part1]=target
  end
 end
 local function physicalPath(target,seen)
  seen=seen or {};assert(not seen[target],"Rig hierarchy contains a cycle.");seen[target]=true
  local parent
  if target:IsA("Bone") then parent=target.Parent
  elseif motors[target] then parent=motors[target].Part0 end
  local result={}
  if parent and (parent:IsA("Bone") or parent:IsA("BasePart")) then result=physicalPath(parent,seen) end
  table.insert(result,target.Name);seen[target]=nil;return result
 end
 local function addPath(parts)
  local path,parent="",nil
  for _,name in ipairs(parts) do
   assert(name~="","Rig pose name is empty.")
   path=path=="" and name or path.."/"..name
   local current=nodes[path]
   if not current then
    current={name=name,path=path,children={},faces={}};nodes[path]=current
    if parent then table.insert(parent.children,current)else table.insert(roots,current)end
   end
   parent=current
  end
  return parent
 end
 local animated=0
 for _,track in ipairs(tracks) do
  local target=bindings[track.id].instance
  local physical=target:IsA("Motor6D") and target.Part1 or target
  local parts={}
  if type(track.posePath)=="string" and track.posePath~="" then
   for part in string.gmatch(track.posePath,"[^/]+")do table.insert(parts,part)end
  else parts=physicalPath(physical)end
  local current=addPath(parts)
  assert(current and not current.track,"Duplicate rig pose path: "..tostring(track.posePath or track.name))
  assert(not track.poseName or current.name==track.poseName,"Rig pose metadata disagrees with its path.")
  current.track,current.target=track,physical
  if #track.keys>0 and track.enabled~=false then animated=animated+1 end
 end
 -- Facial channels are owned by their actual FaceControls parent in this rig.
 local byTarget={};for _,node in pairs(nodes)do if node.target then byTarget[node.target]=node end end
 for _,track in ipairs(project.tracks or {})do
  local binding=bindings[track.id];local target=binding and binding.instance
  if target and target:IsA("FaceControls") and track.valueType=="number" then
   local parent=byTarget[target.Parent]
   if parent and #track.keys>0 and track.enabled~=false then
    table.insert(parent.faces,track);animated=animated+1
   end
  end
 end
 local count=0
 for _,node in pairs(nodes)do
  count=count+1+#node.faces
  table.sort(node.children,function(a,b)return a.name<b.name end)
  table.sort(node.faces,function(a,b)return a.property<b.property end)
 end
 table.sort(roots,function(a,b)return a.name<b.name end)
 return roots,count,animated
end

local function emitMarker(parent,name,value)
 local marker=Instance.new("KeyframeMarker")
 marker.Name,marker.Value,marker.Parent=tostring(name or "Event"),tostring(value or ""),parent
end

function Export.rig(project, item, bindings)
 local fps,duration=timing(project)
 local roots,count,animated=layout(project,item,bindings)
 assert(animated>0,"Add a rig keyframe before exporting.")
 assert(count*(duration+1)<=MAX_POSES,"Rig export exceeds 120000 poses. Shorten the animation or export fewer joints.")
 local sequence=Instance.new("KeyframeSequence")
 local ok,failure=pcall(function()
  sequence.Name,sequence.Loop=project.name or item.name or "Keynova Animation",project.loop==true
  local priority=project.priority or project.optionalpriority
  if priority then
   local selected=typeof(priority)=="EnumItem" and priority or Enum.AnimationPriority[tostring(priority)]
   assert(selected,"Unknown animation priority.");sequence.Priority=selected
  end
  local function addPose(node,parent,frame)
   local pose=Instance.new("Pose");pose.Name,pose.Weight,pose.CFrame=node.name,1,CFrame.new()
   if node.track and node.track.enabled~=false then pose.CFrame=Engine.sampleRaw(node.track,frame)or CFrame.new();pose.Weight=Engine.sampleWeight(node.track,frame)end
   pose.EasingStyle,pose.EasingDirection=Enum.PoseEasingStyle.Linear,Enum.PoseEasingDirection.InOut
   pose.Parent=parent
   if #node.faces>0 then
    local controls=Instance.new("Folder");controls.Name,controls.Parent="FaceControls",pose
    for _,track in ipairs(node.faces)do
     if track.enabled~=false and #track.keys>0 then
      local channel=Instance.new("NumberPose");channel.Name,channel.Weight=track.property,1
      channel.Value=Engine.sampleRaw(track,frame);channel.Weight=Engine.sampleWeight(track,frame);channel.EasingStyle=Enum.PoseEasingStyle.Linear
      channel.EasingDirection,channel.Parent=Enum.PoseEasingDirection.InOut,controls
     end
    end
   end
   for _,child in ipairs(node.children)do addPose(child,pose,frame)end
  end
  local markers={}
  local function cue(frame,name,value)
   assert(finite(frame),"Invalid marker frame.");frame=math.floor(frame+0.5)
   markers[frame]=markers[frame]or {};table.insert(markers[frame],{name=name,value=value})
  end
  for _,marker in ipairs(project.markers or {})do
   if marker.itemId==nil or marker.itemId==item.id then cue(marker.frame,marker.name,marker.value)end
  end
  for _,track in ipairs(project.tracks or {})do
   if track.itemId==item.id and track.property=="Event" and track.enabled~=false then
    for _,key in ipairs(track.keys)do cue(key.frame,key.value,key.eventValue)end
   end
  end
  for frame=0,duration do
   local key=Instance.new("Keyframe");key.Name,key.Time,key.Parent=tostring(frame),frame/fps,sequence
   for _,root in ipairs(roots)do addPose(root,key,frame)end
   for _,marker in ipairs(markers[frame]or {})do emitMarker(key,marker.name,marker.value)end
  end
 end)
 if not ok then sequence:Destroy();error(failure,0)end
 return sequence
end

function Export.importRig(project, item, sequence, mode, at)
 local ok, failure = pcall(function()
  local fps = timing(project)
  assert(sequence and sequence:IsA("KeyframeSequence"), "Select a KeyframeSequence to import.")
  local replace = mode == "Replace" or mode == "Replace Keyframes" or mode == "replace"
  assert(replace or mode == nil or mode == "Paste" or mode == "Paste Keyframes" or mode == "paste", "Unknown import mode.")
  local offset = replace and 0 or (at or 0)
  assert(finite(offset) and offset >= 0 and offset <= MAX_FRAMES, "Invalid import offset.")
  offset = math.floor(offset + 0.5)
  local tracks, byName, byPath = rigTracks(project, item), {}, {}
  for _,track in ipairs(project.tracks or {})do
   if track.valueType=="number" and track.rigItemId==item.id then table.insert(tracks,track)end
  end
  for _, track in ipairs(tracks) do
   if replace then
    assert(not track.locked, "Unlock rig tracks before replacing their keys.")
    for _, key in ipairs(track.keys) do assert(not key.locked, "Unlock keyframes before replacing them.") end
   end
   local name = track.valueType=="number" and track.property or track.poseName or track.name
   if name then
    byName[name] = byName[name] or {}
    table.insert(byName[name], track)
   end
   if type(track.posePath) == "string" then byPath[track.posePath] = track end
  end
  local entries, markers, last, examined = {}, {}, 0, 0
  local keys = sequence:GetKeyframes()
  table.sort(keys, function(a, b) return a.Time < b.Time end)
  for _, key in ipairs(keys) do
   assert(finite(key.Time) and key.Time >= 0, "Import contains an invalid keyframe time.")
   local frame = math.floor(key.Time * fps + 0.5) + offset
   assert(frame <= MAX_FRAMES, "Import time exceeds exact whole-frame precision.")
   last = math.max(last, frame)
   local function readPose(pose, prefix)
    if pose:IsA("PoseBase")then examined=examined+1 end
    assert(examined <= MAX_POSES, "Import exceeds 120000 poses.")
    local path = prefix == "" and pose.Name or prefix .. "/" .. pose.Name
    local track = byPath[path]
    local named = byName[pose.Name]
    if not track and named then
     assert(#named == 1, "Import has ambiguous joint name '" .. pose.Name .. "'; use a unique rig hierarchy.")
     track = named[1]
    end
    if track and pose:IsA("Pose") and track.valueType=="CFrame" then
     table.insert(entries,{track=track,frame=frame,value=pose.CFrame,style=pose.EasingStyle.Name,direction=pose.EasingDirection.Name,weight=pose.Weight})
    elseif track and pose:IsA("NumberPose") and track.valueType=="number" then
     table.insert(entries,{track=track,frame=frame,value=pose.Value,style=pose.EasingStyle.Name,direction=pose.EasingDirection.Name,weight=pose.Weight})
    end
    for _,child in ipairs(pose:GetChildren())do
     if child:IsA("Pose") or child:IsA("NumberPose") or (child:IsA("Folder") and child.Name=="FaceControls")then readPose(child,path)end
    end
   end
   for _, pose in ipairs(key:GetPoses()) do readPose(pose, "") end
   for _, marker in ipairs(key:GetMarkers()) do
    table.insert(markers, {id = ExportHttp:GenerateGUID(false), frame = frame, name = marker.Name, value = marker.Value, itemId = item.id})
   end
  end
  assert(#entries > 0 or #markers > 0, "No imported poses match this rig's tracks.")
  -- Keep mutations transactional, including failures from Engine.insert.
  local previous, oldMarkers, oldDuration = {}, project.markers, project.duration
  for _, track in ipairs(tracks) do previous[track] = copy(track.keys) end
  local applied, applyFailure = pcall(function()
   if replace then for _, track in ipairs(tracks) do track.keys = {} end end
   for _,entry in ipairs(entries)do
    local style=entry.style=="CubicV2"and"Cubic"or entry.style
    assert(table.find(Engine.easingStyles,style),"Unsupported native Pose easing: "..tostring(entry.style))
    assert(finite(entry.weight)and entry.weight>=0 and entry.weight<=1,"Imported pose has an unsupported weight")
    if not replace then for _,existing in ipairs(entry.track.keys)do assert(existing.frame~=entry.frame,"An existing key occupies an import destination")end end
    local key=Engine.insert(entry.track,entry.frame,entry.value,style,entry.direction)
    key.nativeWeight=entry.weight~=1 and entry.weight or nil;key.nativePoseStyle=entry.style
   end
   local combined = {}
   for _, marker in ipairs(project.markers or {}) do
    if not replace or marker.itemId ~= item.id then table.insert(combined, marker) end
   end
   for _, marker in ipairs(markers) do table.insert(combined, marker) end
   table.sort(combined, function(a, b) return a.frame < b.frame end)
   project.markers, project.duration = combined, math.max(project.duration, last)
  end)
  if not applied then
   for track, saved in pairs(previous) do track.keys = saved end
   project.markers, project.duration = oldMarkers, oldDuration
   error(applyFailure, 0)
  end
 end)
 if not ok then return false, tostring(failure) end
 return true
end

-- The returned ModuleScript has ObjectValue children for concrete scene targets.
-- Runtime API: local player = require(module).new(); player:Play(), :Pause(),
-- :Stop(), :Seek(frame), :Destroy(). Marker.Event yields (name, value, frame,
-- targetOrNil); Event-track keys use their string value as the event name.
-- Stop/Destroy restore properties captured when the player was constructed.
local PLAYER_SOURCE = [==[
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Engine=require(script.Engine)
local Properties=require(script.Properties)
local Data=Http:JSONDecode(__KEYNOVA_DATA__)
local Player={};Player.__index=Player
local function ref(name)
 local child=name and script:FindFirstChild(name)
 return child and child:IsA("ObjectValue") and child.Value or nil
end
local function snapshot(target,property)
 return Properties.capture(target,property)
end
local function restore(target,property,value,track)
 Properties.restore(target,property,value,track)
end
local function captureSound(target)return Properties.captureAudio(target)end
local function restoreSound(target,state)return Properties.restoreAudio(target,state)end
local function action(target,key)
 Properties.action(target,key.value,key.arguments)
end

function Player.new(options)
 options=options or {}
 local self=setmetatable({Frame=0,Speed=1,Looped=Data.loop==true,IsPlaying=false,
  _tracks={},_original={},_cameras={},_attachments={},_sounds={},_ownedSounds={},
  _cues={},_activeEvents={},_includeCurrent=true,_destroyed=false},Player)
 local function addCue(frame,kind,binding,key,phase)
  table.insert(self._cues,{frame=frame,kind=kind,binding=binding,key=key,phase=phase,order=#self._cues+1})
 end
 for _,track in ipairs(Data.tracks or {})do
  if track.enabled~=false and track._targetRef then
   local target=ref(track._targetRef);assert(target,"Missing scene target for "..tostring(track.name))
   local binding={track=track,target=target};table.insert(self._tracks,binding)
   if track.property=="Transform"then
    local property=track._jointProperty
    assert(property=="C0"or property=="Transform","Invalid exported rig property.")
    binding.base=Engine.decode(track._rest,"CFrame")
    table.insert(self._original,{target=target,property=property,value=snapshot(target,property),track=track})
   elseif track.property=="Event"or track.property=="Action"then
    for _,key in ipairs(track.keys)do
     addCue(key.frame,track.property,binding,key,"Begin")
     if track.property=="Event"then addCue(key.frame+(key.duration or 0),"Event",binding,key,"End")end
    end
    if track.property=="Action"and(target:IsA("Sound")or target:IsA("AudioPlayer"))and not self._sounds[target]then
     self._sounds[target]=captureSound(target)
    end
   elseif track.property~="AttachToPart"and track.property~="LookAtPart"then
    table.insert(self._original,{target=target,property=track.property,value=snapshot(target,track.property),track=track})
   end
   if target:IsA("Camera")and not self._cameras[target]then
    self._cameras[target]={type=target.CameraType,cframe=target.CFrame,fov=target.FieldOfView}
   end
  end
 end
 for _,binding in ipairs(self._tracks)do
  if binding.track.property=="AttachToPart"or binding.track.property=="LookAtPart"then
   binding.anchors={}
   local baseline=self._cameras[binding.target].cframe
   for _,key in ipairs(binding.track.keys)do
    local target=ref(key.value)
    assert(key.value==""or(target and target:IsA("BasePart")),"Camera target reference is missing or is not a BasePart.")
    if target and binding.track.property=="AttachToPart"then
     binding.anchors[key.id]={
      offset=key.referenceOffset and Engine.decode(key.referenceOffset,"CFrame")or target.CFrame:ToObjectSpace(baseline),
      camera=key.referenceCamera and Engine.decode(key.referenceCamera,"CFrame")or baseline}
    end
   end
  end
 end
 for _,marker in ipairs(Data.markers or {})do addCue(marker.frame,"Marker",nil,marker,"Begin")end
 table.sort(self._cues,function(a,b)if a.frame==b.frame then return a.order<b.order end;return a.frame<b.frame end)
 if options.RunEventCode then
  local code=script:FindFirstChild("EventCode")
  self._code=code and require(code)or {}
 end
 self.Marker,self.Event,self.Completed=Instance.new("BindableEvent"),Instance.new("BindableEvent"),Instance.new("BindableEvent")
 return self
end
function Player:_apply()
 local cameras={}
 for _,binding in ipairs(self._tracks)do
  local track,target=binding.track,binding.target
  if track.property~="Event"and track.property~="Action"then
   local value=Engine.sample(track,self.Frame)
   if value~=nil then
    if target:IsA("Camera")then
     cameras[target]=cameras[target]or {};cameras[target][track.property]=value
     if track.property=="AttachToPart"then
      cameras[target]._attachKey=Engine.activeKey(track,self.Frame);cameras[target]._attachBinding=binding
     end
    elseif track.property=="Transform"then target[track._jointProperty]=binding.base*value
    else Properties.write(target,track.property,value,track)end
   end
  end
 end
 local reference=ref(Data._cameraReference)
 assert(not Data._cameraReference or(reference and reference:IsA("BasePart")),"Camera export reference is missing.")
 for camera,values in pairs(cameras)do
  local original=self._cameras[camera]
  local authored=values.CFrame or original.cframe
  if values.CFrame and reference then authored=reference.CFrame*authored end
  local cf=authored;local attach=ref(values.AttachToPart)
  if attach and attach:IsA("BasePart")then
   local key=values._attachKey
   local state=key and values._attachBinding.anchors[key.id]
   assert(state,"Camera attachment baseline is missing.")
   cf=attach.CFrame*state.offset*state.camera:ToObjectSpace(values.CFrame and authored or state.camera)
  end
  local look=ref(values.LookAtPart)
  if look and look:IsA("BasePart")and(look.Position-cf.Position).Magnitude>0.00001 then cf=CFrame.lookAt(cf.Position,look.Position)end
  camera.CameraType=Enum.CameraType.Scriptable;camera.CFrame=cf
  if values.FieldOfView then camera.FieldOfView=values.FieldOfView end
 end
end
function Player:Seek(frame)
 assert(not self._destroyed,"Player has been destroyed.")
 assert(type(frame)=="number"and frame==frame and math.abs(frame)<math.huge,"Frame must be finite.")
 self.Frame=math.clamp(frame,0,Data.duration);self._includeCurrent=true;self._attachments={};self:_apply();return self
end
function Player:_event(cue,reason)
 local key,binding=cue.key,cue.binding
 local identity=binding.track.id..":"..key.id
 if cue.phase=="End"and not self._activeEvents[identity]then return end
 if cue.phase=="Begin"then self._activeEvents[identity]=cue else self._activeEvents[identity]=nil end
 self.Event:Fire(cue.phase,key.value,key.eventValue or "",binding.target,key)
 if cue.phase=="Begin"then self.Marker:Fire(key.value,key.eventValue or "",cue.frame,binding.target)end
 local functions=self._code and self._code[key.id]
 local callback=functions and functions[cue.phase]
 if callback then callback({Player=self,Target=binding.target,Key=key,Frame=cue.frame,Reason=reason or "Playback"})end
end
function Player:_dispatch(first,last,includeFirst)
 local cues=self._cues
 local low,high=1,#cues+1
 while low<high do
  local middle=math.floor((low+high)/2);local cue=cues[middle]
  if cue and(cue.frame<first or(cue.frame==first and not includeFirst))then low=middle+1 else high=middle end
 end
 for index=low,#cues do
  local cue=cues[index];if cue.frame>last then break end
  if cue.kind=="Marker"then self.Marker:Fire(cue.key.name,cue.key.value,cue.frame)
  elseif cue.kind=="Event"then self:_event(cue)
  else
   local target=cue.binding.target
   if self._sounds[target]then self._ownedSounds[target]=true end
   action(target,cue.key)
  end
 end
end
function Player:Pause()
 if self._connection then self._connection:Disconnect();self._connection=nil end
 self.IsPlaying=false
 for target in pairs(self._ownedSounds)do if target.Parent and target.IsPlaying then Properties.pauseAudio(target);self._sounds[target].paused=true end end
 return self
end
function Player:Play()
 assert(not self._destroyed,"Player has been destroyed.")
 if self.IsPlaying then return self end
 assert(type(self.Speed)=="number"and self.Speed>0 and self.Speed<math.huge,"Speed must be positive and finite.")
 if self.Frame>=Data.duration then self.Frame=0;self._includeCurrent=true end
 self:_apply()
 for target in pairs(self._ownedSounds)do if target.Parent and self._sounds[target].paused then Properties.resumeAudio(target);self._sounds[target].paused=nil end end
 if self._includeCurrent then self:_dispatch(self.Frame,self.Frame,true);self._includeCurrent=false end
 if Data.duration<=0 then self.Completed:Fire();return self end
 self.IsPlaying=true
 self._connection=Run.Heartbeat:Connect(function(dt)
  local success,failure=pcall(function()
   local before,nextFrame=self.Frame,self.Frame+dt*Data.fps*self.Speed
   if self.Looped then
    local cycles=math.floor(nextFrame/Data.duration)
    assert(cycles<=100,"Playback exceeded 100 loops in one update.")
    if cycles>0 then
     self:_dispatch(before,Data.duration,false)
     for _=2,cycles do self:_dispatch(0,Data.duration,true)end
     nextFrame=nextFrame%Data.duration;self:_dispatch(0,nextFrame,true)
    else self:_dispatch(before,nextFrame,false)end
    self.Frame=nextFrame;self:_apply()
   else
    self.Frame=math.min(nextFrame,Data.duration);self:_dispatch(before,self.Frame,false);self:_apply()
    if nextFrame>=Data.duration then self:Pause();self.Completed:Fire()end
   end
  end)
  if not success then self:Pause();error(failure,0)end
 end)
 return self
end
function Player:Stop()
 self:Pause()
 local failures={}
 local function cleanup(callback,...)
  local ok,failure=pcall(callback,...);if not ok then table.insert(failures,tostring(failure))end;return ok
 end
 local events={};for _,cue in pairs(self._activeEvents)do table.insert(events,cue)end
 for _,cue in ipairs(events)do
  local ended={binding=cue.binding,key=cue.key,frame=self.Frame,phase="End"}
  cleanup(self._event,self,ended,"Stop")
 end
 self.Frame=0;self._includeCurrent=true;self._attachments={}
 for _,entry in ipairs(self._original)do cleanup(restore,entry.target,entry.property,entry.value,entry.track)end
 for target in pairs(self._ownedSounds)do if cleanup(restoreSound,target,self._sounds[target])then self._ownedSounds[target]=nil end end
 for camera,original in pairs(self._cameras)do cleanup(function()camera.CFrame=original.cframe;camera.FieldOfView=original.fov;camera.CameraType=original.type end)end
 if #failures>0 then error("Scene cleanup failed; retry Stop: "..table.concat(failures,"; "),0)end
 return self
end
function Player:Destroy()
 if self._destroyed then return end
 self:Stop();self.Marker:Destroy();self.Event:Destroy();self.Completed:Destroy();self._destroyed=true
end
return {Data=Data,Player=Player,new=Player.new}
]==]

-- Resolve references once while authoring, then retain ObjectValues in the artifact.
local function exportData(project,bindings,cameraReference)
 timing(project)
 assert(not cameraReference or cameraReference:IsA("BasePart"),"Camera reference must be a BasePart.")
 local data,references,wanted=copy(project),{},{}
 local function addReference(instance)
  assert(typeof(instance)=="Instance","Export target is missing.")
  for _,entry in ipairs(references)do if entry.instance==instance then return entry.name end end
  local name="Target_"..tostring(#references+1)
  table.insert(references,{name=name,instance=instance});return name
 end
 if cameraReference then data._cameraReference=addReference(cameraReference)end
 local count=0
 for _,track in ipairs(data.tracks or {})do
  if track.enabled~=false and #track.keys>0 then
   local binding=bindings[track.id];assert(binding and binding.instance,"Unbound export track: "..tostring(track.name))
   track._targetRef=addReference(binding.instance);count=count+1
   if track.property=="Transform"then
    assert(binding.instance:IsA("Motor6D")or binding.instance:IsA("Bone"),"Invalid rig binding.")
    track._jointProperty=binding.instance:IsA("Bone")and"Transform"or"C0"
    track._rest=track.rest or Engine.encode(binding.base,"CFrame")
   elseif track.property=="AttachToPart"or track.property=="LookAtPart"then
    for _,key in ipairs(track.keys)do
     local target=binding.references and binding.references[key.id]
     if target then assert(target:IsA("BasePart"),"Camera target must be a BasePart.");key.value=addReference(target)
     elseif key.value~=""and key.value~=nil then
      assert(type(key.value)=="string","Object reference must identify an instance.")
      wanted[key.value]=wanted[key.value]or {};table.insert(wanted[key.value],key)
     end
    end
   elseif cameraReference and binding.instance:IsA("Camera")and track.property=="CFrame"then
    for _,key in ipairs(track.keys)do key.value=Engine.encode(cameraReference.CFrame:ToObjectSpace(Engine.decode(key.value,"CFrame")),"CFrame")end
   end
  end
 end
 assert(count>0,"Add keyed tracks before exporting.")
 if next(wanted)then
  local resolved={}
  for _,instance in ipairs(game:GetDescendants())do
   local path=instance:GetFullName()
   if wanted[path]then assert(not resolved[path],"Ambiguous object reference: "..path);resolved[path]=instance end
  end
  for path,keys in pairs(wanted)do
   assert(resolved[path]and resolved[path]:IsA("BasePart"),"Missing or invalid camera target: "..path)
   local name=addReference(resolved[path]);for _,key in ipairs(keys)do key.value=name end
  end
 end
 return data,references
end

local function objectValue(parent,name,target)
 local value=Instance.new("ObjectValue");value.Name,value.Value,value.Parent=name,target,parent;return value
end
local function folder(parent,name)
 local value=Instance.new("Folder");value.Name,value.Parent=name,parent;return value
end
local function scalar(parent,class,name,value)
 local instance=Instance.new(class);instance.Name,instance.Value,instance.Parent=name,value,parent;return instance
end
local function addReferences(parent,references)
 for _,entry in ipairs(references)do objectValue(parent,entry.name,entry.instance)end
end

local function jsonValue(parent,name,value)
 local result=scalar(parent,"StringValue",name,"")
 local ok,reason=Saves.writeFreshJSON(result,value);assert(ok,reason);return result
end

-- Independent baked scene format. Camera Frames/FOV folder names follow observed
-- public exports; the complete schema is Keynova's, not Moon save interchange.
-- Each item and track retains concrete ObjectValues so names may safely change.
function Export.files(project,bindings,cameraReference,itemObjects)
 local fps,duration=timing(project)
 local data,references=exportData(project,bindings,cameraReference)
 local byReference={};for _,entry in ipairs(references)do byReference[entry.name]=entry.instance end
 local sampled,cues=0,0
 for _,track in ipairs(data.tracks)do if track._targetRef then
  if track.property=="Event"or track.property=="Action"then cues=cues+#track.keys
  else sampled=sampled+1 end
 end end
 assert(sampled*(duration+1)+cues<=MAX_POSES,"Baked export exceeds 120000 frame values. Shorten the animation or export fewer tracks.")
 local root=Instance.new("Folder")
 local ok,failure=pcall(function()
  root.Name=project.name or "Keynova Animation";root:SetAttribute("KeynovaFormat","BakedSceneV1")
  jsonValue(root,"Metadata",data)
  local reader=Instance.new("ModuleScript");reader.Name="ReadMetadata";reader.Source="local Codec=require(script.Codec)\nreturn function(entry)return Codec.read(entry or script.Parent.Metadata)end";reader.Parent=root
  local codec=Instance.new("ModuleScript");codec.Name="Codec";codec.Source=Saves.source;codec.Parent=reader
  local settings=folder(root,"Settings")
  scalar(settings,"NumberValue","FPS",fps);scalar(settings,"IntValue","Duration",duration);scalar(settings,"BoolValue","Loop",project.loop==true)
  local refs=folder(root,"References");addReferences(refs,references)
  if cameraReference then objectValue(settings,"CameraReference",cameraReference)end
  local items=folder(root,"Items");local itemFolders={}
  for _,item in ipairs(project.items or {})do
   local current=folder(items,item.id);current:SetAttribute("ItemName",item.name);current:SetAttribute("ItemType",item.type)
   if itemObjects and itemObjects[item.id]then objectValue(current,"Target",itemObjects[item.id])end
   itemFolders[item.id]=current
  end
  local valueClasses={CFrame="CFrameValue",Vector3="Vector3Value",Color3="Color3Value",number="NumberValue",boolean="BoolValue",string="StringValue"}
  for _,track in ipairs(data.tracks)do if track._targetRef then
   local parent=itemFolders[track.itemId];assert(parent,"Export track has no item.")
   local target=byReference[track._targetRef]
   if not parent:FindFirstChild("Target")and track.property~="Transform"then objectValue(parent,"Target",target)end
   local name=target:IsA("Camera")and(track.property=="CFrame"and"Frames"or track.property=="FieldOfView"and"FOV")or track.property
   if parent:FindFirstChild(name)then name=name.."_"..track.id end
   local frames=folder(parent,name)
   frames:SetAttribute("TrackId",track.id);frames:SetAttribute("Property",track.property);frames:SetAttribute("ValueType",track.valueType)
   objectValue(frames,"Target",target)
   if track._rest then scalar(frames,"CFrameValue","Rest",Engine.decode(track._rest,"CFrame"))end
   if track.property=="AttachToPart"or track.property=="LookAtPart"then
    local keys=folder(frames,"Keys")
    for _,key in ipairs(track.keys)do
     local entry=folder(keys,key.id);jsonValue(entry,"Metadata",key)
     objectValue(entry,"Target",byReference[key.value])
     if key.referenceOffset then scalar(entry,"CFrameValue","ReferenceOffset",Engine.decode(key.referenceOffset,"CFrame"))end
     if key.referenceCamera then scalar(entry,"CFrameValue","ReferenceCamera",Engine.decode(key.referenceCamera,"CFrame"))end
    end
   end
   if track.property=="Event"or track.property=="Action"then
    for _,key in ipairs(track.keys)do
     local entry=folder(frames,tostring(key.frame))
     jsonValue(entry,"Metadata",key)
     scalar(entry,"StringValue","Name",key.value)
     if track.property=="Event"then
      scalar(entry,"StringValue","Value",key.eventValue or "");jsonValue(entry,"Events",key.events or {})
      scalar(entry,"IntValue","Duration",key.duration or 0)
      scalar(entry,"StringValue","CodeBegin",key.codeBegin or "");scalar(entry,"StringValue","CodeEnd",key.codeEnd or "")
     else scalar(entry,"StringValue","Arguments",ExportHttp:JSONEncode(key.arguments or {}))end
    end
   else
    for frame=0,duration do
     local value=Engine.sample(track,frame)
     if value~=nil then
      local class=valueClasses[track.valueType]
      if track.property=="AttachToPart"or track.property=="LookAtPart"then
       objectValue(frames,tostring(frame),byReference[value])
      elseif class then scalar(frames,class,tostring(frame),value)
      else
       local encoded=scalar(frames,"StringValue",tostring(frame),ExportHttp:JSONEncode(Engine.encode(value,track.valueType)))
       encoded:SetAttribute("ValueType",track.valueType)
      end
     end
    end
   end
  end end
  local markers=folder(root,"Markers")
  for _,marker in ipairs(project.markers or {})do jsonValue(markers,marker.id,marker)end
 end)
 if not ok then root:Destroy();error(failure,0)end
 return root
end

-- A shared Engine/Properties child pair is copied exactly from the bundle's
-- producing modules; runtime sampling and property interpretation have one owner.
function Export.sceneModule(project,bindings,cameraReference)
 local data,references=exportData(project,bindings,cameraReference)
 assert(type(Engine.source)=="string"and Engine.source~="","Build the plugin before exporting a scene (missing Engine source).")
 assert(type(Properties.source)=="string"and Properties.source~="","Build the plugin before exporting a scene (missing Properties source).")
 local source=string.gsub(PLAYER_SOURCE,"__KEYNOVA_DATA__",function()return string.format("%q",ExportHttp:JSONEncode(data))end)
 local eventKeys={}
 for _,track in ipairs(data.tracks)do if track.property=="Event"and track._targetRef then for _,key in ipairs(track.keys)do table.insert(eventKeys,key)end end end
 local eventSource=Events.source(eventKeys)
 local result=Instance.new("ModuleScript")
 local ok,failure=pcall(function()
  result.Name,result.Source=(project.name or "Keynova").." Scene",source
  local engine=Instance.new("ModuleScript");engine.Name,engine.Parent="Engine",result;engine.Source=Engine.source
  local properties=Instance.new("ModuleScript");properties.Name,properties.Parent="Properties",result;properties.Source=Properties.source
  local events=Instance.new("ModuleScript");events.Name,events.Parent="EventCode",result;events.Source=eventSource
  addReferences(result,references)
 end)
 if not ok then result:Destroy();error(failure,0)end
 return result
end

return Export
