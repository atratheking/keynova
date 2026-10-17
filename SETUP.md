# Set up Keynova for free

Keynova is a completely free, MIT-licensed, independent reconstruction of Moon Animator 2's publicly visible interface and animation workflows. No purchase of Moon Animator is needed to run Keynova. It runs inside **Roblox Studio**, not in a web browser.

## Install the release

1. Download **[Keynova.rbxmx](https://github.com/atratheking/keynova/releases/latest/download/Keynova.rbxmx)**. If you downloaded the source ZIP instead, use the release link or build it as described below.
2. Open Roblox Studio, sign in normally and open a local place.
3. Show **Explorer** and find **ServerStorage**. Right-click ServerStorage, choose **Insert from File…**, and select the downloaded model. It contains one Script named **Keynova**.
4. Select that Script, then choose **Plugins → Save as Local Plugin**. Save it as **Keynova**. Studio should load the plugin.
5. Delete the staging Script from the place; keep the locally installed plugin.
6. Open the **Plugins** toolbar and click **Keynova**.

Studio's menu layout can vary. The Script's right-click menu may also offer **Save as Local Plugin**. [Roblox's official local-plugin instructions](https://create.roblox.com/docs/studio/plugins) describe the same installation method.

### Text-script alternative

Download **[Keynova.plugin.lua](https://github.com/atratheking/keynova/releases/latest/download/Keynova.plugin.lua)**. Create a Script in ServerStorage, replace its entire source with that file, select it and follow steps 4–6 above. Run it as a plugin, not as a normal play-test Script. No HTTP-request setting, LoadString setting or unrelated software installation is needed.

### Update

Download the new release and repeat the local-plugin installation using the same plugin name. Replace the existing local plugin when Studio prompts. Remove an older duplicate through Studio's plugin management if you installed under a different name. Save and back up your Studio place before changing versions.

## Your first animation

1. In Keynova, choose **New Keynova File**.
2. Select a rig Model in Studio's Explorer. Use a rig with Motor6D joints or Bones.
3. Choose **Item → Add…** (`9`), enable Rig and click **OK**.
4. Choose a joint row. At frame 0, press `=` to record a pose.
5. Scrub to another frame. Move/rotate with Keynova's gizmo to record the next pose; `R` changes the gizmo mode.
6. Press **Space** to play/pause and **Tab** to toggle looping. `7` edits keyframes; `8` opens animation settings.
7. Use **File → Save**, then save the Studio place normally. Multi-item projects live in `ServerStorage.KeynovaSaves`; rig-specific projects live in the rig's `AnimSaves`.
8. Use **File → Export Rigs** for native KeyframeSequences. The rig's `AnimSaves` contains the result. Publishing an animation to Roblox is a separate action using your own account and asset permissions.

For a non-rig object or camera, select it and use **Item → Add…** to choose properties. See the [README](README.md) for camera, event, effects and export workflows.

## Build from source

Requires **Node.js 24.18.0** and npm. Roblox Studio is required for the native preview and native integration tests; Node.js is not needed after installing the built plugin.

```sh
git clone https://github.com/atratheking/keynova.git
cd keynova
npm ci
npm run build
```

Install `build/Keynova.rbxmx` with the release instructions above.

```sh
npm test
npm run test:studio
npm run preview
npm run preview -- --launcher
```

The preview opens a new disposable local Studio place with a sample scene. It does not install a persistent plugin or publish a Roblox asset.

The runner defaults to `/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio` on macOS. If needed, set `KEYNOVA_STUDIO_PATH` to your actual Studio executable. For example, on Windows PowerShell:

```powershell
$env:KEYNOVA_STUDIO_PATH = 'C:\path\to\RobloxStudioBeta.exe'
npm run preview
```

Use your installed executable's actual path. Native integration was verified on macOS; other platforms have not been comprehensively exercised.

## Troubleshooting

- **“Keynova must run as a Studio plugin”:** use Save as Local Plugin and delete the staging Script. Do not run the staging Script with Play.
- **No toolbar button:** check Studio's Plugins tab and plugin management. Restart Studio after installing if necessary; check Output for errors.
- **No rig joints:** select the rig Model, not an individual limb. Check that its Motor6D/Bone hierarchy is valid.
- **Missing saved items:** open the original Studio place and rebind the project item to the intended instance. Saves reference objects in that place.
- **Cannot import or play an asset:** check Roblox ownership, permissions and availability. Installing Keynova does not grant access to someone else's assets.
- **Generic toolbar icon:** the custom K logo is in the launcher. A portable custom toolbar image needs a published Roblox image asset ID; see [branding](branding/README.md).

## Compatibility

Keynova has its own project format. Original Moon Animator saves and every current Moon feature are not certified compatible. Supported areas and known gaps are documented in [FEATURES.md](docs/FEATURES.md). No original paid plugin, cracked copy, account credential or license bypass is included.
