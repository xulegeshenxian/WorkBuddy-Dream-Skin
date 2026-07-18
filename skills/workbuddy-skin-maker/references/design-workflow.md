# Design workflow

## Contents

1. Image assessment
2. Appearance decision
3. Surface system
4. Decoration system
5. Historical task and artifact design
6. Implementation discipline

## Image assessment

Record these observations before selecting UI colors:

| Signal | Inspect | Design consequence |
| --- | --- | --- |
| Luminance | Overall brightness and brightest safe region | Light or dark appearance, overlay strength |
| Saturation | Dominant chroma and accent frequency | Accent intensity and neutral surface temperature |
| Subject | Face, body, product, architecture, focal point | Hero position and protected content area |
| Density | Foliage, texture, typography, small detail | Reading surface opacity and blur |
| Mood | Campus, youth, pastel, romance, night, cyber, luxury | Radius, shadow, typography, motion vocabulary |
| Motion | Hair, leaves, ribbons, particles, light trails | Decoration direction and animation amplitude |

Save the reasoning next to the implementation notes. If the image is ambiguous, inspect it at original resolution and compare a light and dark token draft before choosing.

## Appearance decision

Use the image as the primary signal.

| Image family | Default appearance | Surface direction |
| --- | --- | --- |
| Bright campus and youth | light | warm ivory, pale green, clear olive text |
| Pink portrait and botanical | light | blush, mint, soft cream, restrained rose accent |
| Editorial daylight | light | paper white, cool gray, ink text |
| Deep sea and night watch | dark | blue black, teal glass, luminous cyan accent |
| Gilded banquet and candlelight | dark | near black, warm ivory text, muted gold accent |
| Cyber and stage fantasy | dark | charcoal, controlled neon, low glare panels |

Override the default only after checking text contrast and focal point preservation. The chosen appearance must affect the whole system, including sidebar, top bar, composer, menus, dialogs, reading panels, artifact cards, hover, and focus.

## Surface system

1. Define background, panel, alternate panel, accent, alternate accent, secondary, highlight, text, muted text, and line colors.
2. Use stable opaque or nearly opaque reading surfaces over detailed photography.
3. Target at least 4.5 to 1 contrast for body text and 3 to 1 for large text and visible control boundaries.
4. Keep panel opacity high enough that text remains readable over the brightest and darkest image regions.
5. Separate hierarchy through tone, border, spacing, and shadow. Avoid relying on blur alone.
6. Verify functional white regions such as QR codes separately.

## Decoration system

1. Derive the decoration from the theme image or a matching transparent asset.
2. Use an asymmetric silhouette, layered frame, soft light, restrained particles, or a small orbit to create liveliness.
3. Animate with small transforms and opacity changes. Respect reduced motion.
4. Set `pointer-events: none` on the decoration root and descendants.
5. Hide or reposition it on chat, settings, dialogs, narrow windows, and any state where it intersects controls or artifacts.
6. Confirm it creates no horizontal overflow and no unexpected stacking context above interactive content.

## Historical task and artifact design

1. Give user messages and assistant responses separate readable surfaces.
2. Keep paragraph line height comfortable and preserve Markdown hierarchy.
3. Style skill tags, file tags, status pills, code blocks, tables, and blockquotes as part of the same reading system.
4. Give artifacts a named shelf, distinct cards, file metadata, action affordances, hover, focus, and a clear view all entry.
5. Prevent empty runtime nodes from creating blank visual strips.
6. Keep the composer fade short and ensure the scroll container has enough bottom space for the last response and artifact shelf.
7. Hide only decorative native imagery that demonstrably covers content. Preserve functional controls.

## Implementation discipline

1. Search existing CSS before adding a selector.
2. Scope rules under the theme root and page state.
3. Prefer semantic classes and CSS variables.
4. Add hashed class fragments only as compatibility fallbacks.
5. Keep reinjection idempotent and revoke replaced Blob URLs.
6. Test light and dark themes after any shared rule change.
7. Test maximized, narrow, hover, keyboard focus, and reduced motion states.
