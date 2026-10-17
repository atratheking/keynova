-- Execute in real Roblox Studio after the prepared plugin bundle. No fake API.
local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local function near(a,b)
 if typeof(a)=="CFrame"then
  local x,y={a:GetComponents()},{b:GetComponents()}
  for i=1,12 do if math.abs(x[i]-y[i])>0.0001 then return false end end;return true
 end
 return math.abs(a-b)<0.0001
end
local fixture=Instance.new("Folder");fixture.Name="KeynovaExportParity";fixture.Parent=workspace
local runtime=Runtime.new()
local project=Engine.newProject("Export parity");project.duration=6;project.fps=60
local rig=Instance.new("Model");rig.Name="Mixed Rig";rig.Parent=fixture
local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.Parent=rig
local head=Instance.new("MeshPart");head.Name="Head";head.Parent=rig
local motor=Instance.new("Motor6D");motor.Name="Neck";motor.Part0,motor.Part1=root,head;motor.C0=CFrame.new(0,2,0);motor.Parent=root
local bone=Instance.new("Bone");bone.Name="BoneRoot";bone.CFrame=CFrame.new(0,0.5,0);bone.Transform=CFrame.Angles(0.1,0,0);bone.Parent=head
local tip=Instance.new("Bone");tip.Name="BoneTip";tip.CFrame=CFrame.new(0,1,0);tip.Transform=CFrame.Angles(0,0.2,0);tip.Parent=bone
local face=Instance.new("FaceControls");face.Parent=head
local item,reason=runtime:addRig(project,rig);check(item~=nil,reason or "Mixed Motor/Bone rig binds")
local boneTrack,tipTrack,jawTrack,headTrack
for _,track in ipairs(project.tracks)do
 if track.property=="Transform"then
  Engine.insert(track,0,CFrame.new(),"Sextic","OutIn")
  Engine.insert(track,6,CFrame.Angles(0,0,0.6),"Linear","InOut")
  if track.name==bone.Name then boneTrack=track elseif track.name==tip.Name then tipTrack=track elseif track.name==head.Name then headTrack=track end
 elseif track.property=="JawDrop"and track.rigItemId==item.id then
  jawTrack=track;Engine.insert(track,0,0);Engine.insert(track,6,0.8)
 end
