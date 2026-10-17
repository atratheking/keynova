# Executed verification — 17 October 2026

Keynova 0.3.0 was built and exercised on macOS in Roblox Studio **0.743.0.7431133**, using disposable local places. No original Moon package was available. These checks establish Keynova behavior, not complete Moon feature or visual parity.

## Executed checks

`npm test` passed all **3** package checks: native Lua modules and the generated bundle parse; installable XML embeds that bundle exactly; no web application/runtime remains.

`npm run test:studio` passed **920 native checks** for the logo/launcher build:

| Suite | Checks |
| --- | ---: |
| Original engine semantics | 565 |
| Expanded engine/types/timing | 151 |
| Theme validation | 20 |
| Native storage/chunking/ownership | 16 |
| Gizmo geometry/drag/cancellation | 32 |
| Property/rig/runtime integration | 26 |
| Import/export/native scene playback | 43 |
| Editor commands and large-file workflows | 30 |
| Sample scene and lifecycle smoke | 37 |

The runner prints pass markers and the location of its result/startup logs. The development run logs were retained locally; they are not bundled as public artifacts. Interactive previews skip the final two teardown checks to leave the editor open.

Checks exercise actual native Instances and assignments: Motor/Bone trees, NumberPose channels, composite native values, stable renamed references, sparse easing/weights, generated ModuleScript playback, whitelisted actions, opt-in event Begin/End, original property restoration, onion key insertion, grouped selection, locks, atomic failed edits, save corruption/omission and owned-folder cleanup. The scene player embeds the same Engine/Properties sources as the editor.

The final native launcher and timeline were also visually inspected. The custom toolbar image has not been uploaded to Roblox; the ribbon retains the bundled icon until a published image asset ID is configured.

## Representative completed workflow

A 1,000-key legacy JSON CFrame project was reopened through the public `openSaved` boundary on the same installed Studio. Each sample includes JSON validation, binding and synchronous GUI rendering. These are single warm-context observations, not statistical or cold-run benchmarks.

| Implementation | Lua `os.clock` elapsed | Editor GUI descendants |
| --- | ---: | ---: |
| Earlier Keynova implementation retained during development | 0.068456 s | 9,248 |
| Final logo/launcher build | 0.013518 s | 1,457 |

The 4,000-key workflow writes checked UTF-8 chunks, reopens every key, renders the visible window, exports baked values and reads every key back through its metadata reader. The final run reported **0.035971 s** for reopening/rendering and **1,457** editor GUI descendants. The earlier representation exceeded Roblox's individual StringValue limit and could not complete this workload, so no before/after elapsed comparison is claimed for it.

An earlier full expanded suite was measured with `/usr/bin/time -l`: **9.77 s real**, **14.89 s user CPU**, **1.61 s system CPU**, OS-reported maximum RSS **3,216,769,024 bytes**. RSS was not a sampled aggregate of process-family physical memory. CPU and memory were not remeasured for subsequent appearance/logo changes. Agent token usage and process-family physical memory remain unmeasured. No general speedup or memory-percentage claim is inferred from these samples.

## Remaining limits

- No original Moon runtime comparison, package analysis, exact-current UI conformance or private-save round trip occurred.
- Native commands were exercised through their real owners; this is not exhaustive manual pointer/keyboard coverage of every control.
- Asset-ID imports, avatar insertion, audio permissions and audible synchronization were not comprehensively exercised against live Roblox services.
- Native Bone/FaceControls values and exports were checked; production skinned meshes and dynamic heads were not visually compared.
- Other operating systems, every production rig, simultaneous rig-scale retargeting, legacy Cubic variation and third-party addons are not comprehensively verified.

See [FEATURES.md](FEATURES.md), [VISUAL.md](VISUAL.md) and [REFERENCE.md](REFERENCE.md) for the detailed coverage and evidence boundary.
