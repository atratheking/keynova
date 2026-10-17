# Keynova 0.3 feature coverage

This is an implementation inventory for review. **It is not a certification that every feature in the current paid Moon Animator build has been reproduced.** No original package was available under the user's no-purchase constraint. Sources and observed version differences are recorded in [REFERENCE.md](REFERENCE.md).

| Area | Available in Keynova | Verification boundary |
| --- | --- | --- |
| Host/UI | Native Studio floating timeline and dialogs; File/Edit/Item/Keyframe/Frame/Camera/Options/Theme; compact gray/amber/cyan styling | Native construction and screenshot checked; exact current pixels/defaults unknown |
| Timeline | Scrub, wheel zoom, middle-pan, splitter, scrollbar/zoom slider, frame/key steps, frame/seconds display, key ticks, grid-column toggle | Native editor checks; long-timeline viewport rendering bounded |
| Selection | Individual/Shift selection, group selection and deselection, range selection with Ctrl-drag, Select All | Native editor checks; original gesture equivalence not established |
| Keys | Auto-key through gizmos, manual record, stable double-click recording, delete, cut/copy/paste, paste into track, undo/redo, key/track locks | Engine and editor checks |
| Grouping | Group/Ungroup, blue duration capsules, cross-track group movement, grouped import/template | Engine/editor checks; Moon's private group representation unknown |
| Timing | Fill, sampled Split, Repeat, Stretch, Offset, Reverse, fit length, FPS rescale with collision/lock rejection | Engine checks; authored algorithms and collision policy |
| Wiggle | Endpoint-preserving seeded waves for numbers, Vector3 and CFrame; position/rotation modes, amplitude/period/step/axis controls | Native numerical checks; original Wiggle algorithm/defaults unknown |
| Easing | 13 styles, four directions, graph, Elastic amplitude/period/reset, Use Last Ease, easing colors | Native interpolation checks; legacy native Cubic/CubicV2 mapped to Keynova Cubic |
| Rigs | Multiple R6/R15/custom Motor6D rigs, bone rigs, mixed hierarchies, track-node collapse, initial-pose restoration, reflection | Native Motor/Bone tests; arbitrary production rigs and simultaneous rig-scale retargeting not comprehensively verified |
| Gizmos | Move/rotate, local/world axes, translation/rotation increments, constant size, depth/on-top control, origin and size settings | Native geometry, drag math, cancellation and cleanup checks |
| Parts/models | CFrame, size, model scale/pivot, color/transparency/reflectance and other supported writable visual properties | Native assignments and restoration checks, including heterogeneous model appearance |
| Faces | Decal/Texture swaps and appearance; reflected FaceControls channels; NumberPose import/export | Native property/Pose tests; no visual facial-deformation test on a supplied production head |
| VFX | ParticleEmitter, Trail, Beam, lights, post effects, Atmosphere, Sky, Terrain and mesh property tracks | Real composite-property assignments and exported playback checked; not every asset/effect visually exercised |
| Other properties | Vector2, Vector3, CFrame, Color3, UDim, UDim2, Rect, NumberRange, NumberSequence, ColorSequence, numbers, strings, booleans and enums | Native round trips/interpolation; native 20-point sequence limit retained |
| Audio/actions | Sound/AudioPlayer playback properties and supported actions; Sound PlayOnce/Pause/Resume/Stop; ParticleEmitter Emit/Clear | Whitelist and ownership boundaries checked; audio asset permissions/audible synchronization not comprehensively tested |
| Events | Global markers, item events, named JSON event data, duration, Code Begin/End; opt-in authored code; preview and exported callbacks | Native event tests; code disabled by default; arbitrary execution environments not equivalent to Moon internals |
| Camera | CFrame/FOV, stable AttachToPart/LookAtPart, deterministic attachment baselines, export reference, rotation/value editor, track toggles, hide UI during playback | Native camera/reference tests; authored camera math |
| Onion skins | Ghost snapshots, toggle/clear, paste snapshot as real pose/keyframes | Native object creation, actual pose application and cleanup checks |
| File tools | Launcher/templates, folders, rename/duplicate, trash/restore, scene files and rig-linked editable files | Native construction, save/reopen tests; Keynova's own schema |
| Large saves | Checked UTF-8 chunks and exact ObjectValue references, corruption/incompleteness detection, atomic failure, prior JSON readability | Native storage tests; 64 MiB serialized budget; not Moon save compatibility |
| Import | Multiple rig targets, selected/saved KeyframeSequence, authenticated Roblox animation ID, Replace/Paste and grouping, sparse easing and weights | Native mixed-rig/face import tests; asset-ID network permissions not comprehensively exercised |
| Export | Selected/all rigs as KeyframeSequence, frame-indexed ValueBase folders, portable scene player, optional reference-relative cameras, metadata reader | Native hierarchy/playback/data tests; baked schema is Keynova-specific |
| Helper tools | R6/R15 avatar insertion by username/ID, static Weld and animatable Motor6D joins, model welding, own-joint cleanup | Weld/model checks; avatar network/body variants not comprehensively exercised |
| Preferences/themes | Default/Midnight, custom RGB and JSON import/export, persisted options/theme | Native validation/identity tests; original theme library/defaults unknown |

## Not established as complete

- Current V36000's complete menu/dialog inventory, exact algorithms, defaults and shortcuts.
- Reading/writing the private Moon project format or compatibility with every addon. The historical public save description is evidence, not sufficient conformance data.
- Every advanced Character Inserter/Easy Weld option and all production rig, avatar, skinning and audio combinations.
- Arbitrary curve-clip/FBX/BVH import, full IK/constraint solvers, animation blending layers or physics recording. The investigated primary references did not establish these as stock Moon features; they are not silently claimed as implemented.
- Lunar Sound/MILKYWAY or other separate addons' waveform import, theme libraries and integration APIs.

An authorized current build or a comprehensive current walkthrough exposing all controls is required to resolve these unknowns. Keynova's own tests cannot prove their absence or equivalence.