end
check(boneTrack and tipTrack and headTrack,"All mixed hierarchy joints get tracks")
check(boneTrack.jointType=="Bone"and boneTrack.parentTrackId==headTrack.id,"Bone metadata retains animated parent")
check(jawTrack~=nil,"FaceControls channels are associated with rig")
local rigEvent=runtime:addProperty(project,item,"Event")
local eventKey=Engine.insert(rigEvent,2,"Footstep");eventKey.eventValue="left";eventKey.duration=1
local sequence=Export.rig(project,item,runtime.bindings)
check(sequence.Parent==nil and #sequence:GetKeyframes()==7,"Rig artifact is unparented and bakes integer frames")
local last
for _,key in ipairs(sequence:GetKeyframes())do if near(key.Time,0.1)then last=key end end
local rootPose=last and last:FindFirstChild("HumanoidRootPart")
local headPose=rootPose and rootPose:FindFirstChild("Head")
local bonePose=headPose and headPose:FindFirstChild("BoneRoot")
check(bonePose and bonePose:FindFirstChild("BoneTip"),"Native Pose tree preserves Motor to Bone to Bone hierarchy")
check(near(bonePose.CFrame,CFrame.Angles(0,0,0.6)),"Exported Bone pose is authored relative delta, not bind transform")
local numberPose=headPose:FindFirstChild("FaceControls")and headPose.FaceControls:FindFirstChild("JawDrop")
check(numberPose and numberPose:IsA("NumberPose")and near(numberPose.Value,0.8),"Native facial channels use NumberPose under Head.FaceControls")
local foundMarker=false
for _,key in ipairs(sequence:GetKeyframes())do for _,marker in ipairs(key:GetMarkers())do
 if marker.Name=="Footstep"and marker.Value=="left"then foundMarker=true end
end end
check(foundMarker,"Rig Event name and parameter are exported as native markers")
local imported,importError=Export.importRig(project,item,sequence,"Replace",0)
check(imported,importError or "Mixed rig imports")
check(#boneTrack.keys==7 and near(Engine.sample(tipTrack,6),CFrame.Angles(0,0,0.6)),"Bone relative values survive export/import")
check(near(Engine.sample(jawTrack,6),0.8),"NumberPose channels survive rig import")
local savedKeys=boneTrack.keys;boneTrack.locked=true
local rejected=Export.importRig(project,item,sequence,"Replace",0)
check(not rejected and boneTrack.keys==savedKeys,"Replacing locked tracks fails without partial mutation")
boneTrack.locked=false
local oversized=Engine.clone(project);oversized.duration=36000
check(not pcall(Export.rig,oversized,item,runtime.bindings),"Baked rig capacity rejects excessive instance allocation")
sequence:Destroy()

local sparse=Instance.new("KeyframeSequence")
for _,frame in ipairs({0,6})do
 local key=Instance.new("Keyframe");key.Time=frame/project.fps;key.Parent=sparse
 local rootPose=Instance.new("Pose");rootPose.Name="HumanoidRootPart";rootPose.Parent=key
 local headPose=Instance.new("Pose");headPose.Name="Head";headPose.CFrame=CFrame.new(frame,0,0);headPose.Weight=0.5;headPose.EasingStyle=Enum.PoseEasingStyle.Bounce;headPose.EasingDirection=Enum.PoseEasingDirection.Out;headPose.Parent=rootPose
end
local importedSparse,sparseError=Export.importRig(project,item,sparse,"Replace",0)
check(importedSparse,sparseError or "Sparse eased animation imports")
check(headTrack.keys[1].easing=="Bounce"and headTrack.keys[1].direction=="Out","Native sparse Pose easing is retained")
check(headTrack.keys[1].nativeWeight==0.5 and near(Engine.sample(headTrack,6),CFrame.new(3,0,0)),"Native pose weight affects preview without losing authored delta")
local weightedExport=Export.rig(project,item,runtime.bindings)
local weightedLast;for _,key in ipairs(weightedExport:GetKeyframes())do if near(key.Time,0.1)then weightedLast=key end end
check(weightedLast.HumanoidRootPart.Head.Weight==0.5 and near(weightedLast.HumanoidRootPart.Head.CFrame,CFrame.new(6,0,0)),"Native export preserves pose weight and unweighted pose values")
weightedExport:Destroy()
local oldKeys=headTrack.keys;local pasteResult=Export.importRig(project,item,sparse,"Paste",0)
check(not pasteResult and headTrack.keys~=nil and #headTrack.keys==#oldKeys,"Rig Paste rejects occupied key destinations atomically")
sparse:Destroy()
-- Restore the original mixed fixture for subsequent scene interpolation checks.
for _,track in ipairs(project.tracks)do if track.property=="Transform"then track.keys={};Engine.insert(track,0,CFrame.new(),"Sextic","OutIn");Engine.insert(track,6,CFrame.Angles(0,0,0.6))elseif track==jawTrack then track.keys={};Engine.insert(track,0,0);Engine.insert(track,6,0.8)end end

local reference=Instance.new("Part");reference.Name="Camera Reference";reference.Anchored=true;reference.CFrame=CFrame.new(10,0,0);reference.Parent=fixture
local camera=Instance.new("Camera");camera.Name="ExportCamera";camera.CameraType=Enum.CameraType.Fixed;camera.CFrame=CFrame.new(10,5,20);camera.Parent=fixture
local cameraItem=runtime:addObject(project,camera,{"CFrame","FieldOfView"})
for _,track in ipairs(project.tracks)do if track.itemId==cameraItem.id then
 if track.property=="CFrame"then Engine.insert(track,0,CFrame.new(10,5,20));Engine.insert(track,6,CFrame.new(16,5,20))
 else Engine.insert(track,0,60);Engine.insert(track,6,90)end
end end
local prop=Instance.new("Part");prop.Name="EventTarget";prop.Anchored=true;prop.Parent=fixture
local propItem=runtime:addObject(project,prop,{"Transparency"},true)
local eventTrack
for _,track in ipairs(project.tracks)do if track.itemId==propItem.id then
 if track.property=="Event"then
  eventTrack=track
  local key=Engine.insert(track,0,"Pulse");key.eventValue="payload";key.duration=2;key.events={Parent="Head",EmitCount=3}
  key.codeBegin='parent:SetAttribute("BeginCount",(parent:GetAttribute("BeginCount") or 0)+1);parent:SetAttribute("EventCount",values.EmitCount)'
  key.codeEnd='parent:SetAttribute("EndCount",(parent:GetAttribute("EndCount") or 0)+1)'
 else Engine.insert(track,0,0);Engine.insert(track,6,0.6)end
end end
local files=Export.files(project,runtime.bindings,reference,runtime.objects)
check(files.Parent==nil and files.Settings.FPS.Value==60,"Native baked folder has explicit FPS and no scene side effect")
local cameraFiles=files.Items:FindFirstChild(cameraItem.id)
check(cameraFiles and cameraFiles.Target.Value==camera,"Baked item retains concrete ObjectValue target")
check(cameraFiles.Frames:FindFirstChild("3"):IsA("CFrameValue")and near(cameraFiles.Frames["3"].Value,CFrame.new(3,5,20)),"Camera baked CFrames are reference-local")
check(near(cameraFiles.FOV["3"].Value,75),"Camera FOV is sampled into numeric frame values")
local eventFiles=files.Items[propItem.id].Event["0"]
check(eventFiles.Value.Value=="payload"and eventFiles.CodeBegin.Value~=""and eventFiles.Duration.Value==2,"Baked events retain metadata and authored code")
check(game:GetService("HttpService"):JSONDecode(eventFiles.Events.Value).EmitCount==3,"Baked event dictionaries retain named typed values")
check(files.Settings.CameraReference.Value==reference,"Baked reference survives instance renaming")
files:Destroy()

local model=Instance.new("Model");model.Name="Model Appearance";model.Parent=fixture
local red=Instance.new("Part");red.Anchored=true;red.Color=Color3.new(1,0,0);red.Parent=model
local blue=Instance.new("Part");blue.Anchored=true;blue.Color=Color3.new(0,0,1);blue.Parent=model
local modelItem=runtime:addObject(project,model,{"Color"})
for _,track in ipairs(project.tracks)do if track.itemId==modelItem.id then Engine.insert(track,0,Color3.new(0,1,0))end end
local ui=Instance.new("Frame");ui.Size=UDim2.fromOffset(100,100);ui.Parent=fixture
local uiItem=runtime:addObject(project,ui,{"Position"})
for _,track in ipairs(project.tracks)do if track.itemId==uiItem.id then
 Engine.insert(track,0,UDim2.new(0,0,0,0));Engine.insert(track,6,UDim2.new(1,60,0.5,30))
end end
local particle=Instance.new("ParticleEmitter");particle.Parent=prop
local particleItem=runtime:addObject(project,particle,{"Size","Color","Lifetime"})
for _,track in ipairs(project.tracks)do if track.itemId==particleItem.id then
 if track.property=="Size"then Engine.insert(track,0,NumberSequence.new(0));Engine.insert(track,6,NumberSequence.new(2))
 elseif track.property=="Color"then Engine.insert(track,0,ColorSequence.new(Color3.new(0,0,0)));Engine.insert(track,6,ColorSequence.new(Color3.new(1,1,1)))
 else Engine.insert(track,0,NumberRange.new(0,1));Engine.insert(track,6,NumberRange.new(2,3))end
end end
local structured=Export.files(project,runtime.bindings,nil,runtime.objects)
check(structured.Items[uiItem.id].Position["3"]:IsA("StringValue")and structured.Items[uiItem.id].Position["3"]:GetAttribute("ValueType")=="UDim2","Structured values bake as typed JSON ValueBases")
structured:Destroy()
local exported=Export.sceneModule(project,runtime.bindings,reference);exported.Parent=fixture
check(exported.Engine.Source==Engine.source and exported.Properties.Source==Properties.source,"Scene embeds exact shared producer modules")
camera.Name="Renamed Camera";reference.Name="Renamed Reference";reference.CFrame=CFrame.new(20,0,0)
local playerModule=require(exported)
local player=playerModule.new()
player:Seek(3)
check(near(camera.CFrame,CFrame.new(23,5,20)),"Scene reconstructs camera from moving reference ObjectValue")
check(near(bone.Transform,Engine.decode(boneTrack.rest,"CFrame")*Engine.sample(boneTrack,3)),"Scene applies nonidentity Bone rest times authored delta")
check(red.Color==Color3.new(0,1,0)and blue.Color==Color3.new(0,1,0),"Scene uses shared Model appearance writer")
check(ui.Position==UDim2.new(0.5,30,0.25,15),"Scene shares UDim2 interpolation with editor")
check(near(particle.Size.Keypoints[1].Value,1)and near(particle.Color.Keypoints[1].Value.R,0.5)and near(particle.Lifetime.Min,1),"Scene shares sequence and range interpolation with editor")
check(prop:GetAttribute("BeginCount")==nil,"Seeking never executes event code")
local phases={}
player.Event.Event:Connect(function(phase,name,value,target)
 if target==prop then table.insert(phases,phase..":"..name..":"..value)end
end)
player:Seek(0);player:Play();player:Pause();player:Play();player:Pause();task.wait()
check(#phases==1 and phases[1]=="Begin:Pulse:payload","Pause/resume does not duplicate current-frame event")
check(prop:GetAttribute("BeginCount")==nil,"Scene event code is disabled by default")
player:Stop();task.wait()
check(red.Color==Color3.new(1,0,0)and blue.Color==Color3.new(0,0,1),"Stop restores heterogeneous Model descendants")
check(near(bone.Transform,Engine.decode(boneTrack.rest,"CFrame")),"Stop restores original Bone Transform")
player:Destroy()
local opted=playerModule.new({RunEventCode=true});opted:Play();opted:Pause()
check(prop:GetAttribute("BeginCount")==1 and prop:GetAttribute("EventCount")==3,"Explicit event-code opt-in exposes named event values to authored Begin")
opted:Stop()
check(prop:GetAttribute("EndCount")==1,"Stopping active authored event runs End exactly once")
opted:Destroy();exported:Destroy()

-- Authored attachment baselines are per key; seeking order must not alter them.
local attach=runtime:addProperty(project,cameraItem,"AttachToPart")
local attachKey=Engine.insert(attach,0,"Legacy path intentionally renamed")
attachKey.referenceOffset=Engine.encode(CFrame.new(0,5,20),"CFrame")
attachKey.referenceCamera=Engine.encode(CFrame.new(10,5,20),"CFrame")
runtime.bindings[attach.id].references={[attachKey.id]=reference}
local attachment=Export.sceneModule(project,runtime.bindings);attachment.Parent=fixture
local attached=require(attachment).new()
attached:Seek(6);attached:Seek(3);local firstSeek=camera.CFrame
attached:Seek(0);attached:Seek(3)
check(near(firstSeek,camera.CFrame)and near(camera.CFrame,CFrame.new(23,5,20)),"Stable attachment references and authored offsets are independent of seek history")
attached:Destroy();attachment:Destroy()
local attachmentFiles=Export.files(project,runtime.bindings,nil,runtime.objects)
local bakedAttachment=attachmentFiles.Items[cameraItem.id].AttachToPart
check(bakedAttachment["0"].Value==reference and bakedAttachment.Keys[attachKey.id].ReferenceOffset:IsA("CFrameValue"),"Baked attachment keeps target and per-key baseline values")
attachmentFiles:Destroy()

-- Unknown methods must never become arbitrary instance method calls.
local actionProject=Engine.newProject("Action whitelist");actionProject.duration=2
local actionRuntime=Runtime.new();local emitter=Instance.new("ParticleEmitter");emitter.Parent=prop
local emitterItem=actionRuntime:addObject(actionProject,emitter,{})
local actions=actionRuntime:addProperty(actionProject,emitterItem,"Action")
Engine.insert(actions,0,"Destroy")
local actionModule=Export.sceneModule(actionProject,actionRuntime.bindings);actionModule.Parent=fixture
local actionPlayer=require(actionModule).new()
check(not pcall(function()actionPlayer:Play()end)and emitter.Parent==prop,"Export action dispatch rejects non-whitelisted methods")
actionPlayer:Destroy();actionModule:Destroy();actionRuntime:destroy()
runtime:destroy();fixture:Destroy()
print("KEYNOVA_EXPORT_PARITY_PASS "..checks.." real Studio checks")
