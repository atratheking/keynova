# Visual comparison

The default appearance follows the gray/copper Moon Animator UI directly visible in these firsthand screenshots:

- [Timeline, empty tracks](https://iret.media/wp-content/uploads/2023/08/df67bff415de4659e07db8018e5aa6bf.png)
- [Timeline, property keyframes](https://iret.media/wp-content/uploads/2023/08/85cfdd21edb3235df326e54d91e6165a.png)
- [Timeline, grouped rig keyframes](https://iret.media/wp-content/uploads/2023/08/db0f5ebe915a7e73b0a17de1b19beacd.png)
- [Firsthand tutorial containing launcher and Add Item images](https://iret.media/78488)

These are historical 2023 references, not an observation of the current original plugin runtime.

## Applied appearance

Flat-color regions were sampled from the supplied public PNGs, rather than estimated from a theme description:

| Role | RGB / hex |
| --- | --- |
| Background | 33, 33, 33 / `#212121` |
| Header and scrollbar gray | 108, 113, 117 / `#6C7175` |
| Group outlines | 70, 74, 76 / `#464A4C` |
| Text and key outlines | 178, 187, 193 / `#B2BBC1` |
| Active item, track and time accent | 174, 102, 66 / `#AE6642` |
| Default key and grouped range fill | 23, 101, 184 / `#1765B8` |

The shared native controls use compact SourceSans text, flat backgrounds, subdued group borders and lighter button outlines. The launcher has three outlined columns with aligned placeholders. Add Item has nested outlines, compact checklist rows and the observed 272px content height when no action controls are needed.

The timeline has gray inactive item bands, copper active-item bands, copper active-track text, drawn visibility icons, small square status indicators, pale outlined blue keys with inset squares, neutral track guides and copper selected guides. Item headers no longer invent aggregate key bubbles. The footer includes separate horizontal scrolling and copper overview strips; the latter can seek through the project. Ruler labels use wider frame intervals when zoomed out.

Previously saved themes matching the exact earlier Keynova default migrate to these colors. Custom theme RGB values remain selected.

## Verification boundary

The actual native Studio preview was inspected after rendering. An initial unsupported disclosure glyph and overlapping item-label padding were corrected before the final preview. Native command, rendering and lifecycle checks were rerun; see [VERIFICATION.md](VERIFICATION.md).

Studio owns the floating window title bar, rounded outer shape, system fonts/chrome and display scaling. Those platform elements differ from the reference screenshots. The reconstruction does not include Moon's logo or third-party theme backgrounds. Every current-version dialog, hover state, menu position and pixel has not been verified against an authorized original runtime; this is a closer match to the observed reference, not certified pixel-identical current-version parity.
