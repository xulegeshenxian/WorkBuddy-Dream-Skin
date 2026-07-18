---
name: workbuddy-dream-skin
description: Install, start, customize, verify, diagnose, or restore the external WorkBuddy Windows desktop theme in this directory.
---

# WorkBuddy Dream Skin

Use the scripts in `scripts/` for all operations. Preserve the external injection boundary. Never edit the WorkBuddy installation, `app.asar`, executables, or signatures.

## Workflow

1. Read `README.md` and confirm Windows, Node.js 22, and WorkBuddy are available.
2. For first launch, warn that WorkBuddy will restart, then run `scripts/start-workbuddy-skin.ps1 -RestartExisting`.
3. Run `scripts/verify-workbuddy-skin.ps1` after every start or theme change.
4. Use `scripts/customize-workbuddy-theme.ps1` for image, layered artwork, composition, palette and decoration changes. Imported images use automatic style analysis by default; pass `-Style` for a deliberate palette, `-DecorationMode` for ornament behavior, or `-AnalyzeOnly` to preview the result.
5. Use `scripts/manage-workbuddy-themes.ps1` to list or apply saved presets.
6. If verification fails, inspect `%LOCALAPPDATA%\WorkBuddyDreamSkin\injector-error.log` and run `scripts/probe-workbuddy.ps1`.
7. Use `scripts/restore-workbuddy-skin.ps1 -RestartNormally` to return to an ordinary WorkBuddy launch.

Prefer hot reapplication when the verified CDP endpoint already exists. Restart WorkBuddy only when the first CDP enabled launch is required or the user requests it.
