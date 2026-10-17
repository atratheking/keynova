-- Real Studio integration checks; this place is created only for this run.
local count=0
local function check(value,text)assert(value,text);count=count+1 end
if not workspace:FindFirstChild("Baseplate")then local floor=Instance.new("Part");floor.Name="Baseplate";floor.Size=Vector3.new(256,1,256);floor.Position=Vector3.new(0,-0.5,0);floor.Anchored=true;floor.Color=Color3.fromRGB(105,110,116);floor.Material=Enum.Material.Concrete;floor.Parent=workspace end
local fixture=Instance.new("Model");fixture.Name="Dummy";fixture.Parent=workspace
local function part(name,size,position,color)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(position);p.Color=color or Color3.fromRGB(163,162,165);p.CanCollide=false;p.Parent=fixture;return p
end
local rootPart=part("HumanoidRootPart",Vector3.new(2,2,1),Vector3.new(0,4,0));rootPart.Transparency=1;rootPart.Anchored=true
local torso=part("Torso",Vector3.new(2,2,1),Vector3.new(0,4,0),Color3.fromRGB(28,104,196))
local function joint(name,a,b,c0,c1)local m=Instance.new("Motor6D");m.Name=name;m.Part0=a;m.Part1=b;m.C0=c0;m.C1=c1;m.Parent=a;return m end
joint("RootJoint",rootPart,torso,CFrame.new(),CFrame.new())
local definitions={{"Head",Vector3.new(2,1,1),Vector3.new(0,5.5,0),CFrame.new(0,1,0),CFrame.new(0,-.5,0)}, {"Left Arm",Vector3.new(1,2,1),Vector3.new(1.5,4,0),CFrame.new(1.5,.8,0),CFrame.new(0,.8,0)}, {"Right Arm",Vector3.new(1,2,1),Vector3.new(-1.5,4,0),CFrame.new(-1.5,.8,0),CFrame.new(0,.8,0)}, {"Left Leg",Vector3.new(1,2,1),Vector3.new(.5,2,0),CFrame.new(.5,-1,0),CFrame.new(0,1,0)}, {"Right Leg",Vector3.new(1,2,1),Vector3.new(-.5,2,0),CFrame.new(-.5,-1,0),CFrame.new(0,1,0)}}
for _,d in ipairs(definitions)do local p=part(d[1],d[2],d[3],d[1]=="Head"and Color3.fromRGB(245,205,48)or d[1]:find("Leg")and Color3.fromRGB(75,151,75)or Color3.fromRGB(245,205,48));joint(d[1].."Joint",torso,p,d[4],d[5])end
local face=Instance.new("Decal");face.Name="face";face.Texture="rbxasset://textures/face.png";face.Face=Enum.NormalId.Front;face.Parent=fixture.Head
local shape=Instance.new("SpecialMesh");shape.MeshType=Enum.MeshType.Head;shape.Scale=Vector3.new(1.25,1.25,1.25);shape.Parent=fixture.Head
Keynova.widget.Enabled=true;task.wait(0.2);Keynova.newFile("Wave test")
local state,rt=Keynova.state,Keynova.runtime
state.project.duration=120
local rig,err=rt:addRig(state.project,fixture);check(rig~=nil,err or"Rig binding")
check(#state.project.tracks==6,"Six Motor6D tracks")
local arm
for _,t in ipairs(state.project.tracks)do
 Engine.insert(t,0,CFrame.new(),"Sine","InOut")
 Engine.insert(t,60,t.name=="Right Arm"and CFrame.Angles(0,0,math.rad(-120))or t.name=="Head"and CFrame.Angles(0,0,math.rad(8))or CFrame.new(),"Sine","InOut")
 Engine.insert(t,120,CFrame.new(),"Sine","InOut")
 if t.name=="Right Arm"then arm=t end
end
state.activeItem=rig.id;Keynova.choose(arm);Keynova.seek(60);Keynova.render()
local motor=rt.bindings[arm.id].instance;local original=rt.bindings[arm.id].base
check(motor.C0~=original,"Native pose applied")
state.frame=45;Keynova.addKey(CFrame.Angles(0,0,-1));check(#arm.keys==4,"Key insertion")
Keynova.undo();arm=nil;for _,t in ipairs(state.project.tracks)do if t.name=="Right Arm"then arm=t end end;check(#arm.keys==3,"Undo")
Keynova.redo();arm=nil;for _,t in ipairs(state.project.tracks)do if t.name=="Right Arm"then arm=t end end;check(#arm.keys==4,"Redo")
state.selected={{trackId=arm.id,keyId=arm.keys[1].id},{trackId=arm.id,keyId=arm.keys[2].id}}
Keynova.groupKeys(false);check(arm.keys[1].group~=nil and arm.keys[1].group==arm.keys[2].group,"Selected keys grouped")
Keynova.groupKeys(true);check(arm.keys[1].group==nil and arm.keys[2].group==nil,"Ungroup removes group identity")
state.project.groupKeyframes=true;state.frame=60;Keynova.addKey(CFrame.Angles(0,0,math.rad(-120)))
local group=arm.keys[3].group;local grouped=0
for _,track in ipairs(state.project.tracks)do for _,key in ipairs(track.keys)do if key.frame==60 and key.group==group then grouped=grouped+1 end end end
check(group~=nil and grouped==6,"Group Keyframes joins rig keys on the same frame")
state.project.groupKeyframes=false
local prop=Instance.new("Part");prop.Name="Prop";prop.Anchored=true;prop.Position=Vector3.new(4,2,0);prop.Parent=workspace
local propItem=rt:addObject(state.project,prop,{"CFrame","Size","Color","Transparency"},true);check(propItem~=nil,"Property item")
for _,t in ipairs(state.project.tracks)do if t.itemId==propItem.id then
 local value=rt:read(t);Engine.insert(t,0,value)
 local goal=t.property=="CFrame"and CFrame.new(6,2,0)or t.property=="Size"and Vector3.new(3,2,1)or t.property=="Color"and Color3.new(1,0,0)or t.property=="Transparency"and 0.5 or"PropEvent"
 Engine.insert(t,60,goal)
end end
local camera=Instance.new("Camera");camera.Name="TestCamera";camera.CFrame=CFrame.new(0,8,12);camera.Parent=workspace
local cameraItem=rt:addObject(state.project,camera,{"CFrame","FieldOfView"});check(cameraItem~=nil,"Camera item")
for _,t in ipairs(state.project.tracks)do if t.itemId==cameraItem.id then Engine.insert(t,0,rt:read(t));Engine.insert(t,60,t.property=="CFrame"and CFrame.new(0,9,13)or 80)end end
state.project.markers={{id="marker",frame=30,name="Footstep",value="left"}}
rt:apply(state.project,60)
check(math.abs(prop.Position.X-6)<0.001,"Object CFrame applied")
check(math.abs(prop.Transparency-0.5)<0.001,"Numeric property applied")
check(prop.Color==Color3.new(1,0,0),"Color property applied")
check(math.abs(camera.FieldOfView-80)<0.001,"Camera FOV applied")
-- Exercise restoration through the real runtime rather than mirror its implementation.
local restorePart=Instance.new("Part");restorePart.Anchored=true;restorePart.Material=Enum.Material.Wood;restorePart.Parent=workspace
local restoreCamera=Instance.new("Camera");restoreCamera.CameraType=Enum.CameraType.Fixed;restoreCamera.CFrame=CFrame.new(1,2,3);restoreCamera.FieldOfView=65;restoreCamera.Parent=workspace
local restoreRuntime=Runtime.new();local restoreProject=Engine.newProject("Restoration")
restoreRuntime:addObject(restoreProject,restorePart,{"Transparency","Material"})
restoreRuntime:addObject(restoreProject,restoreCamera,{"CFrame","FieldOfView"})
for _,track in ipairs(restoreProject.tracks)do
 Engine.insert(track,0,track.property=="Transparency"and 0.8 or track.property=="Material"and "Neon"or track.property=="CFrame"and CFrame.new(9,8,7)or 90)
end
restoreRuntime:apply(restoreProject,0)
check(restorePart.Material==Enum.Material.Neon and restorePart.Transparency>0.7,"Enum and numeric preview applied")
for _,track in ipairs(restoreProject.tracks)do track.enabled=false end
restoreRuntime:apply(restoreProject,0)
check(restorePart.Material==Enum.Material.Wood and restorePart.Transparency==0,"Disabled tracks restore enum and numeric originals")
check(restoreCamera.CameraType==Enum.CameraType.Fixed and restoreCamera.CFrame==CFrame.new(1,2,3)and restoreCamera.FieldOfView==65,"Disabled camera releases control and restores properties")
for _,track in ipairs(restoreProject.tracks)do track.enabled=true end
restoreRuntime:apply(restoreProject,0)
for _,track in ipairs(restoreProject.tracks)do track.keys={}end
restoreRuntime:apply(restoreProject,0)
check(restorePart.Material==Enum.Material.Wood and restorePart.Transparency==0,"Deleting final keys restores properties")
check(restoreCamera.CameraType==Enum.CameraType.Fixed,"Empty camera tracks release control")
restoreRuntime:destroy();restorePart:Destroy();restoreCamera:Destroy()
local valid,reason=Engine.validate(Engine.clone(state.project));check(valid,reason or"Project validation")
state.project.rigItemId=rig.id;Keynova.save();local rigEntry=state.savedEntry
check(rigEntry and rigEntry.Parent==fixture:FindFirstChild("AnimSaves"),"Rig Animation saves inside its rig")
Keynova.openSaved(rigEntry);state=Keynova.state
check(state.project.rigItemId==rig.id,"Rig save mode survives reopening")
state.project.rigItemId=nil;state.savedEntry=nil
Keynova.save();local entry=state.savedEntry;check(entry and entry:IsA("StringValue"),"Editable save exists")
Keynova.openSaved(entry);state=Keynova.state;rig=state.project.items[1]
check(#state.project.items==3,"Reopen multi-item file")
local sequence=Export.rig(state.project,rig,rt.bindings)
check(#sequence:GetKeyframes()==121,"Rig export has all integer frames")
local markerFound=false;for _,kf in ipairs(sequence:GetKeyframes())do for _,m in ipairs(kf:GetMarkers())do if m.Name=="Footstep"then markerFound=true end end end;check(markerFound,"Markers exported")
local imported,importError=Export.importRig(state.project,rig,sequence,"Replace",0);check(imported,importError or"Rig import")
sequence:Destroy()
local scene=Export.sceneModule(state.project,rt.bindings);scene.Parent=Storage or game:GetService("ServerStorage")
local playerModule=require(scene);local player=playerModule.new()
player:Seek(30);check(math.abs(prop.Position.X-5)<0.01,"Exported scene interpolates real object")
player:Play();task.wait(0.12);player:Pause();check(player.Frame>30,"Exported playback advances")
player:Stop();player:Destroy();scene:Destroy()
Keynova.setOnion(true);check(rt.onionFolder and rt.onionFolder.Parent==workspace,"Onion geometry exists")
Keynova.setOnion(false);check(rt.onionFolder==nil,"Onion geometry cleaned")
rt:restore();check(motor.C0==original,"Original joint offsets restored")
state.frame=0;Keynova.play();task.wait(0.12);Keynova.play();check(state.frame>0,"Editor playback advances")
-- Dialog constructors and native GUI properties execute against real Studio.
Keynova.settings();Keynova.addItem();Keynova.markers();Keynova.weld()
for name,d in pairs(state.dialogs)do d:Destroy();state.dialogs[name]=nil end
local lastArm;for _,t in ipairs(state.project.tracks)do if t.name=="Right Arm"then lastArm=t end end
Keynova.choose(lastArm);state.selected={{trackId=lastArm.id,keyId=lastArm.keys[1].id}}
Keynova.easing();check(state.dialogs.Easing~=nil,"Native easing window created")
for name,d in pairs(state.dialogs)do d:Destroy();state.dialogs[name]=nil end
if KEYNOVA_EDITOR_TEST then KEYNOVA_EDITOR_TEST()end
Keynova.openSaved(entry);state=Keynova.state
for _,t in ipairs(state.project.tracks)do if t.name=="Right Arm"and t.property=="Transform"then Keynova.choose(t);break end end
Keynova.seek(60);Keynova.render();workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(8,7,-14),Vector3.new(0,3.8,0))
if not KEYNOVA_PREVIEW then
 Keynova.settings();Keynova.setOnion(true);Keynova.destroy();Keynova.destroy()
 check(Keynova.widget.Parent==nil and next(state.dialogs)==nil and rt.onionFolder==nil,"Idempotent teardown removes dialogs and onion geometry")
 check(next(rt.bindings)==nil and next(rt.originals)==nil,"Teardown releases runtime bindings")
 task.wait(0.05)
end
print("KEYNOVA_NATIVE_SMOKE_PASS "..count.." integration checks")
