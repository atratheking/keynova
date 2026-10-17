import './prepare-plugin.mjs';
import {readFile,writeFile,mkdtemp} from 'node:fs/promises';
import {openSync,closeSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import {randomUUID} from 'node:crypto';
const preview=process.argv.includes('--preview');
const launcherPreview=preview&&process.argv.includes('--launcher');
const executable=process.env.KEYNOVA_STUDIO_PATH||(process.platform==='darwin'?'/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio':null);
if(!executable)throw new Error('Set KEYNOVA_STUDIO_PATH to your Roblox Studio executable.');
const root=new URL('../',import.meta.url),folder=await mkdtemp(join(tmpdir(),'keynova-studio-'));
const suites=['engine-studio','parity-engine','parity-gui','parity-saves','parity-gizmo','parity-runtime','parity-export'];
const [plugin,smoke,...suiteSources]=await Promise.all([
 readFile(new URL('build/Keynova.plugin.lua',root),'utf8'),readFile(new URL('tests/studio-smoke.lua',root),'utf8'),
 ...suites.map(name=>readFile(new URL(`tests/${name}.lua`,root),'utf8')),
]);
const editor=await readFile(new URL('tests/parity-editor.lua',root),'utf8');
const source=`local KEYNOVA_PREVIEW=${preview}\nlocal plugin=PluginManager():CreatePlugin()\n${plugin}\n${suiteSources.map(body=>`do\n${body}\nend`).join('\n')}\nlocal KEYNOVA_EDITOR_TEST=function()\n${editor}\nend\ndo\n${smoke}\nend\n${launcherPreview?'Keynova.closeFile();Keynova.widget.Enabled=false;Keynova.showUI()\n':''}print("KEYNOVA_TEST_END")\nreturn true`;
const script=join(folder,'smoke.lua'),output=join(folder,'result.log'),startup=join(folder,'startup.log');
// The CLI echoes its script. Keep the entrypoint small so its output budget remains
// available for diagnostics; the actual native suite is a ModuleScript in this new place.
await writeFile(script,'local ok,result=xpcall(function() return require(game:GetService("ServerStorage"):WaitForChild("KeynovaNativeSuite"))end,debug.traceback)\nif not ok then warn("KEYNOVA_FAILURE "..tostring(result));error(result,0)end\n');
const place=join(folder,`Keynova-${randomUUID()}.rbxlx`);
const cdata=source.replaceAll(']]>',']]]]><![CDATA[>');
await writeFile(place,`<roblox version="4"><External>null</External><External>nil</External><Item class="Workspace"><Properties><string name="Name">Workspace</string></Properties></Item><Item class="Lighting"><Properties><string name="Name">Lighting</string><token name="Technology">5</token><token name="LightingStyle">0</token><bool name="PrioritizeLightingQuality">true</bool><float name="Brightness">2</float><float name="ClockTime">14</float></Properties></Item><Item class="ServerStorage"><Properties><string name="Name">ServerStorage</string></Properties><Item class="ModuleScript"><Properties><string name="Name">KeynovaNativeSuite</string><ProtectedString name="Source"><![CDATA[${cdata}]]></ProtectedString></Properties></Item></Item></roblox>`);
const log=openSync(startup,'w');
const args=['--task','RunScript','--runScriptFile',script,'--outputFile',output,'--localPlaceFile',place];
if(!preview)args.push('--quitAfterExecution');
const child=spawn(executable,args,{stdio:['ignore',log,log]});
if(preview){console.log(`Native Studio preview process ${child.pid}. Evidence: ${output}`);await once(child,'exit');closeSync(log);}else{
 const timeout=setTimeout(()=>child.kill('SIGTERM'),90000);
 try{
  await once(child,'exit');const result=await readFile(output,'utf8');
  const expected=['KEYNOVA_ENGINE_PASS','KEYNOVA_PARITY_ENGINE_PASS','KEYNOVA_GUI_PARITY_PASS','KEYNOVA_SAVES_PARITY_PASS','KEYNOVA_GIZMO_PARITY_PASS','KEYNOVA_RUNTIME_PARITY_PASS','KEYNOVA_EXPORT_PARITY_PASS','KEYNOVA_EDITOR_PARITY_PASS','KEYNOVA_NATIVE_SMOKE_PASS','KEYNOVA_TEST_END'];
  if(expected.some(marker=>!result.includes(marker))||/^KEYNOVA_FAILURE /m.test(result))throw new Error(`Studio verification failed. Inspect ${output} and ${startup}`);
  console.log(result.split('\n').filter(line=>/^KEYNOVA_/.test(line)).join('\n'));console.log(`Evidence: ${output}`);
 }finally{clearTimeout(timeout);closeSync(log);}
}
