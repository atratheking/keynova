-- Real editor commands exercise the same owners as native buttons/menus.
local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local function command(menu,name)
 for _,row in ipairs(Keynova.commands[menu])do if row.name==name then return row.run()end end
 error("Missing command: "..menu.." / "..name)
end
local fixture=Instance.new("Folder");fixture.Name="EditorParityFixture";fixture.Parent=workspace
local prop=Instance.new("Part");prop.Name="Editable";prop.Anchored=true;prop.Parent=fixture
Keynova.newFile("Editor parity")
local state,rt=Keynova.state,Keynova.runtime;state.project.duration=120
local item=rt:addObject(state.project,prop,{"Anchored","Transparency","CFrame"},true)
local tracks={};for _,track in ipairs(state.project.tracks)do tracks[track.property]=track end
Keynova.choose(tracks.Anchored);Keynova.addKey(false)
check(prop.Anchored==false and tracks.Anchored.keys[1].value==false,"Editor inserts explicit false rather than current true")
Keynova.choose(tracks.Transparency)
local a=Engine.insert(tracks.Transparency,10,0.1);local b=Engine.insert(tracks.Transparency,20,0.2)
state.frame=50;state.selected={{trackId=tracks.Transparency.id,keyId=a.id},{trackId=tracks.Transparency.id,keyId=b.id}}
Keynova.editValue(0.6,state.selected)
tracks={};for _,track in ipairs(state.project.tracks)do tracks[track.property]=track end
a,b=tracks.Transparency.keys[1],tracks.Transparency.keys[2]
check(#tracks.Transparency.keys==2 and a.frame==10 and b.frame==20 and a.value==0.6 and b.value==0.6,"Value editing updates selected keys without inserting at playhead")
check(math.abs(prop.Transparency-0.6)<0.001,"Selected value edit applies viewport immediately")
a.locked=true;Keynova.editValue(0.9,state.selected)
tracks={};for _,track in ipairs(state.project.tracks)do tracks[track.property]=track end
a,b=tracks.Transparency.keys[1],tracks.Transparency.keys[2]
check(a.locked and a.value==0.6 and b.value==0.9,"Multi-value edit preserves locked key")
a.locked=false;state.selected={{trackId=tracks.Transparency.id,keyId=a.id},{trackId=tracks.Transparency.id,keyId=b.id}}
Keynova.groupKeys(false)
check(a.group and a.group==b.group,"Group assigns range identity")
state.selected={};Keynova.selectKey(tracks.Transparency,a,false)
check(#state.selected==2,"Selecting a group selects every member")
Keynova.selectKey(tracks.Transparency,a,true)
check(#state.selected==0,"Shift-selecting selected group deselects every member")
Keynova.selectRange(9,11,{[tracks.Transparency.id]=true},false)
check(#state.selected==2,"Range selection expands touched groups")
Keynova.groupKeys(true)
check(not a.group and not b.group,"Ungroup remains functional after range selection")
Keynova.selectRange(0,120,nil,false);command("Keyframe","Lock / Unlock")
check(a.locked and b.locked,"Lock command protects selected keys")
command("Keyframe","Lock / Unlock");check(not a.locked and not b.locked,"Unlock command restores editing")
Keynova.choose(tracks.Transparency);state.selected={{trackId=tracks.Transparency.id,keyId=a.id},{trackId=tracks.Transparency.id,keyId=b.id}}
command("Keyframe","Reverse Frames")
tracks={};for _,track in ipairs(state.project.tracks)do tracks[track.property]=track end
check(tracks.Transparency.keys[1].value==0.9 and tracks.Transparency.keys[2].value==0.6,"Reverse menu uses transactional engine operation")
Keynova.seek(10);Keynova.setOnion(true);local snapshot=prop.Transparency
Keynova.seek(40);Keynova.applyOnion()
local at40=nil;for _,key in ipairs(tracks.Transparency.keys)do if key.frame==40 then at40=key end end
check(at40 and math.abs(at40.value-snapshot)<0.001,"Apply Onion creates actual property keyframes")
Keynova.editItem();check(state.dialogs.Add~=nil,"Edit Item is reachable through editor command")
state.dialogs.Add:Destroy();state.dialogs.Add=nil
Keynova.theme();Keynova.gizmoSettings();Keynova.fileExplorer()
check(state.dialogs.Theme and state.dialogs.Gizmo and state.dialogs.Files,"Native theme gizmo and file dialogs construct")
for name,dialog in pairs(state.dialogs)do dialog:Destroy();state.dialogs[name]=nil end
local originalSeconds=state.showSeconds;command("Options","Show Seconds")
check(state.showSeconds~=originalSeconds,"Show Seconds option is functional")
command("Options","Show Seconds")
local originalDepth=state.alwaysOnTop;command("Gizmos","Not Always On Top")
check(state.alwaysOnTop~=originalDepth,"Gizmo depth toggle changes rendering option")
command("Gizmos","Not Always On Top")
local originalIncrement=state.increment;command("Gizmos","Use Increment")
check(state.increment~=originalIncrement,"Gizmo increment toggle is functional")
command("Gizmos","Use Increment")
local event=Engine.insert(tracks.Event,0,"Pulse");event.duration=10;event.eventValue="test"
event.codeBegin='parent:SetAttribute("PreviewBegin",(parent:GetAttribute("PreviewBegin")or 0)+1)'
event.codeEnd='parent:SetAttribute("PreviewEnd",(parent:GetAttribute("PreviewEnd")or 0)+1)'
state.runEventCode=false;Keynova.previewEvent("Begin",tracks.Event,event,prop)
check(prop:GetAttribute("PreviewBegin")==nil,"Preview never executes authored code by default")
Keynova.previewEvent("End",tracks.Event,event,prop);state.runEventCode=true
Keynova.seek(0);state.speed=1;Keynova.play();Keynova.play()
check(prop:GetAttribute("PreviewBegin")==1,"Opted-in preview executes authored Begin with same parent context as export")
Keynova.play();Keynova.play()
check(prop:GetAttribute("PreviewBegin")==1,"Pause/resume does not duplicate current-frame Begin")
Keynova.advance(0.2)
check(prop:GetAttribute("PreviewEnd")==1,"Crossing event duration executes End once")
Keynova.choose(tracks.Event);Keynova.event();check(state.dialogs.Event~=nil,"Full Event editor constructs")
state.dialogs.Event:Destroy();state.dialogs.Event=nil
local emitter=Instance.new("ParticleEmitter");emitter.Parent=prop
local emitterItem=rt:addObject(state.project,emitter,{})
local action=rt:addProperty(state.project,emitterItem,"Action");Keynova.choose(action);Keynova.action()
check(state.dialogs.Action~=nil,"Whitelisted action editor constructs")
state.dialogs.Action:Destroy();state.dialogs.Action=nil
state.runEventCode=false;state.playing=false;Keynova.seek(60);Keynova.play();Keynova.hideUI();task.wait(0.08)
check(not Keynova.widget.Enabled and state.playing and state.frame>60,"Hide UI keeps native viewport playback running")
Keynova.showUI();Keynova.play();check(Keynova.widget.Enabled and not state.uiHidden,"Showing UI returns editor focus")
Keynova.setOnion(true);Keynova.closeFile()
check(not state.editing and rt.onionFolder==nil,"Close File restores preview and removes onion geometry")
fixture:Destroy()
-- Completed production-boundary workload: reopen a 4000-key editable save and render.
local perfPart=Instance.new("Part");perfPart.Name="KeynovaPerformanceTarget";perfPart.Anchored=true;perfPart.Parent=workspace
local perf=Engine.newProject("Long timeline");perf.duration=4000
local perfItem={id="perf-item",name=perfPart.Name,type="Part",path=Runtime.path(perfPart),expanded=true,propertiesExpanded=true};perf.items={perfItem}
local perfTrack=Engine.newTrack(perfItem.id,"CFrame","CFrame","CFrame");perfTrack.rest=Engine.encode(perfPart.CFrame,"CFrame");perf.tracks={perfTrack}
for frame=0,3999 do perfTrack.keys[frame+1]={id="perf-key-"..frame,frame=frame,value=Engine.encode(CFrame.new(frame/100,0,0),"CFrame"),easing="Linear",direction="InOut"}end
local perfSave=Instance.new("StringValue");perfSave.Name="KeynovaPerformanceSave";perfSave.Value="";perfSave.Parent=game:GetService("ServerStorage")
local short=Engine.clone(perf);short.duration=1000;short.tracks[1].keys={};for i=1,1000 do short.tracks[1].keys[i]=perfTrack.keys[i]end
local shortSave=Instance.new("StringValue");shortSave.Value=game:GetService("HttpService"):JSONEncode(short);shortSave.Parent=game:GetService("ServerStorage")
local shortRef=Instance.new("ObjectValue");shortRef.Name=perfItem.id;shortRef.Value=perfPart;shortRef.Parent=shortSave
local shortStarted=os.clock();Keynova.openSaved(shortSave);local shortElapsed=os.clock()-shortStarted
print(string.format("KEYNOVA_PERF_COMPARABLE keys=1000 seconds=%.6f guiInstances=%d",shortElapsed,#Keynova.widget:GetDescendants()))
shortSave:Destroy()
local perfRefs=Instance.new("Folder");local ref=Instance.new("ObjectValue");ref.Name=perfItem.id;ref.Value=perfPart;ref.Parent=perfRefs
local saved,saveError=Saves.write(perfSave,perf,perfRefs);assert(saved,saveError)
local started=os.clock();Keynova.openSaved(perfSave);local elapsed=os.clock()-started
local instances=#Keynova.widget:GetDescendants()
check(instances<4000,"Long timeline renders a bounded visible window instead of allocating one GUI per saved key")
print(string.format("KEYNOVA_PERF_OPEN keys=4000 seconds=%.6f guiInstances=%d",elapsed,instances))
local exported=Keynova.exportFiles();check(exported and exported:IsA("Folder"),"Long timelines also export without overflowing a StringValue")
local decoded=exported and require(exported.ReadMetadata)()
check(decoded and #decoded.tracks[1].keys==4000,"Exported metadata reader recovers every key from checked chunks")
exported:Destroy();Keynova.closeFile();perfSave:Destroy();perfPart:Destroy()
print("KEYNOVA_EDITOR_PARITY_PASS "..checks.." checks")
