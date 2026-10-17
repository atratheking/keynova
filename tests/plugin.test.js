import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import luaparse from 'luaparse';
const root=new URL('../',import.meta.url);
test('all native source modules and the bundled plugin parse without Lua syntax errors',async()=>{
 for(const name of await readdir(new URL('roblox/src/',root))){const source=await readFile(new URL('roblox/src/'+name,root),'utf8');try{assert.ok(luaparse.parse(source,{luaVersion:'5.3'}).body.length>0);}catch(error){throw new Error(`${name}: ${error.message}`);}}
 const source=await readFile(new URL('build/Keynova.plugin.lua',root),'utf8');assert.ok(luaparse.parse(source,{luaVersion:'5.3'}).body.length>0);
});
test('installable model embeds the generated plugin source exactly',async()=>{
 const source=await readFile(new URL('build/Keynova.plugin.lua',root),'utf8'),xml=await readFile(new URL('build/Keynova.rbxmx',root),'utf8');
 assert.ok(xml.includes('<Item class="Script"'));assert.ok(xml.includes(source.replaceAll(']]>',']]]]><![CDATA[>')));
});
test('deliverable has no browser application or web runtime dependencies',async()=>{
 const pkg=JSON.parse(await readFile(new URL('package.json',root),'utf8'));assert.equal(pkg.dependencies,undefined);
 for(const name of ['src/main.jsx','src/Viewport.jsx','index.html','vite.config.js'])await assert.rejects(stat(new URL(name,root)),{code:'ENOENT'});
});
