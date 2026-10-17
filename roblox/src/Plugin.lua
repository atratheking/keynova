assert(plugin,"Keynova must run as a Studio plugin")
local Http=game:GetService("HttpService")
local Selection=game:GetService("Selection")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local Storage=game:GetService("ServerStorage")
local CoreGui=game:GetService("CoreGui")
local make,label,button,field=Gui.make,Gui.label,Gui.button,Gui.field
local C=Gui.colors
local toolbar=plugin:CreateToolbar("Keynova")
local toggle=toolbar:CreateButton("KeynovaMain","Keynova animation editor",Brand.spec.toolbarAssetId and("rbxassetid://"..Brand.spec.toolbarAssetId)or"rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Animation.png","Keynova")
local characterToggle=toolbar:CreateButton("KeynovaCharacters","Character Inserter","rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/HumanoidDescription.png","Character Inserter")
local weldToggle=toolbar:CreateButton("KeynovaWeld","Easy Weld","rbxasset://studio_svg_textures/Shared/InsertableObjects/Dark/Standard/Weld.png","Easy Weld")
toggle.ClickableWhenViewportHidden=true
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,false,false,532,306,420,180)
local widget=plugin:CreateDockWidgetPluginGuiAsync("KeynovaTimelineV2",info)
widget.Title="Keynova";widget.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local root=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BorderColor3=C.border,BorderSizePixel=1},widget)
local runtime=Runtime.new()
local state={project=Engine.newProject("Untitled"),editing=false,frame=0,playing=false,px=1.25,left=196,selected={},activeTrack=nil,activeItem=nil,dirty=false,undo={},redo={},clipboard=nil,mode="Rotate",onion=false,drag=nil,dialogs={},dialogIndex=0,focused=false,updating=false,launcherGroup=false,launcherRig=false,clickTimes={},speed=1,showSeconds=false,useLastEase=false,easingColors=false,hideColumns=false,handlesVisible=true,world=false,increment=false,translationStep=0.1,rotationStep=5,constantSize=true,alwaysOnTop=true,showOrigin=false,handleSize=1,runEventCode=false,eventModules={},activeEvents={},includeCurrent=true}
local api={state=state,runtime=runtime,widget=widget}
local preferenceKeys={"showSeconds","useLastEase","easingColors","hideColumns","handlesVisible","world","increment","translationStep","rotationStep","constantSize","alwaysOnTop","showOrigin","handleSize"}
local okPreferences,preferences=pcall(function()return plugin:GetSetting("KeynovaPreferencesV1")end)
if okPreferences and type(preferences)=="table"then
 for _,name in ipairs(preferenceKeys)do if type(preferences[name])==type(state[name])then state[name]=preferences[name]end end
 if preferences.theme then
  local oldDefault={background={32,32,32},panel={41,41,41},title={106,111,115},border={115,119,121},text={204,210,213},muted={143,149,152},accent={194,122,53},cyan={72,162,195},key={214,145,58}}
  local legacyDefault=true
  for name,channels in pairs(oldDefault)do local value=preferences.theme[name];for i=1,3 do if type(value)~="table"or value[i]~=channels[i]then legacyDefault=false end end end
  for name in pairs(preferences.theme)do if not oldDefault[name]then legacyDefault=false end end
  if legacyDefault then Gui.theme("Default")else Gui.importTheme(preferences.theme)end
 end
end
local function savePreferences()
 local data={theme=Gui.exportTheme()};for _,name in ipairs(preferenceKeys)do data[name]=state[name]end
 pcall(function()plugin:SetSetting("KeynovaPreferencesV1",data)end)
end
local render,paint,menu,addDialog,easingDialog,settingsDialog,markersDialog,importDialog,charactersDialog,weldDialog,saveAsDialog,transformDialog,eventDialog,actionDialog,themeDialog,gizmoDialog,fileDialog,rebindDialog,addKey,gizmo,guard,clearEventModules
local rowLabels,grid,scroll,head,timeLabel,countLabel,notification,dropdown
local connections={}
local function connect(signal,callback)local c=signal:Connect(callback);table.insert(connections,c);return c end
local function findTrack(id)for _,t in ipairs(state.project.tracks) do if t.id==id then return t end end end
local function findItem(id)for _,item in ipairs(state.project.items) do if item.id==id then return item end end end
local function activeTrack()return findTrack(state.activeTrack)end
local function activeItem()local t=activeTrack();return findItem((t and t.itemId)or state.activeItem)end
local function message(text)
 if notification then notification:Destroy() end
 if text and text~="" then
  notification=label(root,text,5,root.AbsoluteSize.Y-24,root.AbsoluteSize.X-10,20,{color=C.cyan,size=12})
  notification.BackgroundTransparency=0;notification.BackgroundColor3=C.background;notification.ZIndex=90
  local current=notification;task.delay(5,function()if notification==current then current:Destroy();notification=nil end end)
 end
end
local function checkpoint()
 table.insert(state.undo,Engine.clone(state.project));if #state.undo>60 then table.remove(state.undo,1)end;state.redo={};state.dirty=true
end
local function references()
 local folder=Instance.new("Folder")
 for id,object in pairs(runtime.objects)do if object.Parent then local value=Instance.new("ObjectValue");value.Name=id;value.Value=object;value.Parent=folder end end
 for id,binding in pairs(runtime.bindings)do if binding.instance.Parent then local value=Instance.new("ObjectValue");value.Name="Track_"..id;value.Value=binding.instance;value.Parent=folder end end
 for id,targets in pairs(runtime.restMap or{})do for i,object in pairs(targets)do if object.Parent then local value=Instance.new("ObjectValue");value.Name="Rest_"..id.."_"..i;value.Value=object;value.Parent=folder end end end
 for id,object in pairs(runtime.referenceMap or{})do if object.Parent then local value=Instance.new("ObjectValue");value.Name="Key_"..id;value.Value=object;value.Parent=folder end end
 return folder
end
local function changeProject(project,suppliedReferences)
 if gizmo then gizmo:cancel()end
 local refs=suppliedReferences or references();state.project=project;local missing=runtime:load(project,refs);refs:Destroy()
 state.frame=math.min(state.frame,project.duration);state.selected={};state.playing=false
 if not findTrack(state.activeTrack) then state.activeTrack=project.tracks[1] and project.tracks[1].id end
 if not findItem(state.activeItem) then state.activeItem=project.items[1] and project.items[1].id end
 runtime:apply(project,state.frame);render()
 if #missing>0 then message("Missing instances: "..table.concat(missing,", "))end
end
local function undo()
 if #state.undo==0 then return end
 table.insert(state.redo,Engine.clone(state.project));local p=table.remove(state.undo);state.dirty=true;changeProject(p)
end
local function redo()
 if #state.redo==0 then return end
 table.insert(state.undo,Engine.clone(state.project));local p=table.remove(state.redo);state.dirty=true;changeProject(p)
end
local function closeDialog(name)
 local d=state.dialogs[name];if d then d:Destroy();state.dialogs[name]=nil end
end
local function dialog(name,title,w,h)
 closeDialog(name);state.dialogIndex=state.dialogIndex+1
 local d,body=Gui.dialog(plugin,"Keynova_"..name..state.dialogIndex,title,w,h)
 state.dialogs[name]=d;return d,body
end
local function selectedKeys()
 local list={}
 for _,ref in ipairs(state.selected)do local t=findTrack(ref.trackId);if t then for _,key in ipairs(t.keys)do if key.id==ref.keyId then table.insert(list,{track=t,key=key})end end end end
 return list
end
local function selectedCurrent()
 if #state.selected>0 then return state.selected end
 local track=activeTrack();if track then for _,key in ipairs(track.keys)do if key.frame==math.floor(state.frame+0.5)then return {{trackId=track.id,keyId=key.id}}end end end
 return {}
end
gizmo=Gizmo.new(plugin,function(value)
 local track=activeTrack();if track and gizmo.track and track.id==gizmo.track.id then addKey(value)end
end)
local function updateHandles()
 if gizmo.Dragging then return end
 local track=activeTrack();local binding=track and runtime.bindings[track.id]
 local enabled=widget.Enabled and state.editing and not state.playing and not RunService:IsRunning()and track and not track.locked and track.valueType=="CFrame"and state.handlesVisible
 if not enabled or not binding then return gizmo:clear()end
 local value=Engine.sample(track,state.frame);if value==nil then value=runtime:read(track)end
 if typeof(value)~="CFrame"then return gizmo:clear()end
 gizmo:set(binding,track,value,state.mode,{enabled=true,world=state.world,increment=state.increment,translationStep=state.translationStep,rotationStep=state.rotationStep,constantSize=state.constantSize,alwaysOnTop=state.alwaysOnTop,showOrigin=state.showOrigin,size=state.handleSize})
end
local function seek(at)
 gizmo:cancel();state.includeCurrent=true
 state.playing=false;runtime:pauseActions();state.frame=math.clamp(at,0,state.project.duration);runtime:apply(state.project,state.frame);paint();updateHandles()
end
local function choose(track)
 gizmo:cancel()
 state.activeTrack=track.id;state.activeItem=track.itemId;updateHandles()
end
local function groupFrames(project,itemId,onlyFrame)
 local groups={};local rangeGroup=onlyFrame==nil and Http:GenerateGUID(false)or nil
 for _,track in ipairs(project.tracks)do if not track.locked and(not itemId or track.itemId==itemId or track.rigItemId==itemId)then
  for _,key in ipairs(track.keys)do if not key.locked and(onlyFrame==nil or key.frame==onlyFrame)then
   groups[key.frame]=groups[key.frame]or Http:GenerateGUID(false);key.group=rangeGroup or groups[key.frame]
  end end
 end end
end
addKey=function(value)
 local track=activeTrack();if not track then return message("Select an item property or rig joint first.")end
 if track.locked then return message("This track is locked.")end
 if value==nil then value=runtime:read(track)end;if value==nil then return message("The original instance is missing.")end
 checkpoint();state.frame=math.floor(state.frame+0.5)
 local insertOK,key=pcall(Engine.insert,track,state.frame,value,state.useLastEase and state.lastEase or nil,state.useLastEase and state.lastDirection or nil,state.useLastEase and state.lastParameters or nil)
 if not insertOK then table.remove(state.undo);return message(tostring(key))end;key.nativeWeight=nil;if state.project.groupKeyframes then groupFrames(state.project,track.itemId,state.frame)end;state.selected={{trackId=track.id,keyId=key.id}}
 runtime:apply(state.project,state.frame);render()
end
local function deleteKeys()
 local refs=selectedCurrent();if #refs==0 then return end;checkpoint()
 for _,ref in ipairs(refs)do local t=findTrack(ref.trackId);if t and not t.locked then for i=#t.keys,1,-1 do if t.keys[i].id==ref.keyId and not t.keys[i].locked then table.remove(t.keys,i)end end end end
 state.selected={};runtime:apply(state.project,state.frame);render()
end
local function copyKeys(cut)
 runtime:refreshReferences(state.project)
 local refs=selectedCurrent();state.clipboard=Engine.copy(state.project,refs)
 if cut then deleteKeys()else message("Copied selected keyframes.")end
end
local function pasteKeys(intoTrack)
 if not state.clipboard then return end
 for _,track in ipairs(state.clipboard.tracks)do for _,key in ipairs(track.keys)do local target=runtime.referenceMap[key.id];if target and target.Parent then key.targetPath=Runtime.path(target);key.value=target:GetFullName()end end end
 checkpoint();local refs,err=Engine.paste(state.project,state.clipboard,math.floor(state.frame+0.5),intoTrack and state.activeTrack or nil)
 state.selected=refs or {};runtime:apply(state.project,state.frame);render();if err then message(err)end
end
local function jump(nextKey)
 local at=nextKey and state.project.duration or 0
 for _,t in ipairs(state.project.tracks)do for _,key in ipairs(t.keys)do
  if nextKey and key.frame>state.frame+0.01 and key.frame<at then at=key.frame
  elseif not nextKey and key.frame<state.frame-0.01 and key.frame>at then at=key.frame end
 end end;seek(at)
end
local function play()
 gizmo:cancel()
 if not state.editing then return end
 if not state.playing and state.speed>=0 and state.frame>=state.project.duration then state.frame=0;state.includeCurrent=true elseif not state.playing and state.speed<0 and state.frame<=0 then state.frame=state.project.duration end
 state.playing=not state.playing;if state.playing then runtime:resumeActions()else runtime:pauseActions()end;if state.playing and state.speed>=0 and state.includeCurrent then runtime:crossings(state.project,state.frame,state.frame,true,api.previewEvent);state.includeCurrent=false end;paint();updateHandles()
end
local function save()
 if not state.editing then return end
 local owner=Storage;local folderName="KeynovaSaves"
 if state.project.rigItemId then
  owner=runtime.objects[state.project.rigItemId];folderName="AnimSaves"
  if not owner or not owner.Parent or not owner:IsA("Model")then return message("The rig for this file is missing. Rebind it before saving.")end
 end
 local folder=owner:FindFirstChild(folderName)or make("Folder",{Name=folderName},owner)
 local entry=nil
 if state.savedEntry and state.savedEntry.Parent==folder then entry=state.savedEntry end
 if not entry then entry=make("StringValue",{Name=state.project.name},folder);state.savedEntry=entry end
 runtime:refreshReferences(state.project)
 local ok,reason=Saves.write(entry,state.project,references())
 if not ok then if entry.Value==""then entry:Destroy();state.savedEntry=nil end;return message(reason)end
 entry.Name=state.project.name
 state.dirty=false;paint();message("Saved to "..folder:GetFullName()..".");return true
end
local function openSaved(entry)
 local p,refs=Saves.read(entry)
 if not p then return message(refs)end
 local valid,err=Engine.validate(p);if not valid then return message(err)end
 if clearEventModules then clearEventModules()end;state.runEventCode=false;state.includeCurrent=true
 runtime:restore();local missing=runtime:load(p,refs);state.project=p;state.frame=0;state.selected={};state.undo={};state.redo={};state.savedEntry=entry;state.editing=true;state.dirty=false;state.activeItem=p.items[1]and p.items[1].id;state.activeTrack=p.tracks[1]and p.tracks[1].id
 runtime:apply(p,0);render();if #missing>0 then message("Missing instances: "..table.concat(missing,", "))end
