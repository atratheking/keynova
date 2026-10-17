# Reconstruction evidence — Moon Animator 2

Inspected 17 October 2026. Target: the Roblox Studio plugin by xsixx, official Creator Store asset 4725618216. The official listing displayed **Buy For $19.99**, updated **27 September 2026**, description version marker **V36000**. Reconstruction was limited to freely accessible public references. No original package was acquired; observations here are public interface/workflow evidence, not decompiled implementation facts.

## Creator video: observed workflows

[six — Moon Animator 2 Basics, official tutorial](https://www.youtube.com/watch?v=q8tGNMo_jHg), 21 December 2021. Player frames were directly inspected around 00:30–00:43, 01:10, 01:15, 01:20. The creator's chapter list supplies anchors for the later workflows.

| Time | Evidence |
| --- | --- |
| 00:20 | Character Inserter / R6 rig |
| 00:29–00:43 | Floating timeline over actual Studio viewport, rig hierarchy, transformation creates keyframes |
| 01:06–01:10 | Separate Edit Keyframes dialog with Easing / Value tabs, 13 easing types, four directions, graph |
| 01:13–01:20 | Animation Settings, FPS/length/priority, 7/8 shortcuts, wheel zoom and middle-pan |
| 01:40 / 01:56 | Easy Weld / prop attachment |
| 02:20 | Part/property animation |
| 03:10 / 03:41 | Camera animation / hide UI |
| 03:53 / 04:05 | Roblox animation export / import |
| 04:19 | Keyframe markers |

The 2021 menu uses Track / Time / Effects; later screenshots use Keyframe / Frame / Theme. Keynova consistently uses the later version, rather than combining those menu generations.

## Later firsthand screenshots, directly inspected

- [2023 production tutorial](https://iret.media/78488): [launcher](https://iret.media/wp-content/uploads/2023/08/6d83c9f9c7251d6722c63479dc58ab28.png), [Add Item](https://iret.media/wp-content/uploads/2023/08/AddItem.png), [camera properties](https://iret.media/wp-content/uploads/2023/08/AddItemCamera.png), [Import to Rig](https://iret.media/wp-content/uploads/2023/08/AnimationImport.png). Launcher has file/rig lists and central new/template controls. Camera offers FieldOfView, CFrame, AttachToPart, LookAtPart. Rig/model properties include CFrame, Scale and appearance. Import demonstrates Replace/Paste and grouping.
- [2024 settings screenshot](https://devforum.roblox.com/t/moon-animator-2-animation-looks-different-in-game/2943833): [full image](https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/b/8/4/7/b847603d6107d379b6d4ec62aceb90099102e1c6.png). Main window about 532×306 image pixels, settings about 205×202; menu File / Edit / Item / Keyframe / Frame / Camera / Options / Theme; cyan selection/playhead, amber controls and rounded keyframe rings. There is no permanent right-hand inspector.
- [2023 Item dropdown](https://devforum.roblox.com/t/moon-animator-export-issue/2474065): [image](https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/4/e/5/8/4e58fc83bd7b7f4ba576147f6e98c41811344df6.png). Exact order observed: Rig >, Add Effects >, Add… (9), View (F), Toggle All (Shift+Space), Collapse All (2), Jump To… (Shift+P).
- [2025 Edit Item screenshot](https://devforum.roblox.com/t/exporting-the-animation-of-a-camerapart-in-moon-animator/3708207): [image](https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/c/f/c/7/cfc771a0b92f2b60e06268a91545e11e36f95caa.png). Separate compact property dialog, Animation Events checkbox, scrollable properties, Delete / OK. No web shell or dedicated web viewport.
- [Full timeline in a custom theme](https://devforum.roblox.com/t/add-the-missing-easing-styles-for-animations/2397709): [original image](https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/b/b/0/4/bb04e0efd521f1e95073bc600ac126b77d009175.jpeg). 532px-wide floating panel, about 196px left list, ~21px rows, top + / loop / ellipsis and time, 60 FPS, ruler intervals of 15 at that zoom, actual R15 hierarchy, ring-shaped keys, lower zoom and scroll controls. Navy/cyan palette is explicitly a custom theme, not proof of exact default RGB constants.

## Firsthand behavior reports used with version limits

- [Sergeant Chilly, 2024 workflow](https://devforum.roblox.com/t/moon-animator-is-it-worth-it-about-moon-animator-and-how-to-use-it/2874657): R move/rotate, G reset, Space play, Tab loop, B/N onion skins, 7/8 dialogs, wheel zoom, middle-pan, Ctrl+R reflect, = record, 4/6 frames, J/K keys.
- [2020 introductory workflow](https://devforum.roblox.com/t/getting-started-with-moon-animator-2-unofficial/476330): grouping/ungrouping, repeat/stretch and camera attachment. Old-version evidence; no current default/algorithm is inferred from it.
- [Export discussion, 2022–2023](https://devforum.roblox.com/t/how-to-export-using-moon-animator-2/2092413): rig animations saved as KeyframeSequence under the rig's AnimSaves, independently of multi-item scene files.
- [Firsthand Easy Weld use](https://devforum.roblox.com/t/how-to-weld-a-weapon-to-a-players-model/1753550/3): select arm then prop, Join In Place preserves world transform.
- [Lunar Sound 2 listing](https://create.roblox.com/store/asset/13705760514): separate Moon audio addon. Its audio-import/waveform UI is not treated as a verified native Moon feature.

## Independent reconstruction choices and unresolved details

Default flat-color values were later sampled directly from historical PNG references, as documented in [VISUAL.md](VISUAL.md). Fonts and some measurements remain estimates; original source constants and present V36000 visuals are unknown. Studio owns native floating-window chrome. Internal easing math uses Roblox TweenService plus authored Sextic/OutIn behavior. Collision handling, stable IDs, JSON save schema, attachment offsets, resource bounds, editable rig saves, per-frame key grouping and standalone scene player are Keynova implementations, not claims about Moon internals.

Exact modern asset acquisition, all advanced rig/face controls, every theme and addon, original save compatibility, and exact keyframe grouping internals remain unverified without an authorized original build. Public reference coverage does not establish complete 1:1 parity. No cracked/reuploaded code or unofficial source-derived API documentation was used.

## Additional evidence used for the 0.3 feature audit

- [2025 Options/Gizmos screenshot](https://devforum.roblox.com/t/moon-animator-settings-randomly-revert-to-default-for-no-reason/4187154), posted 26 December 2025: Handles/Gizmos submenus, Use Last Ease, Easing Colors, Show Seconds, Hide Columns; Constant Size, Not Always On Top, Use Increment and Show Origin. Controls were directly inspected. Exact Handles submenu contents remain unknown.
- [2022 increment controls](https://devforum.roblox.com/t/cant-find-a-snap-to-grid-option-on-moon-animator/1938120): directly inspected earlier Gizmos submenu. Defaults and internal interaction math are not established.
- [Grouped duration bars](https://iret.media/wp-content/uploads/2023/08/db0f5ebe915a7e73b0a17de1b19beacd.png): directly inspected blue range capsules on imported/grouped rig tracks.
- [Tested N onion behavior](https://devforum.roblox.com/t/moon-animator-is-it-worth-it-about-moon-animator-and-how-to-use-it/2874657/3): firsthand author distinguishes applying a real pose from displaying a ghost.
- [Wiggle/Fill workflow](https://devforum.roblox.com/t/how-can-i-replicate-this-erratic-robotic-animation/2520327): firsthand users describe selecting two keys before filling. Keynova's waveform, seed, angular mode and collision policy are authored choices.
- [2024 mesh-deformation rig report](https://devforum.roblox.com/t/does-moon-animator-support-mesh-deformation-rigs/2861558) and [2025 bone/part report](https://devforum.roblox.com/t/how-to-attach-part-to-bone-and-later-animate-it/3515596): contemporary firsthand evidence supersedes 2021 reports that bones were unsupported.
- [VFX tutorial by Thundey](https://www.youtube.com/watch?v=7fSuvu3URMA), 5 April 2022, particle segment at 03:11 and trail/smear at 04:37; [Roblox Cinema Community tutorial](https://www.youtube.com/watch?v=fEELya_PZl8), 6 March 2020. Firsthand demonstration evidence; not a complete property catalog.
- [Event editor discussion](https://devforum.roblox.com/t/how-to-see-live-events-in-moon-animator-or-roblox-animator/3774719/9), 23 June 2025: Code Begin/End and named event data. Exact original code context is unknown; Keynova documents its own context and requires opt-in.
- [MoonAudio-Enabler creator listing](https://create.roblox.com/store/asset/89176962008004/MoonAudioEnabler-Moon-Animator-Addon): supports existence of sound method tracks. This is separate-addon evidence, not proof of a stock audio waveform editor.
- [2026 baked camera export report](https://devforum.roblox.com/t/frame-animation-function-built-around-moon-animator-2/4214289): firsthand user describes camera Frames/FOV/Settings and numeric ValueBase frame children.
- [2023 save/export walkthrough](https://iret.media/82542), 27 November 2023: directly inspected article and screenshots show historical StringValue JSON plus indexed item/property folders and default rest values. [File menu screenshot](https://iret.media/wp-content/uploads/2023/09/ExportMenu.png) establishes Save, Save As, Save and Close, Close, File Settings, Export Rigs, Import, Export Files, Toggle Loop, Play, Hide UI order in that version. It does not establish the complete V36000 save schema or all current controls.

Roblox primary API references informed the independently authored implementation: [ReflectionService](https://create.roblox.com/docs/reference/engine/classes/ReflectionService), [Bone](https://create.roblox.com/docs/reference/engine/classes/Bone), [NumberPose](https://create.roblox.com/docs/reference/engine/classes/NumberPose), [PoseBase](https://create.roblox.com/docs/reference/engine/classes/PoseBase), [native easing enum](https://create.roblox.com/docs/reference/engine/enums/PoseEasingStyle), and [Studio command-line interface](https://create.roblox.com/docs/studio/command-line-interface). The native sequence constructor limit and StringValue storage limit were additionally observed in the actual installed Studio; the tests retain those boundaries explicitly.

The feature list is now broader, but the unresolved current-version boundary above remains. A larger Keynova test count does not establish a complete Moon feature inventory.
