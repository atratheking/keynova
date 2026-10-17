-- Animation property ownership: one catalog and one native read/write boundary.
local Properties={}
local catalogs={}
local supported={number=true,boolean=true,string=true,CFrame=true,Vector3=true,Color3=true,Vector2=true,UDim=true,UDim2=true,Rect=true,NumberRange=true,NumberSequence=true,ColorSequence=true}
local rules={
 {"Camera",{"FieldOfView","CFrame","AttachToPart","LookAtPart"}},
 {"BasePart",{"CFrame","Size","Transparency","Reflectance","Color","Material","Anchored","CastShadow"}},
 {"Model",{"CFrame","Scale","Color","Transparency","Reflectance"}},
 {"Lighting",{"ClockTime","Brightness","Ambient","OutdoorAmbient","ColorShift_Top","ColorShift_Bottom","FogStart","FogEnd","FogColor","ExposureCompensation","ShadowSoftness","GlobalShadows"}},
 {"Terrain",{"WaterColor","WaterTransparency","WaterReflectance","WaterWaveSize","WaterWaveSpeed"}},
 {"Decal",{"Texture","Color3","Transparency"}},
 {"Texture",{"StudsPerTileU","StudsPerTileV","OffsetStudsU","OffsetStudsV"}},
 {"ParticleEmitter",{"Enabled","Texture","Color","Transparency","Size","Squash","Rate","Speed","Lifetime","Rotation","RotSpeed","SpreadAngle","Acceleration","Drag","Brightness","LightEmission","LightInfluence","TimeScale","ZOffset","VelocityInheritance","LockedToPart","Orientation","EmissionDirection","Shape","ShapeStyle","ShapeInOut"}},
 {"Trail",{"Enabled","Color","Transparency","Lifetime","MinLength","MaxLength","WidthScale","Texture","TextureLength","TextureMode","LightEmission","LightInfluence","Brightness","FaceCamera"}},
 {"Beam",{"Enabled","Color","Transparency","Width0","Width1","CurveSize0","CurveSize1","Texture","TextureLength","TextureSpeed","TextureMode","LightEmission","LightInfluence","Brightness","FaceCamera","Segments"}},
 {"Light",{"Enabled","Brightness","Color","Shadows"}},
 {"PointLight",{"Range"}},{"SpotLight",{"Angle","Range","Face"}},{"SurfaceLight",{"Angle","Range","Face"}},
 {"Sound",{"SoundId","Volume","PlaybackSpeed","TimePosition","Looped","Playing","RollOffMinDistance","RollOffMaxDistance"}},
 {"PostEffect",{"Enabled"}},{"BloomEffect",{"Intensity","Size","Threshold"}},{"BlurEffect",{"Size"}},
 {"ColorCorrectionEffect",{"Brightness","Contrast","Saturation","TintColor"}},{"DepthOfFieldEffect",{"FarIntensity","FocusDistance","InFocusRadius","NearIntensity"}},
 {"SunRaysEffect",{"Intensity","Spread"}},{"Atmosphere",{"Color","Decay","Density","Glare","Haze","Offset"}},
 {"Sky",{"CelestialBodiesShown","MoonAngularSize","StarCount","SunAngularSize","SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp"}},
 {"SpecialMesh",{"Scale","Offset","VertexColor","MeshId","TextureId"}},
 {"GuiObject",{"Position","Size","Rotation","Visible","BackgroundColor3","BackgroundTransparency","BorderColor3","BorderSizePixel"}},
 {"TextLabel",{"Text","TextColor3","TextTransparency","TextStrokeColor3","TextStrokeTransparency","TextSize"}},
 {"TextButton",{"Text","TextColor3","TextTransparency","TextStrokeColor3","TextStrokeTransparency","TextSize"}},
 {"ImageLabel",{"Image","ImageColor3","ImageTransparency","ImageRectOffset","ImageRectSize"}},
 {"ImageButton",{"Image","ImageColor3","ImageTransparency","ImageRectOffset","ImageRectSize"}},
 {"CanvasGroup",{"GroupColor3","GroupTransparency"}},{"UIGradient",{"Color","Transparency","Offset","Rotation","Enabled"}},
 {"UIStroke",{"Color","Transparency","Thickness","Enabled"}},{"UIScale",{"Scale"}},{"Humanoid",{"CameraOffset"}},
 {"Shirt",{"ShirtTemplate"}},{"Pants",{"PantsTemplate"}},{"ShirtGraphic",{"Graphic"}},
 {"ValueBase",{"Value"}},
}
local blocked={Name=true,Parent=true,ClassName=true,Archivable=true,Source=true,Capabilities=true,UniqueId=true,HistoryId=true,Tags=true,Attributes=true,AttributesSerialize=true,AttributesReplicate=true}
function Properties.kind(value)
 local kind=typeof(value)
 if kind=="EnumItem"then return "string"end
 if supported[kind]then return kind end
 return nil
