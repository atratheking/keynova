-- Native runtime integration suite is expanded with the property and rig owner.
local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local folder=Instance.new("Folder");folder.Name="KeynovaRuntimeFixture";folder.Parent=workspace
local model=Instance.new("Model");model.Name="BoneRig";model.Parent=folder
local mesh=Instance.new("MeshPart");mesh.Name="Mesh";mesh.Anchored=true;mesh.Parent=model
local bone=Instance.new("Bone");bone.Name="RootBone";bone.Transform=CFrame.new(0,1,0);bone.Parent=mesh
local child=Instance.new("Bone");child.Name="ChildBone";child.Parent=bone
local rt=Runtime.new();local project=Engine.newProject("Advanced native tracks");local item,reason=rt:addRig(project,model)
check(item~=nil,reason or"Bone-only rig added");check(#project.tracks==2,"Both bone tracks bound")
local first=project.tracks[1];Engine.insert(first,0,CFrame.new(2,0,0));rt:apply(project,0)
check(rt.bindings[first.id].instance.Transform==rt.bindings[first.id].base*CFrame.new(2,0,0),"Bone relative pose applied")
rt:restore();check(bone.Transform==CFrame.new(0,1,0),"Bone rest restored")
local emitter=Instance.new("ParticleEmitter");emitter.Parent=mesh
local names=Runtime.properties(emitter);check(table.find(names,"Color")and table.find(names,"Size")and table.find(names,"SpreadAngle"),"Particle property catalog")
local effect=rt:addObject(project,emitter,{"Color","Size","Speed","SpreadAngle","Enabled"});check(effect~=nil,"Composite particle item added")
for _,track in ipairs(project.tracks)do if track.itemId==effect.id then
 local goal=track.property=="Color"and ColorSequence.new(Color3.new(1,0,0))or track.property=="Size"and NumberSequence.new(3)or track.property=="Speed"and NumberRange.new(4,8)or track.property=="SpreadAngle"and Vector2.new(15,30)or false
 Engine.insert(track,0,goal)
end end
rt:apply(project,0);check(emitter.Color.Keypoints[1].Value==Color3.new(1,0,0),"ColorSequence applied")
check(emitter.Size.Keypoints[1].Value==3 and emitter.Speed.Min==4 and emitter.SpreadAngle.X==15,"Composite particle values applied")
check(emitter.Enabled==false,"Boolean false is preserved")
local face=Instance.new("Decal");face.Name="face";face.Texture="rbxassetid://1";face.Parent=mesh
local faceItem=rt:addObject(project,face,{"Texture","Transparency"});check(faceItem~=nil,"Decal face item added")
for _,track in ipairs(project.tracks)do if track.itemId==faceItem.id and track.property=="Texture"then Engine.insert(track,0,"rbxassetid://2")end end
rt:apply(project,0);check(face.Texture=="rbxassetid://2","Face texture changed")
local controls=Instance.new("FaceControls");controls.Parent=mesh
local controlNames=Runtime.properties(controls);check(table.find(controlNames,"JawDrop")~=nil,"Reflection discovers facial channels")
local controlItem=rt:addObject(project,controls,{"JawDrop"});for _,track in ipairs(project.tracks)do if track.itemId==controlItem.id then Engine.insert(track,0,0.6)end end
rt:apply(project,0);check(math.abs(controls.JawDrop-0.6)<0.001,"Facial channel posed")
local attachment=Instance.new("Part");attachment.Name="Dot.Target";attachment.Anchored=true;attachment.CFrame=CFrame.new(3,0,0);attachment.Parent=folder
local camera=Instance.new("Camera");camera.CFrame=CFrame.new(3,5,10);camera.Parent=folder
local ci=rt:addObject(project,camera,{"CFrame","AttachToPart"});local attachTrack,cfTrack
for _,track in ipairs(project.tracks)do if track.itemId==ci.id then if track.property=="AttachToPart"then attachTrack=track else cfTrack=track end end end
Engine.insert(cfTrack,0,camera.CFrame);local key=Engine.insert(attachTrack,0,attachment:GetFullName());rt:setReference(attachTrack,key,attachment)
attachment.Name="Renamed";attachment.CFrame=CFrame.new(13,0,0);rt:apply(project,60)
check(math.abs(camera.CFrame.X-13)<0.001,"Attachment follows renamed dot-containing target")
local direct=camera.CFrame;rt:apply(project,0);rt:apply(project,60);check(camera.CFrame==direct,"Attachment seek is deterministic")
local refs=Instance.new("Folder");for id,target in pairs(rt.objects)do local ref=Instance.new("ObjectValue");ref.Name=id;ref.Value=target;ref.Parent=refs end
for id,binding in pairs(rt.bindings)do local ref=Instance.new("ObjectValue");ref.Name="Track_"..id;ref.Value=binding.instance;ref.Parent=refs end
for id,target in pairs(rt.referenceMap)do local ref=Instance.new("ObjectValue");ref.Name="Key_"..id;ref.Value=target;ref.Parent=refs end
local bound=rt.bindings[first.id].instance;bound.Name="ChangedBone";rt:load(project,refs);check(rt.bindings[first.id].instance==bound,"Track ObjectValue preserves renamed bone identity")
rt:onion(project,0,60);local selection=rt:applyOnion(project,30,item.id);check(selection and #selection==2,"Onion application inserts real rig poses")
rt:clearOnion();check(rt.onionFolder==nil,"Advanced onion cleanup")
check(Runtime.resolve({"bad"})==nil,"Malformed path is rejected at runtime boundary")
local appearance=Instance.new("Model");appearance.Name="Appearance";appearance.Parent=folder
local red=Instance.new("Part");red.Color=Color3.new(1,0,0);red.Parent=appearance
local blue=Instance.new("Part");blue.Color=Color3.new(0,0,1);blue.Parent=appearance
local appearanceItem=rt:addObject(project,appearance,{"Color"});local appearanceTrack
for _,track in ipairs(project.tracks)do if track.itemId==appearanceItem.id then appearanceTrack=track end end
rt:apply(project,0);check(red.Color==Color3.new(1,0,0)and blue.Color==Color3.new(0,0,1),"Unkeyed Model appearance preserves different descendant originals")
Engine.insert(appearanceTrack,0,Color3.new(0,1,0));rt:apply(project,0);rt:refreshReferences(project)
check(#appearanceTrack.restTargets==2,"Editable save records per-descendant appearance rest values")
local appearanceRefs=Instance.new("Folder")
for id,target in pairs(rt.objects)do local ref=Instance.new("ObjectValue");ref.Name=id;ref.Value=target;ref.Parent=appearanceRefs end
for id,targets in pairs(rt.restMap)do for i,target in pairs(targets)do local ref=Instance.new("ObjectValue");ref.Name="Rest_"..id.."_"..i;ref.Value=target;ref.Parent=appearanceRefs end end
blue.Name="Renamed Blue";local cold=Runtime.new();cold:load(Engine.clone(project),appearanceRefs);cold:restore()
check(red.Color==Color3.new(1,0,0)and blue.Color==Color3.new(0,0,1),"Cold reopen restores heterogeneous appearance through stable live references")
cold:destroy();appearanceRefs:Destroy()
appearanceTrack.enabled=false;rt:apply(project,0)
check(red.Color==Color3.new(1,0,0)and blue.Color==Color3.new(0,0,1),"Disabled Model appearance restores heterogeneous originals")
local weldBase=Instance.new("Part");weldBase.Name="WeldBase";weldBase.Anchored=true;weldBase.Parent=folder
local weldProp=Instance.new("Part");weldProp.Name="WeldProp";weldProp.CFrame=CFrame.new(5,2,1);weldProp.Parent=folder
local priorSelection=game:GetService("Selection"):Get();game:GetService("Selection"):Set({weldBase,weldProp})
local beforeWeld=weldProp.CFrame;local joined=rt:weld(true,"Motor6D")
check(joined and weldProp.CFrame==beforeWeld and weldBase:FindFirstChild("KeynovaJoint"):IsA("Motor6D"),"Easy Weld creates animatable Motor6D while preserving world pose")
local rejected=rt:weld(true,"Motor6D");check(not rejected,"Easy Weld rejects conflicting animation joints before mutation")
weldBase.KeynovaJoint:Destroy()
local static=Instance.new("Model");static.Name="StaticModel";static.Parent=folder
local a=Instance.new("Part");a.Name="Base";a.Anchored=true;a.Parent=static;static.PrimaryPart=a
local b=Instance.new("Part");b.Name="Detail";b.Position=Vector3.new(2,0,0);b.Parent=static
local c=Instance.new("Part");c.Name="Detail2";c.Position=Vector3.new(0,2,0);c.Parent=static
local oldB=b.CFrame;game:GetService("Selection"):Set({static});local modelWelded=rt:weld(true,"Weld")
check(modelWelded and #a:GetChildren()==2 and b.CFrame==oldB,"Easy Weld handles selected Models and retains component geometry")
game:GetService("Selection"):Set(priorSelection)
rt:destroy();rt:destroy();refs:Destroy();folder:Destroy()
print("KEYNOVA_RUNTIME_PARITY_PASS "..checks.." checks")
