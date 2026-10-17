import { mkdir, readFile, writeFile } from 'node:fs/promises';
const root = new URL('../', import.meta.url);
const modules = [['Engine','Animation'],['Properties','Properties'],['Runtime','Runtime'],['Events','Events'],['Saves','Saves'],['Export','Export'],['Gui','Gui'],['Brand','Brand'],['Gizmo','Gizmo'],['Keynova','Plugin']];
let source = '-- Keynova 0.3 | Native Roblox Studio plugin\n-- Independent implementation from public visual and workflow references.\n';
for (const [name,file] of modules) {
 const body=await readFile(new URL(`roblox/src/${file}.lua`,root),'utf8');
 source += `\nlocal ${name} = (function()\n${body}\nend)()\n`;
 if(name==='Brand'){
  const spec=JSON.parse(await readFile(new URL('branding/logo.json',root),'utf8'));
  if(spec.toolbarAssetId!==null&&!/^[1-9][0-9]*$/.test(spec.toolbarAssetId))throw new Error('branding/logo.json toolbarAssetId must be null or a positive asset-ID string');
  const json=JSON.stringify(spec);
  source+=`Brand.spec=game:GetService("HttpService"):JSONDecode([==[${json}]==])\n`;
 }
 if(name==='Engine'||name==='Properties'||name==='Saves'){let delimiter='=';while(body.includes(']'+delimiter+']'))delimiter+='=';source+=`${name}.source=[${delimiter}[${body}]${delimiter}]\n`;}
}
const xml = `<roblox version="4"><Item class="Script" referent="KeynovaPlugin"><Properties><string name="Name">Keynova</string><bool name="Disabled">false</bool><ProtectedString name="Source"><![CDATA[${source.replaceAll(']]>', ']]]]><![CDATA[>')}]]></ProtectedString></Properties></Item></roblox>`;
await mkdir(new URL('build/',root),{recursive:true});
await Promise.all([writeFile(new URL('build/Keynova.plugin.lua',root),source),writeFile(new URL('build/Keynova.rbxmx',root),xml)]);
console.log('Built build/Keynova.rbxmx and build/Keynova.plugin.lua');