end
local appearance={Color=true,Transparency=true,Reflectance=true}
function Properties.read(object,property)
 if object:IsA("Model")and appearance[property]then
  local part=object:FindFirstChildWhichIsA("BasePart",true);return part and part[property]or(property=="Color"and Color3.new(1,1,1)or 0)
 end
 if property=="Pivot"or(property=="CFrame"and object:IsA("Model"))then return object:GetPivot()end
 if property=="Scale"and object:IsA("Model")then return object:GetScale()end
 return object[property]
end
function Properties.write(object,property,value,track)
 if object:IsA("Model")and appearance[property]then
  for _,part in ipairs(object:GetDescendants())do if part:IsA("BasePart")then part[property]=value end end;return
 end
 if property=="Pivot"or(property=="CFrame"and object:IsA("Model"))then object:PivotTo(value)
 elseif property=="Scale"and object:IsA("Model")then object:ScaleTo(math.max(0.001,value))
 else
  local current=object[property]
  if typeof(current)=="EnumItem"and type(value)=="string"then
   local converted=current.EnumType[value];assert(converted,"Unknown "..tostring(current.EnumType).." value: "..value);value=converted
  end
  object[property]=value
 end
end
function Properties.validate(object,property,value)
 local current=Properties.read(object,property)
 if typeof(current)=="EnumItem"then
  assert(typeof(value)=="EnumItem"and value.EnumType==current.EnumType or type(value)=="string"and current.EnumType[value],"Unknown enum value for "..property)
 else assert(typeof(current)==typeof(value),"Expected "..typeof(current).." for "..property)end
 return true
end

function Properties.capture(object,property)
 if object:IsA("Model")and appearance[property]then
  local snapshot={__keynovaSnapshot=true,values={}}
  for _,part in ipairs(object:GetDescendants())do if part:IsA("BasePart")then table.insert(snapshot.values,{target=part,value=part[property]})end end
  return snapshot
 end
 return Properties.read(object,property)
end
function Properties.restore(object,property,snapshot)
 if type(snapshot)=="table"and snapshot.__keynovaSnapshot then
  for _,entry in ipairs(snapshot.values)do if entry.target.Parent then Properties.write(entry.target,property,entry.value)end end
 else Properties.write(object,property,snapshot)end
end
function Properties.list(object)
 local cached=catalogs[object.ClassName]
 if cached then local result={};for i,name in ipairs(cached)do result[i]=name end;return result end
 local result,seen={},{}
 local function add(name)
  if seen[name]or blocked[name]then return end
  local virtual=name=="AttachToPart"or name=="LookAtPart"
  local ok,value=pcall(Properties.read,object,name)
  if virtual or(ok and Properties.kind(value))then seen[name]=true;table.insert(result,name)end
 end
 for _,rule in ipairs(rules)do if object:IsA(rule[1])then for _,name in ipairs(rule[2])do add(name)end end end
 -- Reflection supplies new FaceControls channels and engine properties without probing writes.
 -- Only public writable, nondeprecated members in the caller's own security context qualify.
 local ok,members=pcall(function()return game:GetService("ReflectionService"):GetPropertiesOfClass(object.ClassName)end)
 if ok and members then
  local extra={}
  for _,member in ipairs(members)do
   if member.Permits and member.Permits.Write~=nil and(not member.Display or not member.Display.DeprecationMessage)and not blocked[member.Name]then table.insert(extra,member.Name)end
  end
  table.sort(extra);for _,name in ipairs(extra)do add(name)end
 end
 catalogs[object.ClassName]=result
 local copy={};for i,name in ipairs(result)do copy[i]=name end;return copy
end
function Properties.actions(object)
 if object:IsA("Sound")then return {"Play","PlayOnce","Pause","Resume","Stop"}end
 if object:IsA("AudioPlayer")then return {"Play","Stop"}end
 if object:IsA("ParticleEmitter")then return {"Emit","Clear"}end
 return {}
end
function Properties.isAudio(object)return object:IsA("Sound")or object:IsA("AudioPlayer")end
function Properties.captureAudio(object)
 local loopProperty=object:IsA("Sound")and"Looped"or"Looping"
 return {time=object.TimePosition,playing=object.IsPlaying,loopProperty=loopProperty,looped=object[loopProperty]}
end
function Properties.pauseAudio(object)
 local position=object.TimePosition
 if object:IsA("Sound")then object:Pause()else object:Stop();object.TimePosition=position end
end
function Properties.resumeAudio(object)
 if object:IsA("Sound")then object:Resume()else object:Play()end
end
function Properties.restoreAudio(object,state)
 object:Stop();object[state.loopProperty]=state.looped
 if state.playing then object:Play()end
 object.TimePosition=state.time
end

function Properties.action(object,method,arguments)
 assert(table.find(Properties.actions(object),method),"This action is not supported by "..object.ClassName)
 if method=="PlayOnce"then object.Looped=false;object:Play()
 elseif method=="Emit"then
  local count=arguments and arguments[1]or 1
  assert(type(count)=="number"and count==count and count>=0 and count<=100000 and count%1==0,"Emit count must be a whole number from 0 to 100000")
  object:Emit(count)
 else object[method](object)end
end
return Properties
