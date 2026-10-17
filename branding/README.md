# Keynova logo

A copper K with a blue keyframe diamond, drawn from the geometry and palette in `logo.json`. The native launcher draws this mark directly, so it works without image downloads. It does not use the Moon Animator logo.

Run `python3 scripts/export-brand.py` from the Keynova directory to export SVG and 32/128/512px PNG versions into `build/branding/`. The exporter uses Pillow; it does not run during the normal plugin build. Both a rounded app tile and a transparent mark are available.

For the Studio ribbon, upload `build/branding/keynova-logo-128.png` as an image owned by the publishing Roblox account, put its image asset ID string into `logo.json`'s `toolbarAssetId`, and rebuild. Leave the field `null` until an image is published. Roblox's PluginToolbarButton supports asset URIs, so the plugin retains the bundled Studio animation icon until then; it does not pretend an unpublished local file is a portable toolbar image.

Official API restriction: https://create.roblox.com/docs/reference/engine/classes/PluginToolbarButton#IconContent
