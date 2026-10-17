-- Native save storage owns chunking, integrity and reference-folder identity.
local Saves={capacity=64*1024*1024,chunkSize=65536}
local Http=game:GetService("HttpService")
local crcTable={}
for i=0,255 do
 local value=i
 for _=1,8 do value=bit32.band(value,1)==1 and bit32.bxor(bit32.rshift(value,1),0xedb88320)or bit32.rshift(value,1)end
 crcTable[i]=value
end
local function checksum(text)
 local value=0xffffffff
 for i=1,#text do value=bit32.bxor(bit32.rshift(value,8),crcTable[bit32.band(bit32.bxor(value,string.byte(text,i)),255)])end
 return string.format("%08x",bit32.bnot(value))
end
local function manifest(entry)
 local ok,value=pcall(Http.JSONDecode,Http,entry.Value)
 return ok and type(value)=="table"and value.format=="keynova-packed"and value or nil
end
local function ownedFolder(entry,name,id)
 local found=nil
 for _,child in ipairs(entry:GetChildren())do if child.Name==name then
  assert(not found,"Saved folder identity is ambiguous")
  assert(child:IsA("Folder")and child:GetAttribute("KeynovaSaveOwner")==id,"Saved folder ownership is missing")
  found=child
 end end
 assert(found,"A saved data/reference folder is missing")
 return found
end
function Saves.read(entry)
 local ok,project,refs=pcall(function()
  assert(entry and entry:IsA("StringValue"),"Select a saved StringValue")
  local header=manifest(entry)
  if not header then return Http:JSONDecode(entry.Value),entry end
  assert(header.version==1 and type(header.id)=="string","Unknown save storage version")
  assert(type(header.bytes)=="number"and header.bytes>=1 and header.bytes<=Saves.capacity and header.bytes%1==0,"Saved payload exceeds the storage budget")
  assert(type(header.parts)=="number"and header.parts>=1 and header.parts%1==0 and header.parts<=math.ceil(header.bytes/(Saves.chunkSize-3)),"Saved part count is invalid")
  local data=ownedFolder(entry,header.data,header.id)
  local references=ownedFolder(entry,header.references,header.id)
  local parts={};local bytes=0;local count=0
  for _,part in ipairs(data:GetChildren())do
   assert(part:IsA("StringValue"),"Unknown saved payload member")
   local index=tonumber(part.Name)
   assert(index and index%1==0 and index>=1 and index<=header.parts and part.Name==string.format("%06d",index)and not parts[index],"Saved payload part identity is invalid")
   local value=part.Value;assert(#value>0 and #value<=Saves.chunkSize,"Saved payload part size is invalid")
   bytes=bytes+#value;assert(bytes<=header.bytes,"Saved payload length is inconsistent")
   parts[index]=value;count=count+1
  end
  assert(count==header.parts and bytes==header.bytes,"Saved payload is incomplete")
  local encoded=table.concat(parts)
  assert(checksum(encoded)==header.checksum,"Saved payload checksum does not match")
  return Http:JSONDecode(encoded),references
 end)
 if not ok then return nil,tostring(project)end
 return project,refs
end
-- Consumes only an unparented reference Folder. Failure preserves the old save.
function Saves.write(entry,project,references,encodedPayload)
 assert(references and references:IsA("Folder")and references.Parent==nil,"Pass an owned unparented references folder")
 local data=Instance.new("Folder");local committed=false
 local ok,failure=pcall(function()
  assert(entry and entry:IsA("StringValue"),"Save target must be a StringValue")
  local encoded=encodedPayload or Http:JSONEncode(project);assert(#encoded<=Saves.capacity,"Save exceeds the 64 MiB serialized storage budget")
  assert(utf8.len(encoded),"Saved JSON must be valid UTF-8")
  local id=Http:GenerateGUID(false)
  data.Name="KeynovaData_"..id;references.Name="KeynovaRefs_"..id
  data:SetAttribute("KeynovaSaveOwner",id);references:SetAttribute("KeynovaSaveOwner",id)
  local index,offset=0,1
  while offset<=#encoded do
   local last=math.min(#encoded,offset+Saves.chunkSize-1)
   if last<#encoded then last=utf8.offset(encoded,0,last+1)-1 end
   index=index+1
   local part=Instance.new("StringValue");part.Name=string.format("%06d",index);part.Value=string.sub(encoded,offset,last);part.Parent=data;offset=last+1
  end
  local header={format="keynova-packed",version=1,id=id,bytes=#encoded,parts=index,checksum=checksum(encoded),data=data.Name,references=references.Name}
  local value=Http:JSONEncode(header);local previous=manifest(entry)
  data.Parent=entry;references.Parent=entry
  entry.Value=value;committed=true
  -- Remove only resources whose stored identity proves this save owns them.
  if previous and type(previous.id)=="string"then
   for _,child in ipairs(entry:GetChildren())do
    if child:IsA("Folder")and child:GetAttribute("KeynovaSaveOwner")==previous.id and(child.Name==previous.data or child.Name==previous.references)then child:Destroy()end
   end
  end
 end)
 if not ok then if not committed then data:Destroy();references:Destroy()end;return false,tostring(failure)end
 return true
end
function Saves.writeFreshJSON(entry,value)
 assert(entry:IsA("StringValue")and entry.Value==""and #entry:GetChildren()==0,"Metadata writer requires a new owned StringValue")
 local ok,encoded=pcall(Http.JSONEncode,Http,value)
 if not ok then return false,tostring(encoded)end
 if #encoded<200000 then local stored,failure=pcall(function()entry.Value=encoded end);return stored,failure end
 return Saves.write(entry,nil,Instance.new("Folder"),encoded)
end
return Saves
