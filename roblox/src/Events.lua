-- One code-generation boundary for explicitly authored event callbacks.
-- Generated modules are required only after the caller opts into running code.
local Events={}
function Events.source(keys)
 local source={"return {"}
 for _,key in ipairs(keys)do
  if(key.codeBegin and key.codeBegin~="")or(key.codeEnd and key.codeEnd~="")then
   assert(type(key.id)=="string","Event needs a stable key ID")
   table.insert(source,"["..string.format("%q",key.id).."]={")
   for _,phase in ipairs({"Begin","End"})do
    local code=key["code"..phase]or"";assert(type(code)=="string","Event code must be text")
    table.insert(source,phase.."=function(context)\nlocal parent,player,event=context.Target,context.Player,context.Key\nlocal values=event.events or {}\n"..code.."\nend,")
   end
   table.insert(source,"},")
  end
 end
 table.insert(source,"}");return table.concat(source,"\n")
end
return Events