end
local function newFile(name)
 if clearEventModules then clearEventModules()end;state.runEventCode=false;state.includeCurrent=true
 gizmo:clear()
 runtime:destroy();state.project=Engine.newProject(name or "Untitled");state.editing=true;state.frame=0;state.selected={};state.undo={};state.redo={};state.savedEntry=nil;state.activeTrack=nil;state.activeItem=nil;state.dirty=false;state.playing=false;render()
end
local function exportRig()
 local item=activeItem();if not item or item.type~="Rig" then for _,v in ipairs(state.project.items)do if v.type=="Rig"then item=v;break end end end
 if not item or item.type~="Rig"then return message("Select a rig item to export.")end
 local ok,result=pcall(function()return Export.rig(state.project,item,runtime.bindings)end)
 if not ok then return message(tostring(result))end
 local target=runtime.objects[item.id];if not target then return message("The rig is missing.")end
 local folder=target:FindFirstChild("AnimSaves")or make("Folder",{Name="AnimSaves"},target)
 result.Parent=folder;Selection:Set({result});message("Saved KeyframeSequence in the rig's AnimSaves. Right-click → Save to Roblox.")
end
local function exportAllRigs()
 local results={}
 local ok,reason=pcall(function()
  for _,item in ipairs(state.project.items)do if item.type=="Rig"then
   local keyed=false;for _,track in ipairs(state.project.tracks)do if track.itemId==item.id and track.property=="Transform"and #track.keys>0 and track.enabled~=false then keyed=true end end
   if keyed then local target=runtime.objects[item.id];assert(target and target.Parent,"A rig is missing: "..item.name);table.insert(results,{target=target,sequence=Export.rig(state.project,item,runtime.bindings)})end
  end end
 end)
 if not ok then for _,entry in ipairs(results)do entry.sequence:Destroy()end;return message(tostring(reason))end
 if #results==0 then return message("Add rig keys before exporting.")end
 local selection={};for _,entry in ipairs(results)do
  local folder=entry.target:FindFirstChild("AnimSaves")or make("Folder",{Name="AnimSaves"},entry.target);entry.sequence.Parent=folder;table.insert(selection,entry.sequence)
 end
 Selection:Set(selection);message("Exported "..#selection.." rig animation(s) to AnimSaves.")
end

local function exportScene()
 local ok,result=pcall(function()return Export.sceneModule(state.project,runtime.bindings,state.cameraReference)end)
 if not ok then return message(tostring(result))end
 local folder=Storage:FindFirstChild("KeynovaExports")or make("Folder",{Name="KeynovaExports"},Storage)
 result.Parent=folder;Selection:Set({result});message("Exported scene playback ModuleScript to ServerStorage.KeynovaExports.")
end
local function removeItem()
 local item=activeItem();if not item then return end
 checkpoint();local p=Engine.clone(state.project)
 if p.rigItemId==item.id then p.rigItemId=nil;state.savedEntry=nil end
 for i=#p.tracks,1,-1 do if p.tracks[i].itemId==item.id then table.remove(p.tracks,i)end end
 for i=#p.items,1,-1 do if p.items[i].id==item.id or p.items[i].rigItemId==item.id then table.remove(p.items,i)end end
 changeProject(p)
end
local function focusItem()
 local item=activeItem();local target=item and runtime.objects[item.id]
 if target then Selection:Set({target});local camera=workspace.CurrentCamera
  local cf=target:IsA("Model")and target:GetPivot()or target:IsA("BasePart")and target.CFrame
  if cf then camera.CFrame=CFrame.lookAt(cf.Position+Vector3.new(7,4,10),cf.Position)end
 end
end
local function reflect()
 local item=activeItem();if not item or item.type~="Rig"then return message("Select a rig item.")end
 local snapshots={};for _,track in ipairs(state.project.tracks)do if track.itemId==item.id and track.property=="Transform"then snapshots[track.name]=Engine.clone(track.keys)end end
 checkpoint()
 for _,track in ipairs(state.project.tracks)do if track.itemId==item.id and track.property=="Transform"and not track.locked then
  local locked=false;for _,key in ipairs(track.keys)do if key.locked then locked=true end end
  if not locked then
   local mirrored=string.gsub(string.gsub(string.gsub(track.name,"Left","KEYNOVA_LEFT"),"Right","Left"),"KEYNOVA_LEFT","Right")
   local originals={};for _,key in ipairs(track.keys)do originals[key.frame]=key.id end
   local keys=Engine.clone(snapshots[mirrored]or snapshots[track.name]or{})
   for _,key in ipairs(keys)do
    local x,y,z,a,b,c,d,e,f,g,h,i=Engine.decode(key.value,"CFrame"):GetComponents()
    key.value=Engine.encode(CFrame.new(-x,y,z,a,-b,-c,-d,e,f,-g,h,i),"CFrame");key.id=originals[key.frame]or Http:GenerateGUID(false)
   end
   track.keys=keys
  end
 end end
 runtime:apply(state.project,state.frame);render()
end
local function groupKeys(ungroup)
 if #selectedKeys()==0 then return end
 local group=nil;if not ungroup then group=Http:GenerateGUID(false)end;checkpoint()
 for _,row in ipairs(selectedKeys())do if not row.track.locked and not row.key.locked then row.key.group=group end end;render()
end
local function operationDialog(kind)
 local d,b=dialog(kind,kind.." Frames",204,172)
 local amount=kind=="Stretch"and"1.5"or kind=="Repeat"and"2"or(kind=="Fill"or kind=="Split")and"1"or"10"
 label(b,kind=="Stretch"and"Multiplier"or kind=="Repeat"and"Repeats"or kind=="Fill"and"Frame step"or"Frame offset",10,10,184,20)
 local value=field(b,amount,10,35,184,24)
 local spacing=kind=="Repeat"and field(b,"30",10,88,184,24)or nil
 if spacing then label(b,"Spacing (frames)",10,62,184,20)end
 button(b,"OK",8,134,188,28,function()
  local v=tonumber(value.Text);if not v then return end
  checkpoint();local refs,err
  if kind=="Stretch"then refs,err=Engine.stretch(state.project,selectedCurrent(),v)
  elseif kind=="Repeat"then refs,err=Engine.repeatKeys(state.project,selectedCurrent(),math.max(1,math.floor(v)),tonumber(spacing.Text)or 30)
  elseif kind=="Split"then refs,err=Engine.split(state.project,selectedCurrent(),math.max(1,math.floor(v)))
  elseif kind=="Fill"then refs,err=Engine.fill(state.project,selectedCurrent(),math.max(1,math.floor(v)))
  else refs,err=Engine.retime(state.project,selectedCurrent(),math.floor(v))end
  state.selected=refs or{};closeDialog(kind);runtime:apply(state.project,state.frame);render();if err then message(err)end
 end)
end
saveAsDialog=function(isNew)
 local d,b=dialog("SaveAs",isNew and"New Keynova File"or"Save As",204,108)
 local name=field(b,state.project.name,10,16,184,25)
 button(b,"OK",10,65,184,28,function()local text=name.Text;if text==""then return end;closeDialog("SaveAs");if isNew then guard(function()newFile(text)end)else checkpoint();state.project.name=text;state.savedEntry=nil;save()end end)
end
settingsDialog=function()
 local d,b=dialog("Settings","Animation Settings",205,222)
 label(b,"Name",9,9,64,20);local name=field(b,state.project.name,75,8,119,22)
 label(b,"Timeline Size",9,38,83,20);local length=field(b,tostring(state.project.duration),97,37,97,22);local initialLength=length.Text
 label(b,"FPS",9,67,50,20);local fps=field(b,tostring(state.project.fps),97,66,97,22)
 local stretch=true;Gui.check(b,"Stretch Animation",true,10,95,180,function(v)stretch=v end)
 local loop=state.project.loop;Gui.check(b,"Loop",loop,10,119,180,function(v)loop=v end)
 label(b,"Priority",10,147,70,20)
 local priority=state.project.priority or"Action";local priorities={"Core","Idle","Movement","Action","Action2","Action3","Action4"}
 local pbutton;pbutton=button(b,priority,90,146,104,23,function()priority=priorities[(table.find(priorities,priority)or 4)%#priorities+1];pbutton.Text=priority end)
 button(b,"OK",8,183,189,28,function()
  local rate=math.max(1,math.floor(tonumber(fps.Text)or state.project.fps))
  local a,c=string.match(length.Text,"^(%d+):(%d+)$");local duration=a and(tonumber(a)*rate+tonumber(c))or tonumber(length.Text)
  if not duration then return message("Enter a frame count or seconds:frames.")end
  duration=math.clamp(math.floor(duration),1,math.floor(2147483647/30))
  local candidate=Engine.clone(state.project);local ok,reason=Engine.rescale(candidate,rate,stretch)
  if not ok then return message(reason)end
  if length.Text==initialLength and stretch and rate~=state.project.fps then duration=candidate.duration end
  for _,track in ipairs(candidate.tracks)do for _,key in ipairs(track.keys)do if key.frame>duration then return message("The new length would remove keyframes. Move or delete them first.")end end end
  for _,marker in ipairs(candidate.markers)do if marker.frame>duration then return message("The new length would remove markers.")end end
  candidate.name=name.Text~=""and name.Text or"Untitled";candidate.duration=duration;candidate.loop=loop;candidate.priority=priority
  checkpoint();closeDialog("Settings");changeProject(candidate)
 end)
end
addDialog=function(editItem,forcedTarget)
 local target=editItem and runtime.objects[editItem.id]or forcedTarget or Selection:Get()[1]
 local extraActions=target and #Runtime.actions(target)>0 and 21 or 0
 local d,b=dialog("Add",editItem and"Edit Item"or"Add Item",204,272+extraActions)
 local props,checks={},{}
 local events=false;local actions=false
 if editItem then for _,track in ipairs(state.project.tracks)do if track.itemId==editItem.id and track.property=="Event"then events=true end end end
 make("Frame",{Name="ItemPanel",Position=UDim2.fromOffset(9,9),Size=UDim2.fromOffset(186,225+extraActions),BackgroundTransparency=1,BorderColor3=C.border,BorderSizePixel=1},b)
 local itemText=label(b,"",18,10,170,18);local typeText=label(b,"",18,27,170,18)
 local box=Gui.section(b,"Properties",17,70+extraActions,170,128)
 local list=make("ScrollingFrame",{Position=UDim2.fromOffset(5,12),Size=UDim2.new(1,-10,1,-17),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,0)},box)
 local function refresh()
  Gui.clear(list);checks={};props={}
  itemText.Text="Item: "..(target and target.Name or"< none >");typeText.Text="Type: "..(target and target.ClassName or"-")
  local y=0
  if target and target:IsA("Model")then
   local hasRig=false;for _,o in ipairs(target:GetDescendants())do if o:IsA("Motor6D")or o:IsA("Bone")then hasRig=true;break end end
   if hasRig then
    props.Rig=true;Gui.check(list,"Rig",true,2,y,148,function(v)props.Rig=v end);y=y+16
   end
  end
  for _,property in ipairs(target and Runtime.properties(target)or{})do
   local checked=property=="CFrame"or property=="FieldOfView"
   if editItem then checked=false;for _,t in ipairs(state.project.tracks)do if t.itemId==editItem.id and t.property==property then checked=true end end end
   props[property]=checked;Gui.check(list,property,checked,2,y,148,function(v)props[property]=v end);y=y+16
  end
  list.CanvasSize=UDim2.fromOffset(0,y)
 end
 Gui.check(b,"Animation Events",events,17,45,170,function(v)events=v end)
 if target and #Runtime.actions(target)>0 then
  if editItem then for _,track in ipairs(state.project.tracks)do if track.itemId==editItem.id and track.property=="Action"then actions=true end end end
  Gui.check(b,"Actions",actions,17,66,170,function(v)actions=v end)
 end
 button(b,"Delete",17,208+extraActions,170,20,function()if editItem then state.activeItem=editItem.id;removeItem();closeDialog("Add")end end)
 button(b,"OK",9,244+extraActions,186,20,function()
  if not target then return end;checkpoint()
  local item,err
  local properties={};for name,checked in pairs(props)do if checked and name~="Rig"then table.insert(properties,name)end end;table.sort(properties)
  if editItem then
   item=editItem
   for _,property in ipairs(properties)do runtime:addProperty(state.project,item,property)end
   for i=#state.project.tracks,1,-1 do local t=state.project.tracks[i];if t.itemId==item.id and t.property~="Transform"and t.property~="Event"and t.property~="Action"and not props[t.property]then table.remove(state.project.tracks,i)end end
  elseif props.Rig then item,err=runtime:addRig(state.project,target);if item then for _,property in ipairs(properties)do runtime:addProperty(state.project,item,property)end end
  else item,err=runtime:addObject(state.project,target,properties,events)end
  if not item then return message(err or"Cannot add this instance.")end
  if events then local exists=false;for _,t in ipairs(state.project.tracks)do if t.itemId==item.id and t.property=="Event"then exists=true end end;if not exists then local t=Engine.newTrack(item.id,"Events","Event","string");table.insert(state.project.tracks,t);runtime.bindings[t.id]={instance=target,property="Event"}end
  elseif editItem then for i=#state.project.tracks,1,-1 do local t=state.project.tracks[i];if t.itemId==item.id and t.property=="Event"then table.remove(state.project.tracks,i)end end end
  if actions then runtime:addProperty(state.project,item,"Action")
  elseif editItem then for i=#state.project.tracks,1,-1 do local track=state.project.tracks[i];if track.itemId==item.id and track.property=="Action"then table.remove(state.project.tracks,i)end end end
  local alive={};for _,track in ipairs(state.project.tracks)do alive[track.id]=true end
  for id in pairs(runtime.bindings)do if not alive[id]then runtime.bindings[id]=nil end end
  runtime:restore();runtime:apply(state.project,state.frame)
  state.activeItem=item.id;for _,t in ipairs(state.project.tracks)do if t.itemId==item.id then state.activeTrack=t.id;break end end
  closeDialog("Add");render()
 end)
 refresh()
 local connection;connection=Selection.SelectionChanged:Connect(function()if not d.Parent then connection:Disconnect();return end;if not editItem and not forcedTarget then target=Selection:Get()[1];refresh()end end)
 d.Destroying:Connect(function()connection:Disconnect()end)
end
local function editValue(result,refs)
 refs=refs or selectedCurrent();local entries={};local candidate=Engine.clone(state.project);local wanted={}
 for _,ref in ipairs(refs)do wanted[ref.keyId]=ref.trackId end
 for _,track in ipairs(candidate.tracks)do for _,key in ipairs(track.keys)do if wanted[key.id]==track.id and not track.locked and not key.locked then table.insert(entries,{track=track,key=key})end end end
 if #refs==0 then return addKey(result)end
 if #entries==0 then return message("Selected keyframes are locked.")end
 for _,row in ipairs(entries)do
  local ok,value=pcall(function()
   local binding=runtime.bindings[row.track.id]
   if binding and row.track.property~="Event"and row.track.property~="Action"and row.track.property~="Transform"and row.track.property~="AttachToPart"and row.track.property~="LookAtPart"then Properties.validate(binding.instance,binding.property,result)end
   return Engine.encode(result,row.track.valueType)
  end)
  if not ok then return message(tostring(value))end;row.key.value=value
 end
 local valid,reason=Engine.validate(candidate);if not valid then return message(reason)end
 checkpoint();changeProject(candidate);state.selected=refs;render()
end
transformDialog=function()
 local track=activeTrack();if not track then return message("Select a track.")end
 if track.property=="Event"then return eventDialog()elseif track.property=="Action"then return actionDialog()end
 local refs=Engine.clone(selectedCurrent());local entries=selectedKeys();local value
 if #entries>0 then track=entries[1].track;value=Engine.decode(entries[1].key.value,track.valueType)else value=Engine.sample(track,state.frame)end
 if value==nil then value=runtime:read(track)end;if value==nil then return end
 local d,b=dialog("Value","Edit Keyframes - Value",242,264)
 label(b,track.name.." / "..track.property,9,8,224,23,{color=C.accent})
 local inputs={};local kind=track.valueType;local complex=false
 if kind=="CFrame"then
  local x,y,z=value:ToOrientation();local values={value.X,value.Y,value.Z,math.deg(x),math.deg(y),math.deg(z)}
  for i=1,6 do local row=math.floor((i-1)/3);local col=(i-1)%3;label(b,(row==0 and"Position "or"Rotation ")..string.sub("XYZ",col+1,col+1),9+col*76,40+row*60,72,18,{size=11});inputs[i]=field(b,string.format("%.3f",values[i]),9+col*76,61+row*60,69,23)end
 elseif kind=="Vector3"or kind=="Color3"then
  local vals=kind=="Color3"and{value.R*255,value.G*255,value.B*255}or{value.X,value.Y,value.Z}
  for i=1,3 do label(b,string.sub(kind=="Color3"and"RGB"or"XYZ",i,i),10+(i-1)*76,43,60,20);inputs[i]=field(b,string.format("%.3f",vals[i]),9+(i-1)*76,67,69,24)end
 elseif kind~="number"and kind~="boolean"and kind~="string"then
  complex=true;label(b,kind.." / JSON components",10,38,222,20)
  inputs[1]=field(b,Http:JSONEncode(Engine.encode(value,kind)),10,65,222,121,nil,{multiline=true})
 else
  label(b,"Value",10,43,220,20);inputs[1]=field(b,tostring(value),10,68,222,26)
  if track.enumType then
   local choices=Enum[track.enumType]:GetEnumItems();local choice=1
   button(b,"Next "..track.enumType,10,105,222,24,function()choice=choice%#choices+1;inputs[1].Text=choices[choice].Name end)
  elseif track.property=="AttachToPart"or track.property=="LookAtPart"then button(b,"Use selected part",10,110,222,24,function()local obj=Selection:Get()[1];if obj and obj:IsA("BasePart")then inputs[1].Text=obj:GetFullName();state.valueTarget=obj end end)end
 end
 local weight=nil
 if track.property=="Transform"or(track.rigItemId and kind=="number")then
  label(b,"Pose Weight",10,163,95,22);weight=field(b,tostring(entries[1]and entries[1].key.nativeWeight or 1),112,163,120,24)
 end
 label(b,#refs>0 and("Editing "..#refs.." selected keyframe(s)")or"Insert at the current frame",10,192,222,20,{color=C.muted,size=11})
 button(b,"OK",9,226,224,28,function()
  local result
  local ok,reason=pcall(function()
   if kind=="CFrame"then local v={};for i=1,6 do v[i]=assert(tonumber(inputs[i].Text),"Enter numeric components")end;result=CFrame.new(v[1],v[2],v[3])*CFrame.Angles(math.rad(v[4]),math.rad(v[5]),math.rad(v[6]))
   elseif kind=="Vector3"or kind=="Color3"then local v={};for i=1,3 do v[i]=assert(tonumber(inputs[i].Text),"Enter numeric components")end;result=kind=="Vector3"and Vector3.new(v[1],v[2],v[3])or Color3.fromRGB(math.clamp(v[1],0,255),math.clamp(v[2],0,255),math.clamp(v[3],0,255))
   elseif complex then result=Engine.decode(Http:JSONDecode(inputs[1].Text),kind)
   elseif kind=="number"then result=assert(tonumber(inputs[1].Text),"Enter a number")
   elseif kind=="boolean"then local text=string.lower(inputs[1].Text);assert(text=="true"or text=="false","Enter true or false");result=text=="true"
   else result=inputs[1].Text;if track.enumType then assert(Enum[track.enumType][result],"Unknown enum value")end end
   Engine.encode(result,kind)
  end)
  if not ok then return message(tostring(reason))end
  if weight then local amount=tonumber(weight.Text);if not amount or amount<0 or amount>1 then return message("Pose weight must be between zero and one.")end end
  closeDialog("Value");editValue(result,refs)
  if weight then local amount=tonumber(weight.Text);for _,row in ipairs(selectedKeys())do if not row.track.locked and not row.key.locked then row.key.nativeWeight=amount~=1 and amount or nil end end;runtime:apply(state.project,state.frame)end
  if state.valueTarget and(track.property=="AttachToPart"or track.property=="LookAtPart")then
   for _,row in ipairs(selectedKeys())do runtime:setReference(row.track,row.key,state.valueTarget)end;state.valueTarget=nil
  end
 end)
end
local function eventKey(track)
 for _,row in ipairs(selectedKeys())do if row.track.id==track.id then return row.key end end
 for _,key in ipairs(track.keys)do if key.frame==math.floor(state.frame+0.5)then return key end end
end
eventDialog=function()
 local track=activeTrack();if not track or track.property~="Event"then return message("Select an Events track.")end
 local key=eventKey(track);local d,b=dialog("Event","Edit Animation Event",402,490)
 label(b,"Name",9,8,75,20);local name=field(b,key and key.value or"Event",88,8,305,23)
 label(b,"Value",9,39,75,20);local value=field(b,key and key.eventValue or"",88,39,305,23)
 label(b,"Duration (frames)",9,70,150,20);local duration=field(b,tostring(key and key.duration or 0),172,70,221,23)
 local contents={
  Events=field(b,Http:JSONEncode(key and key.events or{}),9,145,384,235,nil,{multiline=true}),
  Begin=field(b,key and key.codeBegin or"",9,145,384,235,nil,{multiline=true}),
  End=field(b,key and key.codeEnd or"",9,145,384,235,nil,{multiline=true}),
 }
 contents.Begin.Visible=false;contents.End.Visible=false
 local tabs={}
 local function show(tab)for title,content in pairs(contents)do content.Visible=title==tab;tabs[title].BorderColor3=title==tab and C.cyan or C.border end end
 tabs.Events=button(b,"Events (JSON)",9,107,122,27,function()show("Events")end,{selected=true})
 tabs.Begin=button(b,"Code Begin",140,107,122,27,function()show("Begin")end)
 tabs.End=button(b,"Code End",271,107,122,27,function()show("End")end)
 label(b,"Event data is a JSON object of named values.",9,386,384,20,{color=C.muted,size=12})
 Gui.check(b,"Run authored event code in preview",state.runEventCode,9,414,384,function(v)state.runEventCode=v end)
 button(b,"OK",9,450,384,28,function()
  if track.locked or(key and key.locked)then return message("This event is locked.")end
  local frames=tonumber(duration.Text);if not frames or frames<0 or frames%1~=0 or frames+(key and key.frame or math.floor(state.frame))>state.project.duration then return message("Use a whole duration inside the timeline.")end
  local ok,data=pcall(function()return Http:JSONDecode(contents.Events.Text)end)
  if not ok or type(data)~="table"then return message("Events must be a JSON object.")end
  for eventName in pairs(data)do if type(eventName)~="string"or eventName==""then return message("Use nonempty names for event values.")end end
  checkpoint();local edited=key or Engine.insert(track,math.floor(state.frame+0.5),name.Text)
  edited.value=name.Text;edited.eventValue=value.Text;edited.events=data;edited.duration=frames;edited.codeBegin=contents.Begin.Text;edited.codeEnd=contents.End.Text
  closeDialog("Event");render()
 end)
end
actionDialog=function()
 local track=activeTrack();local binding=track and runtime.bindings[track.id]
 if not binding or track.property~="Action"then return message("Select an Actions track.")end
 local methods=Runtime.actions(binding.instance);if #methods==0 then return message("This object has no supported actions.")end
 local key=eventKey(track);local method=key and key.value or methods[1]
 local d,b=dialog("Action","Edit Action",242,166)
 local choice;choice=button(b,method,9,12,224,27,function()method=methods[(table.find(methods,method)or 0)%#methods+1];choice.Text=method end)
 label(b,"Emit count",9,53,98,22);local amount=field(b,tostring(key and key.arguments and key.arguments[1]or 1),112,53,121,24)
 button(b,"Preview action",9,88,224,25,function()local ok,reason=pcall(runtime.action,runtime,binding.instance,method,{tonumber(amount.Text)or 1});if not ok then message(reason)end end)
 button(b,"OK",9,127,224,28,function()
  if track.locked or(key and key.locked)then return message("This action is locked.")end
  local n=tonumber(amount.Text);if method=="Emit"and(not n or n<0 or n%1~=0 or n>100000)then return message("Enter a valid emission count.")end
  checkpoint();local edited=key or Engine.insert(track,math.floor(state.frame+0.5),method);edited.value=method;edited.arguments=method=="Emit"and{n}or nil
  closeDialog("Action");render()
 end)
end
easingDialog=function()
 state.selected=selectedCurrent();if #state.selected==0 then return transformDialog()end
 local first=selectedKeys()[1];if not first then return end
 if first.track.property=="Event"then return eventDialog()elseif first.track.property=="Action"then return actionDialog()end
 local d,b=dialog("Easing","Edit Keyframes",294,481)
 local style,direction=first.key.easing or"Linear",first.key.direction or"InOut"
 local parameters=Engine.clone(first.key.parameters or{amplitude=1,period=0.3})
 button(b,"Easing",9,8,134,24,function()end,{selected=true})
 button(b,"Value",149,8,136,24,function()closeDialog("Easing");transformDialog()end)
 local group=Gui.section(b,"Ease Type",9,51,276,131)
 local styles={"Linear","Constant","Sine","Quad","Cubic","Quart","Quint","Sextic","Expo","Circ","Back","Bounce","Elastic"}
 local styleButtons={};local graph
 local function drawGraph()
  if graph then Gui.clear(graph)else return end
  for i=0,4 do make("Frame",{Position=UDim2.fromOffset(i*63,0),Size=UDim2.fromOffset(1,100),BackgroundColor3=C.border,BackgroundTransparency=0.7,BorderSizePixel=0},graph)end
  make("Frame",{Position=UDim2.fromOffset(0,95),Size=UDim2.fromOffset(252,1),BackgroundColor3=C.border,BorderSizePixel=0},graph)
  local previous=nil
  for i=0,60 do
   local t=i/60;local alpha=Engine.ease(t,style,direction,style=="Elastic"and parameters or nil);local point=Vector2.new(t*252,95-alpha*85)
   if previous then local delta=point-previous;make("Frame",{AnchorPoint=Vector2.new(0,0.5),Position=UDim2.fromOffset(previous.X,previous.Y),Size=UDim2.fromOffset(delta.Magnitude,1),Rotation=math.deg(math.atan2(delta.Y,delta.X)),BackgroundColor3=C.accent,BorderSizePixel=0},graph)end;previous=point
  end
  for name,control in pairs(styleButtons)do control.BorderColor3=name==style and C.cyan or C.border;control.TextColor3=name==style and C.accent or C.text end
 end
 for i,name in ipairs(styles)do local col=i<=2 and 0 or i<=6 and 1 or i<=10 and 2 or 3;local row=i<=2 and i-1 or i<=6 and i-3 or i<=10 and i-7 or i-11
  styleButtons[name]=button(group,name,6+col*66,10+row*27,62,23,function()style=name;drawGraph()end,{selected=name==style})
 end
 local directionGroup=Gui.section(b,"Direction",9,199,276,46)
 local dirs={};for i,name in ipairs({"In","Out","InOut","OutIn"})do dirs[name]=button(directionGroup,name,6+(i-1)*66,12,62,24,function()direction=name;for n,c in pairs(dirs)do c.BorderColor3=n==name and C.cyan or C.border end;drawGraph()end,{selected=name==direction})end
 graph=make("Frame",{Position=UDim2.fromOffset(20,261),Size=UDim2.fromOffset(252,105),BackgroundColor3=C.background,BorderColor3=C.border,BorderSizePixel=1,ClipsDescendants=true},b);drawGraph()
 label(b,"Amplitude",9,374,76,21);local amplitude=field(b,tostring(parameters.amplitude),88,374,69,23,function(text)local v=tonumber(text);if v and v>=0 then parameters.amplitude=v;drawGraph()end end)
 label(b,"Period",9,405,76,21);local period=field(b,tostring(parameters.period),88,405,69,23,function(text)local v=tonumber(text);if v and v>0 then parameters.period=v;drawGraph()end end)
 button(b,"Reset",174,374,111,23,function()parameters.amplitude=1;amplitude.Text="1";drawGraph()end)
 button(b,"Reset",174,405,111,23,function()parameters.period=0.3;period.Text="0.3";drawGraph()end)
 button(b,"OK",9,442,133,28,function()
  local a,p=tonumber(amplitude.Text),tonumber(period.Text);if not a or a<0 or not p or p<=0 then return message("Use nonnegative amplitude and a positive period.")end
  parameters={amplitude=a,period=p};local candidate=Engine.clone(state.project);local wanted={};local refs=Engine.clone(state.selected)
  for _,ref in ipairs(refs)do wanted[ref.keyId]=ref.trackId end
  for _,track in ipairs(candidate.tracks)do if not track.locked then for _,key in ipairs(track.keys)do if wanted[key.id]==track.id and not key.locked then key.easing=style;key.direction=direction;key.parameters=style=="Elastic"and Engine.clone(parameters)or nil end end end end
  local valid,reason=Engine.validate(candidate);if not valid then return message(reason)end
  state.lastEase=style;state.lastDirection=direction;state.lastParameters=style=="Elastic"and Engine.clone(parameters)or nil
  checkpoint();closeDialog("Easing");changeProject(candidate);state.selected=refs;render()
 end)
 button(b,"Cancel",151,442,134,28,function()closeDialog("Easing")end)
end
markersDialog=function()
 local d,b=dialog("Markers","Edit Markers",277,228)
 local list=make("ScrollingFrame",{Position=UDim2.fromOffset(9,9),Size=UDim2.fromOffset(259,91),BackgroundColor3=C.background,BorderColor3=C.border,BorderSizePixel=1,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,#state.project.markers*22)},b)
 for i,marker in ipairs(state.project.markers)do button(list,tostring(marker.frame).."f  "..marker.name.."  "..tostring(marker.value),3,(i-1)*22,246,21,function()seek(marker.frame)end,{flat=true})end
 label(b,"Name",9,110,49,20);local name=field(b,"Marker",63,110,205,23)
 label(b,"Value",9,140,49,20);local value=field(b,"",63,140,205,23)
 button(b,"Add at current frame",9,175,173,27,function()checkpoint();table.insert(state.project.markers,{id=Http:GenerateGUID(false),frame=math.floor(state.frame+0.5),name=name.Text,value=value.Text});closeDialog("Markers");render();markersDialog()end)
 button(b,"Delete",189,175,79,27,function()checkpoint();for i=#state.project.markers,1,-1 do if state.project.markers[i].frame==math.floor(state.frame+0.5)then table.remove(state.project.markers,i)end end;closeDialog("Markers");render();markersDialog()end)
end
importDialog=function()
 local rigs={};for _,item in ipairs(state.project.items)do if item.type=="Rig"then table.insert(rigs,item)end end
 if #rigs==0 then return message("Add a rig before importing an animation.")end
 local d,b=dialog("Import","Import to Rig",402,364)
 local targets={};local active=activeItem();targets[active and active.type=="Rig"and active.id or rigs[1].id]=true
 local targetGroup=Gui.section(b,"Import to",9,16,384,83)
 local targetList=make("ScrollingFrame",{Position=UDim2.fromOffset(5,12),Size=UDim2.fromOffset(374,64),CanvasSize=UDim2.fromOffset(0,#rigs*21),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4},targetGroup)
 for i,item in ipairs(rigs)do Gui.check(targetList,item.name,targets[item.id]==true,2,(i-1)*21,360,function(v)targets[item.id]=v end)end
 local id=field(b,"",9,111,384,25,nil,{placeholder="Roblox animation ID / Avatar Shop animation"})
 local source=nil;local selected=Selection:Get()[1];if selected and selected:IsA("KeyframeSequence")then source=selected end
 local useSelected;useSelected=button(b,source and source.Name or"Use selected KeyframeSequence",9,146,384,26,function()
  local object=Selection:Get()[1];if object and object:IsA("KeyframeSequence")then source=object;useSelected.Text=object.Name else message("Select a KeyframeSequence in Explorer.")end
 end)
 local sourceList=make("ScrollingFrame",{Position=UDim2.fromOffset(9,182),Size=UDim2.fromOffset(384,80),CanvasSize=UDim2.fromOffset(0,0),BackgroundTransparency=1,BorderColor3=C.border,BorderSizePixel=1,ScrollBarThickness=4},b)
 local sources={};for _,object in ipairs(game:GetDescendants())do if object:IsA("KeyframeSequence")then table.insert(sources,object)end end
 table.sort(sources,function(x,y)return x:GetFullName()<y:GetFullName()end)
 for i,sequence in ipairs(sources)do button(sourceList,sequence:GetFullName(),3,(i-1)*22,367,21,function()source=sequence;useSelected.Text=sequence.Name end,{flat=true})end;sourceList.CanvasSize=UDim2.fromOffset(0,#sources*22)
 local mode="Replace";local grouped=state.project.groupKeyframes==true
 Gui.check(b,"Paste Keyframes at current frame",false,9,272,384,function(v)mode=v and"Paste"or"Replace"end)
 Gui.check(b,"Group Keyframes",grouped,9,294,384,function(v)grouped=v end)
 button(b,"OK",9,327,384,28,function()
  local selectedRigs={};for _,item in ipairs(rigs)do if targets[item.id]then table.insert(selectedRigs,item)end end
  if #selectedRigs==0 then return message("Choose at least one target rig.")end
  local owned=false
  if not source then local number=string.match(id.Text,"(%d+)");if not number then return message("Select a saved animation or enter its Roblox ID.")end
   local ok,result=pcall(function()return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync("rbxassetid://"..number)end)
   if not ok then return message("Roblox could not load that animation: "..tostring(result))end;source=result;owned=true
  end
  local candidate=Engine.clone(state.project);local failure=nil
  for _,item in ipairs(selectedRigs)do
   local target=nil;for _,entry in ipairs(candidate.items)do if entry.id==item.id then target=entry end end
   local ok,reason=Export.importRig(candidate,target,source,mode,math.floor(state.frame+0.5))
   if not ok then failure=reason;break end
   if grouped then groupFrames(candidate,item.id)end
  end
  if owned then source:Destroy();source=nil end
  if failure then return message(failure)end
  local valid,reason=Engine.validate(candidate);if not valid then return message(reason)end
  checkpoint();closeDialog("Import");changeProject(candidate)
 end)
end
charactersDialog=function()
 local d,b=dialog("Characters","Character Inserter",470,228)
 local group=Gui.section(b,"Character",10,17,450,150)
 label(group,"Username or User ID",12,16,180,21);local username=field(group,"",190,15,245,24)
 local rigType="R6";local r6,r15
 r6=button(group,"R6",12,56,204,28,function()rigType="R6";r6.BorderColor3=C.cyan;r15.BorderColor3=C.border end,{selected=true})
 r15=button(group,"R15",229,56,206,28,function()rigType="R15";r15.BorderColor3=C.cyan;r6.BorderColor3=C.border end)
 label(group,"Leave the username empty for a plain rig.",12,99,423,25,{color=C.muted})
 button(b,"Insert",10,183,450,29,function()
  local ok,result=pcall(function()return runtime:createRig(rigType,username.Text)end)
  if not ok then return message("Character insertion failed: "..tostring(result))end
  closeDialog("Characters");message("Inserted "..result.Name..". Add it to your animation with Item → Add.")
 end)
end
weldDialog=function()
 local d,b=dialog("Weld","Easy Weld",285,225)
 local group=Gui.section(b,"Parts",10,17,265,71)
 label(group,"Select the base part first, then the prop(s).",9,13,248,23)
 local status=label(group,"",9,38,248,22,{color=C.muted})
 local kind="Weld";local mode
 mode=button(b,"Weld (static)",10,92,265,25,function()kind=kind=="Weld"and"Motor6D"or"Weld";mode.Text=kind=="Weld"and"Weld (static)"or"Motor6D (animate independently)"end)
 local function weld(inPlace)
  local history=game:GetService("ChangeHistoryService");local token=nil;pcall(function()token=history:TryBeginRecording("KeynovaWeld")end)
  local ok,text=runtime:weld(inPlace,kind);status.Text=text
  if token then history:FinishRecording(token,ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)end
 end
 button(b,"Join In Place",10,129,265,28,function()weld(true)end)
 button(b,"Join",10,171,128,28,function()weld(false)end)
 button(b,"Clean selected welds",147,171,128,28,function()local count=0;for _,obj in ipairs(Selection:Get())do for _,child in ipairs(obj:GetChildren())do if (child:IsA("Weld")and child.Name=="KeynovaWeld"or child:IsA("Motor6D")and child.Name=="KeynovaJoint")then child:Destroy();count=count+1 end end end;status.Text="Removed "..count.." Keynova weld(s)."end)
end

local function applyOnion()
 checkpoint();local refs,reason=runtime:applyOnion(state.project,math.floor(state.frame+0.5),activeItem()and activeItem().id)
 if not refs then table.remove(state.undo);return message(reason)end
 state.selected=refs;render()
end
local function reverseKeys()
 local candidate=Engine.clone(state.project);local refs,reason=Engine.reverse(candidate,selectedCurrent())
 if not refs then return message(reason)end
 checkpoint();local selected=refs;changeProject(candidate);state.selected=selected;render()
end
local function wiggleDialog()
 local d,b=dialog("Wiggle","Fill / Wiggle",282,311)
 local inputs={};local values={{"Amplitude","1"},{"Period (frames)","30"},{"Step (frames)","1"},{"Seed","0"},{"Axes (X,Y,Z)","1,1,1"}}
 for i,row in ipairs(values)do label(b,row[1],9,12+(i-1)*39,127,24);inputs[i]=field(b,row[2],141,12+(i-1)*39,132,25)end
 local mode="Position";local modeButton;modeButton=button(b,"Position (studs)",9,210,264,25,function()mode=mode=="Position"and"Rotation"or"Position";modeButton.Text=mode=="Position"and"Position (studs)"or"Rotation (degrees)"end)
 button(b,"Fill with Wiggle",9,266,264,29,function()
  local axes={};for value in string.gmatch(inputs[5].Text,"[^,]+")do table.insert(axes,tonumber(value))end
  if #axes~=3 or not axes[1]or not axes[2]or not axes[3]then return message("Enter three numeric axes.")end
  local candidate=Engine.clone(state.project)
  local refs,reason=Engine.wiggle(candidate,selectedCurrent(),{amplitude=tonumber(inputs[1].Text),period=tonumber(inputs[2].Text),step=tonumber(inputs[3].Text),seed=tonumber(inputs[4].Text),axes=Vector3.new(axes[1],axes[2],axes[3]),mode=mode})
  if not refs then return message(reason)end
  checkpoint();closeDialog("Wiggle");changeProject(candidate);state.selected=refs;render()
 end)
end
local function closeFile()
 gizmo:clear();state.playing=false;clearEventModules();runtime:restore();runtime:clearOnion();state.editing=false;state.runEventCode=false;render()
end
local function selectAll()
 state.selected={};for _,track in ipairs(state.project.tracks)do if not track.locked then for _,key in ipairs(track.keys)do if not key.locked then table.insert(state.selected,{trackId=track.id,keyId=key.id})end end end end;render()
end
local function lockKeys()
 local rows=selectedKeys();if #rows==0 then return end;checkpoint();local lock=false
 for _,row in ipairs(rows)do if not row.key.locked then lock=true end end
 for _,row in ipairs(rows)do if not row.track.locked then row.key.locked=lock end end;render()
end
local function jumpDialog()
 local d,b=dialog("Jump","Jump To Item",242,243)
 local list=make("ScrollingFrame",{Position=UDim2.fromOffset(9,10),Size=UDim2.fromOffset(224,221),CanvasSize=UDim2.fromOffset(0,#state.project.items*25),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4},b)
 for i,item in ipairs(state.project.items)do button(list,item.name,2,(i-1)*25,213,24,function()state.activeTrack=nil;state.activeItem=item.id;closeDialog("Jump");focusItem();render()end,{flat=true})end
end
local function toggleItem()
 local item=activeItem();if not item then return end
 checkpoint();local enable=false;for _,track in ipairs(state.project.tracks)do if track.itemId==item.id and track.enabled==false then enable=true end end
 for _,track in ipairs(state.project.tracks)do if track.itemId==item.id then track.enabled=enable end end
 runtime:apply(state.project,state.frame);render()
end
local function toggleCamera()
 checkpoint();local enable=false
 for _,track in ipairs(state.project.tracks)do local item=findItem(track.itemId);if item and item.type=="Camera"and track.enabled==false then enable=true end end
 for _,track in ipairs(state.project.tracks)do local item=findItem(track.itemId);if item and item.type=="Camera"then track.enabled=enable end end
 runtime:apply(state.project,state.frame);render()
end
local function cameraReference()
 local object=Selection:Get()[1];if not object or not object:IsA("BasePart")then return message("Select a camera reference BasePart in Explorer.")end
 state.cameraReference=object;message("Camera export reference: "..object:GetFullName())
end
local function exportFiles()
 local ok,result=pcall(Export.files,state.project,runtime.bindings,state.cameraReference,runtime.objects)
 if not ok then return message(tostring(result))end
 local folder=Storage:FindFirstChild("KeynovaExports")or make("Folder",{Name="KeynovaExports"},Storage)
 result.Parent=folder;Selection:Set({result});message("Exported frame files to "..result:GetFullName());return result
end
local function previewEvent(phase,track,key,target,failure)
 if phase=="Error"then return message(failure)end
 if phase=="Marker"then return message(tostring(key.value)..": "..tostring(key.eventValue))end
 local identity=track.id..":"..key.id
 if phase=="End"and not state.activeEvents[identity]then return end
 if phase=="Begin"then state.activeEvents[identity]={track=track,key=key,target=target}else state.activeEvents[identity]=nil end
 message(tostring(key.value).." ["..phase.."] "..tostring(key.eventValue or""))
 local authored=phase=="Begin"and key.codeBegin or key.codeEnd
 if state.runEventCode and authored and authored~=""then
  local code=key.codeBegin or"";local ending=key.codeEnd or"";local cached=state.eventModules[key.id]
  if not cached or cached.beginCode~=code or cached.endCode~=ending then
   if cached then cached.module:Destroy()end
   local module=Instance.new("ModuleScript");module.Name="KeynovaAuthoredEvent";module.Source=Events.source({key});module.Parent=CoreGui
   local ok,callbacks=pcall(require,module);if not ok then module:Destroy();return message(tostring(callbacks))end
   cached={module=module,callbacks=callbacks[key.id],beginCode=code,endCode=ending};state.eventModules[key.id]=cached
  end
  local ok,reason=pcall(cached.callbacks[phase],{Target=target,Frame=key.frame,Name=key.value,Value=key.eventValue,Project=state.project,Phase=phase,Player=api,Key=key})
  if not ok then message(tostring(reason))end
 end
end
clearEventModules=function()
 local active={};for _,entry in pairs(state.activeEvents)do table.insert(active,entry)end
 for _,entry in ipairs(active)do previewEvent("End",entry.track,entry.key,entry.target)end
 state.activeEvents={}
 for id,entry in pairs(state.eventModules)do entry.module:Destroy();state.eventModules[id]=nil end
end
local function advance(dt)
 local duration=state.project.duration;if duration<=0 then state.playing=false;return end
 local first=state.frame;local target=first+dt*state.project.fps*state.speed
 if state.speed>=0 then
  if state.project.loop and target>duration then
   local cycles=math.floor(target/duration)
   if cycles>100 then state.playing=false;return message("Playback exceeded 100 loops in one update.")end
   runtime:crossings(state.project,first,duration,false,previewEvent)
   for _=2,cycles do runtime:crossings(state.project,0,duration,true,previewEvent)end
   target=target%duration;runtime:crossings(state.project,0,target,true,previewEvent)
  else runtime:crossings(state.project,first,math.min(target,duration),false,previewEvent)end
 else
  if state.project.loop and target<0 then target=target%duration elseif target<0 then target=0;state.playing=false end
 end
 if not state.project.loop and target>=duration then target=duration;state.playing=false;runtime:stopActions()end
 state.frame=math.clamp(target,0,duration);runtime:apply(state.project,state.frame);paint();updateHandles()
end
themeDialog=function()
 local d,b=dialog("Theme","Theme Colors",354,443);local palette=Gui.exportTheme();local inputs={};local names={}
 for name in pairs(palette)do table.insert(names,name)end;table.sort(names)
 for i,name in ipairs(names)do local y=9+(i-1)*31;label(b,name,9,y,119,23);inputs[name]={}
  for channel=1,3 do inputs[name][channel]=field(b,tostring(palette[name][channel]),131+(channel-1)*71,y,65,24)end
 end
 local data=field(b,Http:JSONEncode(palette),9,298,336,68,nil,{multiline=true})
 button(b,"Load JSON",9,374,162,26,function()local ok,value=pcall(function()return Http:JSONDecode(data.Text)end);if not ok then return message("Invalid theme JSON")end
  local success,reason=Gui.importTheme(value);if not success then return message(reason)end
  savePreferences();closeDialog("Theme");render();themeDialog()
 end)
 button(b,"Apply RGB",183,374,162,26,function()
  local value={};for _,name in ipairs(names)do value[name]={};for channel=1,3 do value[name][channel]=tonumber(inputs[name][channel].Text)end end
  local success,reason=Gui.importTheme(value);if not success then return message(reason)end
  savePreferences();closeDialog("Theme");render()
 end)
 button(b,"Export JSON to selection",9,408,336,26,function()local value=Instance.new("StringValue");value.Name="KeynovaTheme";value.Value=Http:JSONEncode(Gui.exportTheme());value.Parent=Storage;Selection:Set({value});message("Theme JSON saved in ServerStorage.KeynovaTheme")end)
end
gizmoDialog=function()
 local d,b=dialog("Gizmo","Gizmo Settings",282,189)
 label(b,"Translation increment",9,13,166,23);local translation=field(b,tostring(state.translationStep),184,13,89,24)
 label(b,"Rotation increment (°)",9,52,166,23);local rotation=field(b,tostring(state.rotationStep),184,52,89,24)
 label(b,"Handle size",9,91,166,23);local size=field(b,tostring(state.handleSize),184,91,89,24)
 button(b,"OK",9,145,264,29,function()
  local t,r,z=tonumber(translation.Text),tonumber(rotation.Text),tonumber(size.Text)
  if not t or t<=0 or not r or r<=0 or not z or z<=0 or t==math.huge or r==math.huge or z==math.huge then return message("Enter positive finite settings.")end
  state.translationStep=t;state.rotationStep=r;state.handleSize=z;savePreferences();closeDialog("Gizmo");updateHandles()
 end)
end
rebindDialog=function()
 local item=activeItem();local target=Selection:Get()[1];if not item or not target then return message("Select an item and its replacement instance in Explorer.")end
 local refs=references();local ref=refs:FindFirstChild(item.id);if ref then ref.Value=target end
 for _,track in ipairs(state.project.tracks)do if track.itemId==item.id then local old=refs:FindFirstChild("Track_"..track.id);if old then old:Destroy()end;track.targetPath=nil end end
 checkpoint();item.path=Runtime.path(target);item.name=target.Name;local missing=runtime:load(state.project,refs);refs:Destroy();runtime:apply(state.project,state.frame);render()
 if #missing>0 then message("Missing tracks: "..table.concat(missing,", "))end
end
fileDialog=function(current)
 local base=Storage:FindFirstChild("KeynovaSaves")or make("Folder",{Name="KeynovaSaves"},Storage)
 current=current or base;local d,b=dialog("Files","File Explorer",402,354);local chosen=nil
 label(b,current:GetFullName(),9,8,332,22,{color=C.muted});button(b,"Up",346,8,47,23,function()fileDialog(current~=base and current.Parent or base)end)
 local entries=current:GetChildren();table.sort(entries,function(a,c)return a.Name<c.Name end)
 local list=make("ScrollingFrame",{Position=UDim2.fromOffset(9,39),Size=UDim2.fromOffset(384,178),CanvasSize=UDim2.fromOffset(0,#entries*25),BackgroundTransparency=1,BorderColor3=C.border,BorderSizePixel=1,ScrollBarThickness=4},b)
 local name=field(b,"",9,228,384,24,nil,{placeholder="File or folder name"})
 for i,entry in ipairs(entries)do
  button(list,(entry:IsA("Folder")and"[+] "or"")..entry.Name,4,(i-1)*25,365,24,function()chosen=entry;name.Text=entry.Name end,{flat=true})
 end
 button(b,"Open",9,262,89,26,function()if not chosen then return end;if chosen:IsA("Folder")then fileDialog(chosen)elseif chosen:IsA("StringValue")then closeDialog("Files");guard(function()openSaved(chosen)end)end end)
 button(b,"Rename",107,262,89,26,function()if chosen and name.Text~=""then chosen.Name=name.Text;fileDialog(current)end end)
 button(b,"Duplicate",205,262,89,26,function()if chosen then local clone=chosen:Clone();clone.Name=chosen.Name.." Copy";clone.Parent=current;fileDialog(current)end end)
 button(b,"New Folder",303,262,90,26,function()if name.Text~=""then make("Folder",{Name=name.Text},current);fileDialog(current)end end)
 button(b,"Trash",9,302,89,26,function()if chosen then local trash=Storage:FindFirstChild("KeynovaTrash")or make("Folder",{Name="KeynovaTrash"},Storage);local origin=make("ObjectValue",{Name="KeynovaOriginalFolder",Value=current},chosen);chosen.Parent=trash;fileDialog(current)end end)
 button(b,"Show Trash",107,302,138,26,function()fileDialog(Storage:FindFirstChild("KeynovaTrash")or make("Folder",{Name="KeynovaTrash"},Storage))end)
 button(b,"Restore",254,302,139,26,function()if chosen then local origin=chosen:FindFirstChild("KeynovaOriginalFolder");chosen.Parent=origin and origin.Value or base;if origin then origin:Destroy()end;fileDialog(current)end end)
end

guard=function(callback)
 if not state.dirty then return callback()end
 local d,b=dialog("Unsaved","Unsaved Changes",302,135)
 label(b,"Save changes to "..state.project.name.."?",9,13,284,42)
 button(b,"Save",9,87,88,29,function()if save()then closeDialog("Unsaved");callback()end end)
 button(b,"Discard",107,87,88,29,function()closeDialog("Unsaved");callback()end)
 button(b,"Cancel",205,87,88,29,function()closeDialog("Unsaved")end)
end

local menus={}
local function action(name,fn,key)return{name=name,run=fn,key=key}end
local function cameraItem()
 for _,item in ipairs(state.project.items)do if item.type=="Camera"then return item end end
 checkpoint();local item=runtime:addObject(state.project,workspace.CurrentCamera,{"CFrame","FieldOfView"});state.activeItem=item and item.id;render();return item
end
local function cameraKey()
 local cf=workspace.CurrentCamera.CFrame;local item=cameraItem();if not item then return end
 for _,track in ipairs(state.project.tracks)do if track.itemId==item.id and track.property=="CFrame"then choose(track);addKey(cf);return end end
end
local function resetPose()
 local track=activeTrack();if not track then return end
 local binding=runtime.bindings[track.id];if not binding then return end
 addKey(track.property=="Transform"and CFrame.new()or binding.base)
end
local function setOnion(enabled)
 state.onion=enabled
 if enabled then runtime:onion(state.project,math.max(0,state.frame-10),state.frame)else runtime:clearOnion()end
end
local function collapseAll()
 local collapsed=false;for _,item in ipairs(state.project.items)do if item.expanded~=false then collapsed=true end end
 for _,item in ipairs(state.project.items)do item.expanded=not collapsed end;render()
end
local function hide()state.uiHidden=true;widget.Enabled=false;gizmo:clear()end
local function option(name,fieldName,invert)
 return {name=name,checked=function()return invert and not state[fieldName]or(not invert and state[fieldName])end,run=function()state[fieldName]=not state[fieldName];savePreferences();render()end}
end
local function directionPlay(direction)
 if state.playing and state.speed==direction then return play()end
 state.speed=direction;state.playing=false;play()
end
local function fitTimeline()
 local last=1;for _,track in ipairs(state.project.tracks)do for _,key in ipairs(track.keys)do last=math.max(last,key.frame+(key.duration or 0))end end
 for _,marker in ipairs(state.project.markers)do last=math.max(last,marker.frame)end
 checkpoint();state.project.duration=last;state.frame=math.min(state.frame,last);render()
end
local function rotateCamera()
 local item=cameraItem();if not item then return end
 for _,track in ipairs(state.project.tracks)do if track.itemId==item.id and track.property=="CFrame"then choose(track);state.selected={};return transformDialog()end end
end
menus.File={action("Save",save,"0"),action("Save As...",function()saveAsDialog(false)end),action("Save and Close",function()if save()then closeFile()end end,"/"),action("Close",function()guard(closeFile)end,"\\"),action("File Settings...",settingsDialog,"8"),{},action("Export Rigs",exportAllRigs,"5"),action("Import...",importDialog,"Shift+I"),action("Export Files...",exportFiles),{},action("Toggle Loop",function()checkpoint();state.project.loop=not state.project.loop;paint()end,"Tab"),action("Play",play,"Space"),action("Hide UI",hide,"Ctrl+H"),{},action("File Explorer...",fileDialog),action("Export Scene Player",exportScene)}
menus.LauncherFile={action("New Keynova File...",function()saveAsDialog(true)end),action("Open File Explorer",fileDialog),action("Character Inserter",charactersDialog),action("Easy Weld",weldDialog)}
menus.Edit={action("Undo",undo,"Ctrl+Z"),action("Redo",redo,"Ctrl+Y"),{},action("Cut",function()copyKeys(true)end,"Ctrl+X"),action("Copy",function()copyKeys(false)end,"Ctrl+C"),action("Paste",function()pasteKeys(false)end,"Ctrl+V"),action("Paste Into Track",function()pasteKeys(true)end,"Shift+Ctrl+V"),action("Delete",deleteKeys,"Delete"),action("Select All",selectAll,"Ctrl+A")}
menus.Item={action("Rig  ›",function()menu("Rig")end),action("Add Effects  ›",function()menu("Effects")end),action("Add...",function()addDialog()end,"9"),{},action("View",focusItem,"F"),action("Toggle All",toggleItem,"Shift+Space"),action("Collapse All",collapseAll,"2"),action("Jump To...",jumpDialog,"Shift+P")}
menus.ItemContext={action("Edit Item...",function()addDialog(activeItem())end),action("View",focusItem,"F"),action("Rebind to Selected Instance",rebindDialog),action("Delete Item",removeItem)}
menus.Rig={action("Reflect",reflect,"Ctrl+R"),action("Import...",importDialog,"Shift+I"),action("Export",exportRig,"5"),action("Rebind to Selected Rig",rebindDialog),action("Character Inserter",charactersDialog)}
menus.Effects={action("Lighting",function()addDialog(nil,game:GetService("Lighting"))end),action("Terrain",function()addDialog(nil,workspace.Terrain)end),action("Selected Effect / Face / Sound",function()addDialog()end)}
menus.Keyframe={action("Add",function()addKey()end,"="),action("Edit...",easingDialog,"7"),action("Edit Value...",transformDialog),{},action("Group",function()groupKeys(false)end,"Ctrl+G"),action("Ungroup",function()groupKeys(true)end,"Ctrl+U"),action("Lock / Unlock",lockKeys),action("Markers...",markersDialog),{},action("Fill Frames...",function()operationDialog("Fill")end,"Shift+K"),action("Fill with Wiggle...",wiggleDialog),action("Split Frames...",function()operationDialog("Split")end,"M"),action("Reverse Frames",reverseKeys),action("Repeat Frames...",function()operationDialog("Repeat")end,"Shift+L"),action("Stretch Frames...",function()operationDialog("Stretch")end,"3"),action("Frame Offset...",function()operationDialog("Offset")end)}
menus.Frame={action("Play / Pause",play,"Space"),action("Play Backward",function()directionPlay(-1)end),action("Play Forward",function()directionPlay(1)end),action("Loop",function()checkpoint();state.project.loop=not state.project.loop;paint()end,"Tab"),{},action("First Frame",function()seek(0)end,"1"),action("Previous Frame",function()seek(math.max(0,math.floor(state.frame)-1))end,"4"),action("Next Frame",function()seek(math.min(state.project.duration,math.floor(state.frame)+1))end,"6"),action("Previous Keyframe",function()jump(false)end,"J"),action("Next Keyframe",function()jump(true)end,"K"),action("Fit to Last Keyframe",fitTimeline,"Shift+F"),{},action("Animation Settings...",settingsDialog,"8")}
menus.Camera={action("Add Camera",function()addDialog(nil,workspace.CurrentCamera)end),action("Add Camera Keyframe",cameraKey),action("Attach To Selected Part",function()local obj=Selection:Get()[1];local item=cameraItem();if obj and obj:IsA("BasePart")and item then local track=runtime:addProperty(state.project,item,"AttachToPart");choose(track);addKey(obj:GetFullName());for _,row in ipairs(selectedKeys())do runtime:setReference(row.track,row.key,obj)end end end),action("Look At Selected Part",function()local obj=Selection:Get()[1];local item=cameraItem();if obj and obj:IsA("BasePart")and item then local track=runtime:addProperty(state.project,item,"LookAtPart");choose(track);addKey(obj:GetFullName());for _,row in ipairs(selectedKeys())do runtime:setReference(row.track,row.key,obj)end end end),action("Camera Export Reference",cameraReference),action("Clear Export Reference",function()state.cameraReference=nil end),action("Rotate Camera...",rotateCamera,"Shift+O"),action("Toggle Camera Tracks",toggleCamera,"Ctrl+Space"),action("Hide UI",hide,"Ctrl+H")}
menus.Options={action("Handles  ›",function()menu("Handles")end),action("Gizmos  ›",function()menu("Gizmos")end),option("Use Last Ease","useLastEase"),option("Easing Colors","easingColors"),option("Show Seconds","showSeconds"),option("Hide Columns","hideColumns"),{},action("Other  ›",function()menu("Other")end)}
menus.Handles={option("Show Handles","handlesVisible"),option("World Axes","world"),action("Move / Rotate",function()state.mode=state.mode=="Rotate"and"Move"or"Rotate";updateHandles()end,"R"),action("Handle Settings...",gizmoDialog),action("Reset Pose",resetPose,"G")}
menus.Gizmos={option("Constant Size","constantSize"),option("Not Always On Top","alwaysOnTop",true),option("Use Increment","increment"),option("Show Origin","showOrigin"),action("Increment Settings...",gizmoDialog)}
menus.Other={action("Toggle Onion Skin",function()setOnion(not state.onion)end,"B"),action("Apply Onion Pose",applyOnion,"N"),action("Clear Onion Skins",function()state.onion=false;runtime:clearOnion()end,"Alt+B"),option("Run Authored Event Code","runEventCode"),{},action("Character Inserter",charactersDialog),action("Easy Weld",weldDialog),action("Hide UI",hide,"Ctrl+H")}
menus.Theme={action("Default",function()Gui.theme("Default");savePreferences();render()end),action("Midnight",function()Gui.theme("Midnight");savePreferences();render()end),action("Customize / Import...",themeDialog)}
menu=function(name,x)
 if dropdown then dropdown:Destroy();dropdown=nil end
 local entries=name=="File"and not state.editing and menus.LauncherFile or menus[name];if not entries then return end
 local height=8;for _,row in ipairs(entries)do height=height+(row.name and 22 or 8)end
 dropdown=make("ScrollingFrame",{CanvasSize=UDim2.fromOffset(0,height),ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.Y,Position=UDim2.fromOffset(math.min(x or 8,math.max(0,root.AbsoluteSize.X-221)),22),Size=UDim2.fromOffset(214,math.min(height,math.max(100,root.AbsoluteSize.Y-27))),BackgroundColor3=C.background,BorderColor3=C.title,BorderSizePixel=1,ZIndex=50},root)
 make("UICorner",{CornerRadius=UDim.new(0,2)},dropdown)
 local y=4
 for _,row in ipairs(entries)do
  if row.name then
   local control=button(dropdown,(row.checked and(row.checked()and"● "or"○ ")or"")..row.name,4,y,206,22,function()local old=dropdown;dropdown=nil;if old then old:Destroy()end;row.run()end,{flat=true,color=C.text});control.TextXAlignment=Enum.TextXAlignment.Left;control.ZIndex=51
   if row.key then local hint=label(control,row.key,106,0,96,22,{align="Right",color=C.muted,size=12});hint.ZIndex=52 end;y=y+22
  else make("Frame",{Position=UDim2.fromOffset(7,y+3),Size=UDim2.fromOffset(200,1),BackgroundColor3=C.border,BorderSizePixel=0,ZIndex=51},dropdown);y=y+8 end
 end
end

local function launcher()
 local width=math.max(420,root.AbsoluteSize.X);local height=math.max(180,root.AbsoluteSize.Y);local side=math.floor(width*0.30)
 local files=Gui.section(root,"Keynova Files",8,32,side-5,height-41)
 local rigs=Gui.section(root,"Rig Animations",width-side-3,32,side-5,height-41)
 local mid=side+18;local midWidth=width-side*2-36
 make("Frame",{Name="TemplatePanel",Position=UDim2.fromOffset(mid-8,32),Size=UDim2.fromOffset(midWidth+16,height-41),BackgroundTransparency=1,BorderColor3=C.border,BorderSizePixel=1},root)
 local list=make("ScrollingFrame",{Position=UDim2.fromOffset(5,13),Size=UDim2.new(1,-10,1,-18),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,0)},files)
 local folder=Storage:FindFirstChild("KeynovaSaves");local count=0
 if folder then for _,entry in ipairs(folder:GetChildren())do if entry:IsA("StringValue")then button(list,entry.Name,2,count*23,side-24,22,function()openSaved(entry)end,{flat=true});count=count+1 end end end
 if count==0 then label(list,"[ none ]",5,math.floor(height*.53)-45,side-30,28,{color=C.muted,align="Center"})end
 list.CanvasSize=UDim2.fromOffset(0,count*23)
 button(root,"Clone Template File",mid,39,midWidth,20,function()
  local p=Engine.clone(state.project);p.name=p.name.." Copy";p.groupKeyframes=state.launcherGroup
  if p.groupKeyframes then groupFrames(p)end
  local refs=references();newFile(p.name);changeProject(p,refs);state.dirty=true
 end)
 local groupCheck=Gui.check(root,"Group Keyframes",state.launcherGroup,mid,64,midWidth,function(v)state.launcherGroup=v end)
 local groupIndicator=groupCheck:FindFirstChild("Indicator");groupIndicator.Position=UDim2.fromOffset(midWidth-13,4)
 for _,child in ipairs(groupCheck:GetChildren())do if child.Name=="Label"then child.Position=UDim2.fromOffset(0,0);child.Size=UDim2.fromOffset(midWidth-20,20);child.TextXAlignment=Enum.TextXAlignment.Right end end
 Brand.draw(root,mid+math.floor((midWidth-46)/2),94,46)
 local selected=Selection:Get()[1];local rig=selected and(selected:IsA("Model")and selected or selected:FindFirstAncestorOfClass("Model"))
 label(root,rig and rig.Name or"[ no rig selected ]",mid,math.floor(height*.53),midWidth,24,{color=C.muted,align="Center"})
 Gui.check(root,"Rig Animation",state.launcherRig,mid,height-74,midWidth,function(v)state.launcherRig=v end)
 button(root,"New Keynova File",mid,height-36,midWidth,20,function()
  if state.launcherRig and not rig then return message("Select a rig Model in Explorer first.")end
  newFile("Untitled");state.project.groupKeyframes=state.launcherGroup
  if state.launcherRig then
   local item,err=runtime:addRig(state.project,rig)
   if not item then return message(err)end
   state.project.rigItemId=item.id;state.activeItem=item.id;state.activeTrack=state.project.tracks[1]and state.project.tracks[1].id;render()
  end
 end)
 local saved=rig and rig:FindFirstChild("AnimSaves");local y=14
 if saved then for _,entry in ipairs(saved:GetChildren())do
  if entry:IsA("StringValue")then
   button(rigs,entry.Name,6,y,side-23,22,function()openSaved(entry)end,{flat=true});y=y+23
  elseif entry:IsA("KeyframeSequence")then
   button(rigs,entry.Name,6,y,side-23,22,function()
    newFile(entry.Name);local item,err=runtime:addRig(state.project,rig);if not item then return message(err)end
    state.project.rigItemId=item.id;state.project.groupKeyframes=state.launcherGroup;state.activeItem=item.id;state.activeTrack=state.project.tracks[1]and state.project.tracks[1].id
    local ok,reason=Export.importRig(state.project,item,entry,"Replace",0)
    if ok and state.project.groupKeyframes then groupFrames(state.project,item.id)end
    runtime:apply(state.project,0);render();if not ok then message(reason)end
   end,{flat=true});y=y+23
  end
 end end
 if y==14 then label(rigs,"[ none ]",5,math.floor(height*.53)-32,side-22,28,{color=C.muted,align="Center"})end
end
local function rows()
 local result={}
 for _,item in ipairs(state.project.items)do
  table.insert(result,{kind="Item",item=item,name=item.name,indent=0})
  if item.expanded~=false then
   local rigTracks,properties,events={},{},{}
   for _,t in ipairs(state.project.tracks)do if t.itemId==item.id then if t.property=="Transform"then table.insert(rigTracks,t)elseif t.property=="Event"or t.property=="Action"then table.insert(events,t)else table.insert(properties,t)end end end
   for _,t in ipairs(events)do table.insert(result,{kind="Track",item=item,track=t,name=t.name,indent=1})end
   if #rigTracks>0 then table.insert(result,{kind="Rig",item=item,name="Rig",indent=1});if item.rigExpanded~=false then
    local byId={};for _,track in ipairs(rigTracks)do byId[track.id]=track end
    local function parentId(track)
     if track.parentTrackId then return track.parentTrackId end
     local found=nil;for _,other in ipairs(rigTracks)do if other.name==track.parentPart then if found then return nil end;found=other.id end end;return found
    end
    local seen={}
    local function append(track,depth)
     if seen[track.id]then return end;seen[track.id]=true
     local hasChildren=false;for _,other in ipairs(rigTracks)do if parentId(other)==track.id then hasChildren=true end end
     table.insert(result,{kind="Track",item=item,track=track,name=track.name,indent=math.min(6,depth),hasChildren=hasChildren})
     if track.expanded~=false then for _,other in ipairs(rigTracks)do if parentId(other)==track.id then append(other,depth+1)end end end
    end
    for _,track in ipairs(rigTracks)do if not byId[parentId(track)]then append(track,2)end end
    for _,track in ipairs(rigTracks)do if not seen[track.id]and not byId[parentId(track)]then append(track,2)end end
   end end
   if #properties>0 then table.insert(result,{kind="Properties",item=item,name="Properties",indent=1});if item.propertiesExpanded~=false then for _,t in ipairs(properties)do table.insert(result,{kind="Track",item=item,track=t,name=t.name,indent=2})end end end
  end
 end
 return result
end
local function frameAt(input)return math.clamp(math.floor((input.Position.X-grid.AbsolutePosition.X-10)/state.px+0.5),0,state.project.duration)end
local function selectKey(track,key,shift)
 local members={};local selected={};for _,ref in ipairs(state.selected)do selected[ref.keyId]=ref end
 if key.group then
  for _,candidate in ipairs(state.project.tracks)do for _,entry in ipairs(candidate.keys)do if entry.group==key.group then table.insert(members,{trackId=candidate.id,keyId=entry.id})end end end
 else members={{trackId=track.id,keyId=key.id}}end
 local all=true;for _,ref in ipairs(members)do if not selected[ref.keyId]then all=false end end
 if shift and all then for _,ref in ipairs(members)do selected[ref.keyId]=nil end
 else if not shift and not all then selected={}end;for _,ref in ipairs(members)do selected[ref.keyId]=ref end end
 state.selected={};for _,ref in pairs(selected)do table.insert(state.selected,ref)end
 return state.selected
end
local function keyDrag(input,track,key)
 if track.locked or key.locked then return end
 choose(track);state.playing=false;state.frame=key.frame
 local shift=Input:IsKeyDown(Enum.KeyCode.LeftShift)or Input:IsKeyDown(Enum.KeyCode.RightShift)
 selectKey(track,key,shift)
 if #state.selected==0 then state.drag=nil;return render()end
 state.drag={kind="Key",x=input.Position.X,from=key.frame,keyId=key.id,trackId=track.id,offset=0,before=Engine.clone(state.project),selection=Engine.clone(state.selected)};paint()
end
local function selectRange(first,last,trackIds,additive)
 local refs={};if additive then for _,ref in ipairs(state.selected)do refs[ref.keyId]=ref end end
 local groups={};first,last=math.min(first,last),math.max(first,last)
 for _,track in ipairs(state.project.tracks)do if not track.locked and(not trackIds or trackIds[track.id])then
  for _,key in ipairs(track.keys)do if not key.locked and key.frame>=first and key.frame<=last then refs[key.id]={trackId=track.id,keyId=key.id};if key.group then groups[key.group]=true end end end
 end end
 for _,track in ipairs(state.project.tracks)do if not track.locked then for _,key in ipairs(track.keys)do if not key.locked and key.group and groups[key.group]then refs[key.id]={trackId=track.id,keyId=key.id}end end end end
 state.selected={};for _,ref in pairs(refs)do table.insert(state.selected,ref)end
 return state.selected
end
local function timeline()
 local width,height=math.max(420,root.AbsoluteSize.X),math.max(180,root.AbsoluteSize.Y)
 state.left=math.clamp(state.left,130,width-170)
 button(root,"+",6,25,20,23,function()addDialog()end,{flat=true,color=C.cyan})
 local loopControl=button(root,"",28,25,20,23,function()checkpoint();state.project.loop=not state.project.loop;paint()end,{flat=true,color=C.accent})
 for _,segment in ipairs({{4,7,11,1,0},{6,14,11,1,0},{12,5,5,1,45},{12,9,5,1,-45},{3,12,5,1,-45},{3,16,5,1,45}})do make("Frame",{Position=UDim2.fromOffset(segment[1],segment[2]),Size=UDim2.fromOffset(segment[3],segment[4]),Rotation=segment[5],BackgroundColor3=C.accent,BorderSizePixel=0},loopControl)end
 button(root,"•••",51,25,29,23,function()settingsDialog()end,{flat=true,color=C.accent})
 timeLabel=label(root,"",92,23,state.left-97,18,{color=C.text,size=11,align="Right"})
 countLabel=label(root,"",7,41,state.left-12,11,{color=C.accent,size=9,align="Right"})
 rowLabels=make("Frame",{Position=UDim2.fromOffset(5,58),Size=UDim2.fromOffset(state.left-5,height-86),BackgroundTransparency=1,ClipsDescendants=true},root)
 local content=make("Frame",{Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(state.left-6,math.max(5000,#state.project.tracks*42)),BackgroundTransparency=1},rowLabels)
 scroll=make("ScrollingFrame",{Position=UDim2.fromOffset(state.left+7,23),Size=UDim2.new(1,-state.left-14,1,-48),BackgroundColor3=C.background,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.XY},root)
 local rowData=rows();state.visibleRows=rowData
 local view=state.timelineView or Vector2.new();local viewWidth=math.max(170,width-state.left-14)
 local function inView(frame)local x=10+frame*state.px;return x>=view.X-30 and x<=view.X+viewWidth+30 end
 local canvasWidth=math.max(scroll.AbsoluteSize.X,state.project.duration*state.px+24)
 grid=make("Frame",{Size=UDim2.fromOffset(canvasWidth,35+#rowData*21),BackgroundTransparency=1},scroll)
 scroll.CanvasSize=UDim2.fromOffset(canvasWidth,35+#rowData*21)
 local ruler=make("TextButton",{Text="",Size=UDim2.fromOffset(canvasWidth,35),BackgroundTransparency=1,AutoButtonColor=false,BorderSizePixel=0},grid)
 local stride=state.px>=7 and 5 or state.px>=3 and 15 or 30;while state.project.duration/stride>250 do stride=stride*2 end
 for f=0,state.project.duration,stride do
  local x=10+f*state.px;if inView(f)then label(ruler,tostring(f),x-12,0,30,18,{color=C.accent,size=11,align="Center"})
  make("Frame",{Position=UDim2.fromOffset(x,19),Size=UDim2.fromOffset(1,7),BackgroundColor3=C.accent,BorderSizePixel=0},ruler)
  if not state.hideColumns then make("Frame",{Position=UDim2.fromOffset(x,35),Size=UDim2.new(0,1,1,-35),BackgroundColor3=C.accent,BackgroundTransparency=0.91,BorderSizePixel=0},grid)end
  end
 end
 local occupied={};for _,track in ipairs(state.project.tracks)do for _,key in ipairs(track.keys)do if inView(key.frame)then occupied[key.frame]=true end end end
 for frame in pairs(occupied)do make("Frame",{Position=UDim2.fromOffset(10+frame*state.px,28),Size=UDim2.fromOffset(1,5),BackgroundColor3=C.accent,BorderSizePixel=0},ruler)end
 make("Frame",{Position=UDim2.fromOffset(10,29),Size=UDim2.fromOffset(state.project.duration*state.px,1),BackgroundColor3=C.accent,BorderSizePixel=0},ruler)
 ruler.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then state.drag={kind="Scrub"};seek(frameAt(input))end end)
 for index,row in ipairs(rowData)do
  local y=(index-1)*21;if y+21>=view.Y-42 and y<=view.Y+height then
  local isActive=row.track and row.track.id==state.activeTrack or row.kind=="Item"and row.item.id==state.activeItem
  local back=row.kind=="Item"and(isActive and C.accent or C.title)or C.background
  local leftRow=make("Frame",{Position=UDim2.fromOffset(0,y),Size=UDim2.fromOffset(state.left-6,21),BackgroundColor3=back,BackgroundTransparency=0,BorderSizePixel=0},content)
  local text=(row.kind=="Item"and""or row.kind=="Rig"and(row.item.rigExpanded~=false and"▼ "or"▶ ")or row.kind=="Properties"and(row.item.propertiesExpanded~=false and"▼ "or"▶ ")or"")..row.name
  local control=button(leftRow,text,row.kind=="Item"and 26 or 2+row.indent*7+(row.track and 12 or 0),0,state.left-42-row.indent*7,21,function()
   if row.track then
    choose(row.track);local previous=state.clickTimes[row.track.id]or 0;local now=os.clock();state.clickTimes[row.track.id]=now
    if now-previous<0.3 then addKey()end
   else
    local previous=state.clickTimes[row.item.id]or 0;local now=os.clock();state.clickTimes[row.item.id]=now
    if row.kind=="Item"and now-previous<0.3 then state.activeItem=row.item.id;state.activeTrack=nil;return addDialog(row.item)end
    state.activeItem=row.item.id;state.activeTrack=nil;if row.kind=="Item"then row.item.expanded=not(row.item.expanded~=false)elseif row.kind=="Rig"then row.item.rigExpanded=not(row.item.rigExpanded~=false)else row.item.propertiesExpanded=not(row.item.propertiesExpanded~=false)end end;render()
  end,{flat=true,color=row.kind=="Item"and C.text or isActive and C.accent or C.text});control.TextXAlignment=Enum.TextXAlignment.Left
  if row.track then
   control.MouseButton2Click:Connect(function()choose(row.track);menu("Keyframe",5)end)
   if row.hasChildren then button(leftRow,row.track.expanded~=false and"▼"or"▶",2+row.indent*7,0,11,21,function()row.track.expanded=not(row.track.expanded~=false);render()end,{flat=true,size=10})else label(leftRow,"▼",2+row.indent*7,0,11,21,{color=isActive and C.accent or C.title,size=9})end
   local visibility=button(leftRow,"",state.left-41,0,18,21,function()checkpoint();row.track.enabled=not(row.track.enabled~=false);runtime:apply(state.project,state.frame);render()end,{flat=true})
   visibility.Name="TrackVisibility"
   local eye=make("Frame",{Position=UDim2.fromOffset(2,7),Size=UDim2.fromOffset(13,8),BackgroundColor3=row.track.enabled~=false and C.text or C.border,BorderSizePixel=0},visibility)
   make("UICorner",{CornerRadius=UDim.new(1,0)},eye)
   local pupil=make("Frame",{Position=UDim2.fromOffset(4,1),Size=UDim2.fromOffset(5,6),BackgroundColor3=C.background,BorderSizePixel=0},eye);make("UICorner",{CornerRadius=UDim.new(1,0)},pupil)
   local status=button(leftRow,"",state.left-23,0,15,21,function()checkpoint();row.track.locked=not row.track.locked;render()end,{flat=true})
   local square=make("Frame",{Position=UDim2.fromOffset(3,7),Size=UDim2.fromOffset(8,8),BackgroundColor3=isActive and C.accent or C.text,BackgroundTransparency=row.track.locked and 0.7 or 0,BorderSizePixel=0},status);make("UICorner",{CornerRadius=UDim.new(0,1)},square)
  end
  if row.kind=="Item"then
   label(leftRow,row.item.expanded~=false and"▼"or"▶",1,0,12,21,{size=10})
   local icon=make("Frame",{Position=UDim2.fromOffset(12,6),Size=UDim2.fromOffset(7,7),BackgroundColor3=C.title,BorderColor3=C.text,BorderSizePixel=1},leftRow)
   make("Frame",{Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(7,7),BackgroundColor3=C.border,BorderColor3=C.text,BorderSizePixel=1},icon)
   button(leftRow,"•••",state.left-42,0,21,21,function()state.activeTrack=nil;state.activeItem=row.item.id;menu("ItemContext",5)end,{flat=true})
   local status=make("Frame",{Position=UDim2.fromOffset(state.left-19,7),Size=UDim2.fromOffset(8,8),BackgroundColor3=C.text,BorderSizePixel=0},leftRow);make("UICorner",{CornerRadius=UDim.new(0,1)},status)
  end
  if not row.track then control.MouseButton2Click:Connect(function()state.activeTrack=nil;state.activeItem=row.item.id;menu("ItemContext",5)end)end
  local gridRow=make("TextButton",{Text="",Position=UDim2.fromOffset(0,y+35),Size=UDim2.fromOffset(canvasWidth,21),BackgroundColor3=C.background,BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false},grid)
  gridRow.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then if row.track then choose(row.track)end
   local ctrl=Input:IsKeyDown(Enum.KeyCode.LeftControl)or Input:IsKeyDown(Enum.KeyCode.RightControl)or Input:IsKeyDown(Enum.KeyCode.LeftMeta)or Input:IsKeyDown(Enum.KeyCode.RightMeta)
   if ctrl then state.drag={kind="Select",firstFrame=frameAt(input),lastFrame=frameAt(input),firstIndex=index,lastIndex=index,additive=Input:IsKeyDown(Enum.KeyCode.LeftShift)or Input:IsKeyDown(Enum.KeyCode.RightShift)}
   local box=make("Frame",{BackgroundColor3=C.cyan,BackgroundTransparency=0.85,BorderColor3=C.cyan,BorderSizePixel=1,ZIndex=25},grid);state.drag.box=box
   else state.drag={kind="Scrub"};seek(frameAt(input))end end end)
  local keys=row.track and row.track.keys or{}
  if row.track then make("Frame",{Name="TrackGuide",Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(canvasWidth-20,1),BackgroundColor3=isActive and C.accent or C.title,BorderSizePixel=0},gridRow)end
  local ranges={};if row.track then for _,key in ipairs(keys)do if key.group then
   local range=ranges[key.group]or{first=key.frame,last=key.frame,key=key};ranges[key.group]=range
   if key.frame<range.first then range.first=key.frame;range.key=key end;range.last=math.max(range.last,key.frame)
  end end end
  local hidden={}
  for group,range in pairs(ranges)do if range.last>range.first and 10+range.last*state.px>=view.X-20 and 10+range.first*state.px<=view.X+viewWidth+20 then
   hidden[group]=true;local selected=false;for _,ref in ipairs(state.selected)do for _,key in ipairs(keys)do if key.group==group and ref.keyId==key.id then selected=true;break end end;if selected then break end end
   local capsule=button(gridRow,"",10+range.first*state.px-4,5,math.max(9,(range.last-range.first)*state.px+8),11,function()end,{flat=true})
   capsule.BackgroundTransparency=0;capsule.BackgroundColor3=C.key;make("UICorner",{CornerRadius=UDim.new(0,5)},capsule)
   make("UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1,Color=selected and C.accent or C.text},capsule)
   make("Frame",{Position=UDim2.fromOffset(5,4),Size=UDim2.new(1,-10,0,1),BackgroundColor3=C.text,BackgroundTransparency=0.4,BorderSizePixel=0},capsule)
   capsule.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then keyDrag(input,row.track,range.key)end end)
  end end
  for _,key in ipairs(keys)do if inView(key.frame)and not(key.group and hidden[key.group])then
   local selected=false;for _,ref in ipairs(state.selected)do if ref.keyId==key.id then selected=true end end
   local hue=({Linear=0.1,Constant=0,Sine=0.16,Quad=0.23,Cubic=0.32,Quart=0.4,Quint=0.48,Sextic=0.56,Expo=0.62,Circ=0.69,Back=0.76,Bounce=0.84,Elastic=0.92})[key.easing or"Linear"]
   local keyColor=state.easingColors and Color3.fromHSV(hue,0.65,0.9)or C.key
   local eventKey=row.track and(row.track.property=="Event"or row.track.property=="Action")
   local node=button(gridRow,key.locked and"▪"or"",10+key.frame*state.px-6,4,12,13,function()end,{flat=true})
   node.Name=eventKey and"EventKey"or"Keyframe";node.BackgroundTransparency=0;node.BackgroundColor3=eventKey and C.text or keyColor;node.BorderSizePixel=0
   make("UICorner",{CornerRadius=UDim.new(0,eventKey and 1 or 6)},node);make("UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=selected and 2 or 1,Color=selected and C.accent or C.text},node)
   make("Frame",{Name="Inset",Position=UDim2.fromOffset(4,5),Size=UDim2.fromOffset(3,3),BackgroundColor3=eventKey and C.border or C.text,BackgroundTransparency=eventKey and 0 or 0.3,BorderSizePixel=0},node)
   if row.track then node.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then keyDrag(input,row.track,key)end end)
   else node.MouseButton1Click:Connect(function()state.selected={};for _,t in ipairs(state.project.tracks)do if t.itemId==row.item.id then for _,k in ipairs(t.keys)do if k.frame==key.frame then table.insert(state.selected,{trackId=t.id,keyId=k.id})end end end end;seek(key.frame);render()end)end
  end end
  end
 end
 head=make("Frame",{Position=UDim2.fromOffset(10+state.frame*state.px,16),Size=UDim2.new(0,1,1,-16),BackgroundColor3=C.accent,BorderSizePixel=0,ZIndex=8},grid)
 make("Frame",{Position=UDim2.fromOffset(-4,0),Size=UDim2.fromOffset(9,12),BackgroundColor3=C.accent,BorderSizePixel=0,ZIndex=9},head)
 for _,marker in ipairs(state.project.markers)do local m=button(ruler,"▼",4+marker.frame*state.px,13,13,18,function()seek(marker.frame);markersDialog()end,{flat=true,color=C.cyan});m.ZIndex=10 end
 local thisScroll=scroll
 scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
  if not thisScroll.Parent then return end
  state.timelineView=thisScroll.CanvasPosition;content.Position=UDim2.fromOffset(0,-thisScroll.CanvasPosition.Y)
  if not state.updating and not state.viewportQueued and not state.drag then
   state.viewportQueued=true;task.defer(function()state.viewportQueued=false;if thisScroll.Parent then render()end end)
  end
 end)
 scroll.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton3 then state.drag={kind="Pan",x=input.Position.X,y=input.Position.Y,position=scroll.CanvasPosition}end end)
 scroll.InputChanged:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseWheel then state.px=math.clamp(state.px*(input.Position.Z>0 and 1.15 or 1/1.15),0.2,30);render()end end)
 button(root,"−",7,height-25,18,19,function()state.px=math.max(0.2,state.px/1.2);render()end,{flat=true,color=C.cyan})
 local zoomLine=make("Frame",{Position=UDim2.fromOffset(29,height-16),Size=UDim2.fromOffset(state.left-59,2),BackgroundColor3=C.border,BackgroundTransparency=0,BorderSizePixel=0},root)
 local knob=button(root,"",29+math.log(state.px/0.2)/math.log(150)*(state.left-66),height-21,11,11,function()end,{flat=true});knob.BackgroundTransparency=0;knob.BackgroundColor3=C.title
 knob.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then state.drag={kind="Zoom"}end end)
 button(root,"+",state.left-27,height-25,19,19,function()state.px=math.min(30,state.px*1.2);render()end,{flat=true,color=C.cyan})
 local overview=button(root,"",state.left+8,height-10,width-state.left-17,7,function()end,{flat=true})
 overview.Name="TimelineOverview";overview.BackgroundTransparency=0;overview.BackgroundColor3=C.accent
 for _,edge in ipairs({0,1})do make("Frame",{Position=UDim2.new(edge,edge==1 and -4 or 0,0,0),Size=UDim2.fromOffset(4,7),BackgroundColor3=C.title,BorderSizePixel=0},overview)end
 overview.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then state.drag={kind="Overview",x=overview.AbsolutePosition.X,width=overview.AbsoluteSize.X};seek((input.Position.X-overview.AbsolutePosition.X)/overview.AbsoluteSize.X*state.project.duration)end end)
 local divider=make("TextButton",{Text="",Position=UDim2.fromOffset(state.left,23),Size=UDim2.new(0,3,1,-48),BackgroundColor3=C.title,BackgroundTransparency=0,BorderSizePixel=0},root)
 divider.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then state.drag={kind="Divider",x=input.Position.X,left=state.left}end end)
end
paint=function()
 widget.Title=(state.editing and(state.project.name..(state.dirty and" *"or"").." - ")or"").."Keynova"
 if timeLabel then local seconds=math.floor(state.frame/state.project.fps);local f=math.floor(state.frame)%state.project.fps;timeLabel.Text=seconds..":"..string.format("%02d",f).." | "..(state.showSeconds and string.format("%.3fs",state.frame/state.project.fps)or(math.floor(state.frame).."f"))end
 if countLabel then local count=0;for _,t in ipairs(state.project.tracks)do count=count+#t.keys end;countLabel.Text=count.." KEYFRAMES | "..state.project.fps.." FPS"end
 if head then head.Position=UDim2.fromOffset(10+state.frame*state.px,16)end
end
render=function()
 if state.updating then return end;state.updating=true
 local oldScroll=scroll and scroll.CanvasPosition or state.timelineView
 timeLabel=nil;countLabel=nil;head=nil;scroll=nil;dropdown=nil;notification=nil;Gui.clear(root);root.BackgroundColor3=C.background
 make("Frame",{Name="MenuRule",Position=UDim2.fromOffset(3,21),Size=UDim2.new(1,-6,0,1),BackgroundColor3=C.title,BorderSizePixel=0},root)
 local x=4
 for _,name in ipairs({"File","Edit","Item","Keyframe","Frame","Camera","Options","Theme"})do local w=math.max(30,#name*5.6+10);local pos=x;button(root,name,x,1,w,20,function()menu(name,pos)end,{flat=true,color=name=="Theme"and C.accent or C.text});x=x+w end
 if state.editing then timeline();if oldScroll and scroll then scroll.CanvasPosition=Vector2.new(math.min(oldScroll.X,math.max(0,scroll.CanvasSize.X.Offset-scroll.AbsoluteSize.X)),math.min(oldScroll.Y,math.max(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)))end else launcher()end
 paint();updateHandles();state.updating=false
end

connect(Input.InputChanged,function(input)
 local drag=state.drag;if not drag or input.UserInputType~=Enum.UserInputType.MouseMovement then return end
 if drag.kind=="Select"then drag.lastFrame=frameAt(input);drag.lastIndex=math.clamp(math.floor((input.Position.Y-grid.AbsolutePosition.Y-35)/21)+1,1,#state.visibleRows)
  if drag.box and drag.box.Parent then drag.box.Position=UDim2.fromOffset(10+math.min(drag.firstFrame,drag.lastFrame)*state.px,35+(math.min(drag.firstIndex,drag.lastIndex)-1)*21);drag.box.Size=UDim2.fromOffset(math.max(1,math.abs(drag.lastFrame-drag.firstFrame)*state.px),(math.abs(drag.lastIndex-drag.firstIndex)+1)*21)end
 elseif drag.kind=="Overview"then seek((input.Position.X-drag.x)/drag.width*state.project.duration)
 elseif drag.kind=="Scrub"then seek(frameAt(input))
 elseif drag.kind=="Pan"and scroll then scroll.CanvasPosition=Vector2.new(math.clamp(drag.position.X-(input.Position.X-drag.x),0,math.max(0,scroll.CanvasSize.X.Offset-scroll.AbsoluteSize.X)),math.clamp(drag.position.Y-(input.Position.Y-drag.y),0,math.max(0,scroll.CanvasSize.Y.Offset-scroll.AbsoluteSize.Y)))
 elseif drag.kind=="Divider"then state.left=drag.left+input.Position.X-drag.x;render()
 elseif drag.kind=="Zoom"then local t=math.clamp((input.Position.X-root.AbsolutePosition.X-29)/(state.left-66),0,1);state.px=0.2*150^t;render()
 elseif drag.kind=="Key"then
  local delta=math.floor((input.Position.X-drag.x)/state.px+0.5);local p=Engine.clone(drag.before)
  local refs,err=Engine.retime(p,drag.selection,delta)
  drag.error=err
  if not err then state.project=p;state.selected=refs;drag.offset=delta;for _,track in ipairs(p.tracks)do if track.id==drag.trackId then for _,key in ipairs(track.keys)do if key.id==drag.keyId then state.frame=key.frame;drag.offset=key.frame-drag.from end end end end;runtime:apply(p,state.frame);render()end
 end
end)
connect(Input.InputEnded,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseButton3 then
  local drag=state.drag;state.drag=nil
  if drag and drag.kind=="Select"then
   if drag.box then drag.box:Destroy()end
   local ids={};for i=math.min(drag.firstIndex,drag.lastIndex),math.max(drag.firstIndex,drag.lastIndex)do local row=state.visibleRows[i];if row and row.track then ids[row.track.id]=true end end
   selectRange(drag.firstFrame,drag.lastFrame,ids,drag.additive);render()
  elseif drag and drag.kind=="Key"then
   if drag.offset~=0 then table.insert(state.undo,drag.before);state.redo={};state.dirty=true end
   render();if drag.error then message(drag.error)end
  end
 end
end)
connect(Input.InputBegan,function(input,processed)
 if not widget.Enabled or Input:GetFocusedTextBox()or(not state.focused and not plugin:IsActivated())then return end
 if input.UserInputType~=Enum.UserInputType.Keyboard then return end
 local key=input.KeyCode;local ctrl=Input:IsKeyDown(Enum.KeyCode.LeftControl)or Input:IsKeyDown(Enum.KeyCode.RightControl)or Input:IsKeyDown(Enum.KeyCode.LeftMeta)or Input:IsKeyDown(Enum.KeyCode.RightMeta)
 local shift=Input:IsKeyDown(Enum.KeyCode.LeftShift)or Input:IsKeyDown(Enum.KeyCode.RightShift)
 local alt=Input:IsKeyDown(Enum.KeyCode.LeftAlt)or Input:IsKeyDown(Enum.KeyCode.RightAlt)
 if key==Enum.KeyCode.Escape then if dropdown then dropdown:Destroy();dropdown=nil end;state.selected={};return end
 if ctrl and key==Enum.KeyCode.A then selectAll()
 elseif ctrl and key==Enum.KeyCode.B then state.handlesVisible=not state.handlesVisible;savePreferences();updateHandles()
 elseif ctrl and key==Enum.KeyCode.Space then toggleCamera()
 elseif alt and key==Enum.KeyCode.F then selectAll()
 elseif alt and key==Enum.KeyCode.B then state.onion=false;runtime:clearOnion()
 elseif shift and key==Enum.KeyCode.P then jumpDialog()
 elseif shift and key==Enum.KeyCode.O then rotateCamera()
 elseif shift and key==Enum.KeyCode.T then state.showSeconds=not state.showSeconds;savePreferences();paint()
 elseif shift and key==Enum.KeyCode.F then fitTimeline()
 elseif shift and key==Enum.KeyCode.K then operationDialog("Fill")
 elseif shift and key==Enum.KeyCode.L then operationDialog("Repeat")
 elseif key==Enum.KeyCode.M then operationDialog("Split")
 elseif key==Enum.KeyCode.Three or key==Enum.KeyCode.KeypadThree then operationDialog("Stretch")
 elseif key==Enum.KeyCode.Zero or key==Enum.KeyCode.KeypadZero then save()
 elseif key==Enum.KeyCode.Slash or key==Enum.KeyCode.KeypadDivide then if save()then closeFile()end
 elseif key==Enum.KeyCode.BackSlash then guard(closeFile)
 elseif key==Enum.KeyCode.KeypadEnter then play()
 elseif ctrl and key==Enum.KeyCode.S then save()
 elseif ctrl and key==Enum.KeyCode.Z then if shift then redo()else undo()end
 elseif ctrl and key==Enum.KeyCode.Y then redo()
 elseif ctrl and key==Enum.KeyCode.C then copyKeys(false)
 elseif ctrl and key==Enum.KeyCode.X then copyKeys(true)
 elseif ctrl and key==Enum.KeyCode.V then pasteKeys(shift)
 elseif ctrl and key==Enum.KeyCode.U then groupKeys(true)
 elseif ctrl and key==Enum.KeyCode.R then reflect()
 elseif ctrl and key==Enum.KeyCode.G then groupKeys(false)
 elseif ctrl and key==Enum.KeyCode.H then hide()
 elseif shift and key==Enum.KeyCode.I then importDialog()
 elseif key==Enum.KeyCode.Space then if shift then toggleItem()else play()end
 elseif key==Enum.KeyCode.Tab then checkpoint();state.project.loop=not state.project.loop;paint()
 elseif key==Enum.KeyCode.Equals or key==Enum.KeyCode.KeypadPlus then addKey()
 elseif key==Enum.KeyCode.Delete or key==Enum.KeyCode.Backspace then deleteKeys()
 elseif key==Enum.KeyCode.Seven or key==Enum.KeyCode.KeypadSeven then easingDialog()
 elseif key==Enum.KeyCode.Eight or key==Enum.KeyCode.KeypadEight then settingsDialog()
 elseif key==Enum.KeyCode.Nine or key==Enum.KeyCode.KeypadNine then addDialog()
 elseif key==Enum.KeyCode.One or key==Enum.KeyCode.KeypadOne then seek(0)
 elseif key==Enum.KeyCode.Four or key==Enum.KeyCode.KeypadFour or key==Enum.KeyCode.Left then seek(math.max(0,math.floor(state.frame)-1))
 elseif key==Enum.KeyCode.Six or key==Enum.KeyCode.KeypadSix or key==Enum.KeyCode.Right then seek(math.min(state.project.duration,math.floor(state.frame)+1))
 elseif key==Enum.KeyCode.Five or key==Enum.KeyCode.KeypadFive then exportAllRigs()
 elseif key==Enum.KeyCode.Two or key==Enum.KeyCode.KeypadTwo then collapseAll()
 elseif key==Enum.KeyCode.J then jump(false)
 elseif key==Enum.KeyCode.K then jump(true)
 elseif key==Enum.KeyCode.R then state.mode=state.mode=="Rotate"and"Move"or"Rotate";updateHandles()
 elseif key==Enum.KeyCode.G then resetPose()
 elseif key==Enum.KeyCode.F then focusItem()
 elseif key==Enum.KeyCode.B then setOnion(not state.onion)
 elseif key==Enum.KeyCode.N then applyOnion()end
end)
connect(widget.WindowFocused,function()state.focused=true end)
connect(widget.WindowFocusReleased,function()state.focused=false end)
connect(widget:GetPropertyChangedSignal("Enabled"),function()
 toggle:SetActive(widget.Enabled)
 if not widget.Enabled then if not state.uiHidden then state.playing=false;runtime:restore();runtime:clearOnion();plugin:Deactivate()end else state.uiHidden=false;plugin:Activate(false);render();runtime:apply(state.project,state.frame)end;updateHandles()
end)
connect(root:GetPropertyChangedSignal("AbsoluteSize"),function()if root.AbsoluteSize.X>0 then render()end end)
connect(Selection.SelectionChanged,function()
 if not widget.Enabled then return end
 if not state.editing then render();return end
 local selected=Selection:Get()[1]
 for _,t in ipairs(state.project.tracks)do local binding=runtime.bindings[t.id];if binding and(binding.instance==selected or binding.instance:IsA("Motor6D")and binding.instance.Part1==selected)then choose(t);render();break end end
end)
local wasRunning=RunService:IsRunning();local paintClock=0
connect(RunService.Heartbeat,function(dt)
 local running=RunService:IsRunning()
 if running~=wasRunning then wasRunning=running;if running then state.playing=false;runtime:restore();runtime:clearOnion();updateHandles()end end
 if running or not state.playing or(not widget.Enabled and not state.uiHidden)then return end
 advance(dt)
 paintClock=paintClock+dt;if paintClock>0.03 then paintClock=0;paint()end
end)
connect(toggle.Click,function()widget.Enabled=not widget.Enabled end)
connect(characterToggle.Click,charactersDialog);connect(weldToggle.Click,weldDialog)
local destroyed=false
local function destroy()
 if destroyed then return end;destroyed=true;state.playing=false;state.drag=nil
 for _,c in ipairs(connections)do c:Disconnect()end;connections={}
 for name,d in pairs(state.dialogs)do d:Destroy();state.dialogs[name]=nil end
 clearEventModules();runtime:destroy();gizmo:destroy();widget:Destroy();toolbar:Destroy()
end
connect(plugin.Unloading,destroy)
api.newFile=newFile;api.save=save;api.openSaved=openSaved;api.render=render;api.seek=seek;api.play=play;api.addKey=addKey;api.undo=undo;api.redo=redo;api.exportRig=exportRig;api.exportScene=exportScene;api.choose=choose;api.settings=settingsDialog;api.addItem=addDialog;api.easing=easingDialog;api.markers=markersDialog;api.import=importDialog;api.characters=charactersDialog;api.weld=weldDialog;api.reflect=reflect;api.setOnion=setOnion;api.groupKeys=groupKeys;api.editValue=editValue;api.applyOnion=applyOnion;api.reverseKeys=reverseKeys;api.advance=advance;api.previewEvent=previewEvent;api.exportFiles=exportFiles;api.exportAllRigs=exportAllRigs;api.closeFile=closeFile;api.fileExplorer=fileDialog;api.theme=themeDialog;api.gizmoSettings=gizmoDialog;api.editItem=function()addDialog(activeItem())end;api.event=eventDialog;api.action=actionDialog;api.selectAll=selectAll;api.lockKeys=lockKeys;api.gizmo=gizmo;api.readSave=Saves.read;api.writeSave=Saves.write;api.selectKey=selectKey;api.selectRange=selectRange;api.commands=menus;api.hideUI=hide;api.showUI=function()widget.Enabled=true end;api.destroy=destroy
render()
return api
