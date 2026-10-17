# Keynova

<p align="center"><img src="branding/keynova-logo.svg" alt="Keynova logo" width="112" /></p>

**A completely free, open-source, reverse-engineered Moon Animator 2 reconstruction for Roblox Studio.**

Animate rigs, bones, properties, effects and cameras in a compact native Studio editor. Keynova is free to download, use and modify under the [MIT license](LICENSE), with no Keynova subscription, purchase or license key required.

The interface and workflows were independently reconstructed from public Moon Animator videos and screenshots. **This is an independent implementation, not the original Moon Animator plugin or a redistribution of its paid code.** Complete current-version feature parity and Moon save-file compatibility are unverified. See [feature coverage](docs/FEATURES.md) and the [reference ledger](docs/REFERENCE.md). Keynova is not affiliated with or endorsed by Moon Animator's creator.

## Free download and quick setup

**[Install Keynova free from the Roblox Creator Store](https://create.roblox.com/store/asset/101249387759167/Keynova)** — search **Keynova** in Studio's Toolbox under Plugins and choose the listing by **Derpyburger33333**, then click **Install**. The Creator Store listing is free.

The GitHub release remains available for manual installation:

1. [Download Keynova.rbxmx](https://github.com/atratheking/keynova/releases/latest/download/Keynova.rbxmx) from the [latest release](https://github.com/atratheking/keynova/releases/latest). No Node.js or build tools are needed to install it.
2. Open Roblox Studio and a local place. In Explorer, right-click **ServerStorage → Insert from File…** and select `Keynova.rbxmx`.
3. Select the inserted **Keynova** Script. Choose **Plugins → Save as Local Plugin**, name it Keynova and save. Some Studio versions also expose this on the Script's right-click menu.
4. Delete the staging Script from ServerStorage. The locally installed plugin remains available.
5. Open **Plugins → Keynova**. Character Inserter and Easy Weld have their own buttons.

For the text-script installation option, updates, troubleshooting and a first animation, see **[SETUP.md](SETUP.md)**. These steps follow [Roblox's local-plugin workflow](https://create.roblox.com/docs/studio/plugins).

Roblox services and third-party assets keep their own availability, permission and pricing rules. Keynova itself is completely free.

## Build from source and preview

Requires Node.js 24.18.0 for packaging/testing. The installed plugin has no Node.js dependency.

```sh
git clone https://github.com/atratheking/keynova.git
cd keynova
npm ci
npm run build
npm run preview
```

Preview opens a separate, disposable Studio place containing a sample rig, object, camera and the actual plugin. It uses Studio's documented command-line scripting support, installs no persistent plugin, publishes nothing and does not edit an existing place. Studio is required; set `KEYNOVA_STUDIO_PATH` if it is not at the standard macOS path. Close the preview when finished.

## Animate

Create a file, select an object/rig in Explorer, then **Item → Add…** (`9`). Motor6D and Bone hierarchies are supported; facial channels are added for FaceControls found in a rig. Right-click an item or double-click its name to edit/rebind/delete it.

Select a joint/property row. Move/rotate with the gizmos, or press `=` to record its current value. Rig gizmo edits auto-key. `R` changes move/rotate and `G` resets a pose. Options → Handles/Gizmos controls world/local axes, increments, size, depth and origin.

Scrub the ruler, wheel to zoom, middle-drag to pan, or drag the list divider. Shift-click adds/removes key selections; grouped keys select as a unit. Ctrl-drag selects a range across rows. Blue capsules represent grouped ranges. Edit provides cut/copy/paste/undo/redo; locks protect tracks and keys. Conflicting time edits are rejected rather than silently dropping unrelated keys.

`7` opens Easing/Value; `8` opens file settings. Easing includes 13 styles, four directions and Elastic amplitude/period. Value edits act on compatible selected keys, with pose weights for imported rig channels. Structured values use JSON component arrays, for example a NumberSequence `[[0,1,0],[1,0,0]]`.

Keyframe provides Fill, Split, Repeat, Stretch, Offset, Reverse and seeded Wiggle, including positional and angular modes. FPS rescaling updates duration/markers and rejects rounding collisions. Frame provides stepping, forward/backward playback, looping and fit-to-last-key.

Space plays/pauses; Tab loops; 1 starts; 4/6 step frames; J/K step keys. B toggles onion skin; N records its snapshot as actual keys. Options → Other clears skins. Hide UI preserves playback; closing the editor restores previewed properties.

## Properties, effects and events

Animate parts/models, decals/textures, FaceControls, particles/trails/beams, lights/post effects, camera, Terrain and other supported writable visual properties. Native property reflection discovers current facial channels. Enum and composite VFX/UI values retain typed interpolation; native sequences remain subject to Roblox's 20-point limit.

Sound and ParticleEmitter items offer an Actions track. Only supported methods can run. Sound/AudioPlayer action ownership is retained for pause/restore; access to actual audio assets follows Roblox permissions. Separate Moon audio addons' waveform features are not claimed.

Event tracks have names, values, a JSON dictionary of named data, duration, Code Begin and Code End. Authored code runs only when explicitly enabled for preview or when constructing an exported player with `RunEventCode=true`. Callbacks expose `context`, plus `parent` (target), `player`, `event` (key metadata) and `values` (named event data). Seeking does not execute actions/code. The plugin does not change LoadStringEnabled or Studio security settings.

Camera tracks include CFrame, FieldOfView, AttachToPart and LookAtPart. Selected-part bindings use stable references, including after renaming. Per-key baselines make seeks deterministic. Camera → Camera Export Reference makes exported CFrames relative to the selected part.

Easy Weld joins selected parts or models in place or at the base, with static Weld or animatable Motor6D modes. Existing animation-joint conflicts are rejected. Cleanup removes Keynova's own named joints.

## Save and export

Save editable files in `ServerStorage.KeynovaSaves`. The launcher's Rig Animation option binds a file to a rig and saves under its `AnimSaves`. Save the Studio place normally to retain them. File Explorer supports folders, rename/duplicate and recoverable trash. Save As makes an independent file.

Version 0.3 stores checked UTF-8 chunks and live ObjectValues under a small StringValue manifest to avoid Roblox's individual StringValue limit. Earlier unchunked Keynova version2 JSON remains readable. Missing/corrupt chunks fail closed; failed encoding preserves the preceding save. There is a 64 MiB serialized-save budget. These are **Keynova files**, not claims of Moon private-format compatibility.

Import accepts selected/saved KeyframeSequences or a permitted Roblox animation ID. Choose target rigs and Replace/Paste/Group options. Sparse native easing and pose weights are retained; legacy Cubic/CubicV2 map to Keynova's Cubic curve. Paste collisions are explicit errors.

Export Rigs bakes native KeyframeSequences to each keyed rig's `AnimSaves`, with Bone/Pose hierarchy, NumberPose faces and markers. Right-click a sequence and choose Save to Roblox to publish it yourself.

Export Files creates frame-indexed native values in `ServerStorage.KeynovaExports`, including camera Frames/FOV and stable references. Structured values use typed JSON. The full metadata is readable with `require(export.ReadMetadata)()`; large metadata is chunked. This baked schema is independently authored.

Export Scene Player produces a self-contained ModuleScript with the same Engine/Properties sources as the editor, so interpolation has one owner. Move it somewhere available to the calling script. Cameras normally play from a LocalScript. Generated player code includes authored event callbacks but executes them only after opt-in.

```lua
local Scene = require(path.To.ExportedScene)
local player = Scene.new() -- or Scene.new({RunEventCode = true})
player.Event.Event:Connect(function(phase, name, value, target, key)
    print(phase, name, value)
end)
player:Play()
-- player:Pause(); player:Seek(60); player:Stop(); player:Destroy()
```

Generation is bounded at 120,000 key/pose/frame values per operation/export. It reports excess rather than silently reducing fidelity. This is an explicit Keynova resource budget, not a claimed Moon limit.

## Verification and reference boundary

```sh
npm test
npm run test:studio
```

The package checks validate Lua modules, the combined plugin, XML embedding and absence of a browser runtime. Native suites exercise Engine, properties, bones/faces, geometry/dragging, events/actions, storage, import/export, scene playback, UI commands and cleanup. [Verification notes](docs/VERIFICATION.md) record the executed evidence and its limits.

[Reference ledger](docs/REFERENCE.md) links creator/firsthand sources. The original paid plugin was not acquired or decompiled; reconstruction uses the public references linked above. Exact current Moon behavior, private saves and every addon remain unverified. Studio controls outer window chrome.

Source modules are in `roblox/src/`; build output and dependencies are excluded from Git. Installable packages are distributed through GitHub Releases.

For the screenshot-based appearance comparison and its limits, see [VISUAL.md](docs/VISUAL.md).

The custom Keynova logo and export instructions live in [branding/README.md](branding/README.md). Run `npm run preview -- --launcher` to view the branded native launcher.
