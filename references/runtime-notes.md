# Runtime notes

## Native window frame boundary

The 30 pixel WorkBuddy caption and menu strip is outside the renderer viewport and cannot be reached by injected CSS. On Windows 10.0.19044, setting `DWMWA_USE_IMMERSIVE_DARK_MODE` succeeds but produces no visual change for this WorkBuddy window. Styling this strip would require replacing the Electron native frame and recreating caption controls, menu access and drag regions, which is outside the non-invasive CDP injection boundary.

The implementation uses Electron's remote debugging switch to expose CDP on a dynamically selected loopback port. The launcher verifies both the target list and the operating system listener owner before starting the injector.

The injector selects page targets with local renderer protocols, opens the target WebSocket, then evaluates a probe inside the renderer. A valid page needs a WorkBuddy title and `#root`. The payload combines the built in CSS, theme metadata, version and image data.

Inside the renderer, the payload creates a single style node and a pointer transparent decorative layer. CSS variables carry the palette. A debounced mutation observer tracks workspace changes, while CDP load events trigger reinjection after full navigation. Reapplying the payload first cleans the prior state, so repeated runs stay idempotent.

Restoration calls the renderer cleanup routine, disconnects the injector and optionally relaunches WorkBuddy without debugging switches. Since official application files remain untouched, an update does not require binary repair or signature recovery.
