---
name: workbuddy-skin-maker
description: Create, refine, diagnose, and release adaptive WorkBuddy Dream Skin themes in this project, including image driven light or dark UI selection, lively nonblocking decorations, readable chat and artifact surfaces, external CDP injection, and strict visual auditing. Use for WorkBuddy skin design, theme JSON or CSS changes, ornament work, historical task readability, artifact panel improvements, compatibility fixes, QA evidence, or release readiness checks.
---

# WorkBuddy Skin Maker

Build image responsive WorkBuddy skins while preserving the external CDP injection boundary. Treat automated and visual audits as release gates.

## Required reading

1. Read the project `AGENTS.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT.md`, and `docs/THEME-SCHEMA.md` before editing.
2. Read [design workflow](references/design-workflow.md) before selecting a palette, layout, surface opacity, or decoration.
3. Read [strict audit contract](references/strict-audit-contract.md) before testing, auditing, or reporting completion.

## Safety boundary

1. Keep all styling in the external CDP injector and project assets.
2. Never edit the WorkBuddy installation, executable, `app.asar`, signatures, or updater.
3. Bind CDP only to a loopback address and verify that its listener belongs to the selected `WorkBuddy.exe`.
4. Keep decorative nodes pointer transparent and hidden wherever they could cover chat, settings, dialogs, or artifacts.
5. Preserve the cleanup routine, reinjection idempotency, active theme backup, and normal restore path.
6. Do not let audit automation send messages, create content, save settings, grant authorization, upgrade an account, or sign out.
7. Preserve unrelated user changes in a dirty workspace.

## Workflow

### 1. Establish the baseline

1. Locate the project root from this Skill directory.
2. Inspect `VERSION`, `CHANGELOG.md`, active theme state, relevant selectors, and existing audit scripts.
3. Run static validation before editing. Use `scripts/run-strict-audit.ps1 -StaticOnly` from this Skill.
4. Capture a baseline screenshot for every affected page and state.
5. Record the WorkBuddy version, active theme ID, appearance, window size, and CDP port.

### 2. Derive the visual direction

1. Analyze every supplied image for luminance, saturation, subject location, visual density, mood, and safe areas.
2. Select `appearance: light` for bright campus, youth, pastel, botanical, soft portrait, and similar imagery unless measured contrast proves another mode is stronger.
3. Select `appearance: dark` for night, deep sea, gilded banquet, cyber, dramatic stage, and similar imagery.
4. Derive UI surfaces from the image mood. Avoid forcing every image into one dark shell.
5. Design the decoration as a theme specific companion. Give it depth, asymmetry, subtle motion, and responsive positioning. Keep it subordinate to task content.
6. Declare the intended hierarchy for background, hero, panels, reading surfaces, artifact shelf, composer, and decoration before coding.

### 3. Implement in layers

1. Prefer theme tokens and stable semantic selectors.
2. Use hashed selectors only as scoped compatibility fallbacks.
3. Keep text over photography on a stable reading surface. Do not depend on text shadow alone.
4. Give artifact output a dedicated shelf with a title, cards, file metadata, actions, hover, focus, and empty state.
5. Keep long conversations scrollable above the fixed composer. Verify both the first and last message.
6. Style normal, hover, selected, disabled, focus visible, modal, tooltip, and narrow window states together.
7. Keep QR codes and other functional images scannable.
8. Update `VERSION`, `CHANGELOG.md`, and architecture handoff documents for user visible or structural changes.

### 4. Refresh safely

1. Prefer hot reapplication when the recorded local CDP endpoint is valid.
2. Restart WorkBuddy only for the first CDP enabled launch or when explicitly required.
3. Run `scripts/verify-workbuddy-skin.ps1` after every refresh or theme switch.
4. Confirm exactly one intended injector process is active.

### 5. Execute strict audit

1. Run the automated gate for the current theme:

```powershell
& .\skills\workbuddy-skin-maker\scripts\run-strict-audit.ps1 `
  -ProjectRoot (Get-Location) `
  -ArtifactDirectory .\artifacts\strict-audit-current
```

2. Repeat the live gate with at least one representative light theme and one representative dark theme.
3. Inspect every generated screenshot at original resolution.
4. Create a manual review manifest only after completing the checks in the audit contract.
5. Run the gate again with `-ManualReviewManifest` to obtain release readiness.
6. Treat missing pages, missing screenshots, identical history top and bottom screenshots, nonzero audit exits, low contrast, overflow, occlusion, or unreviewed states as failures.
7. Never convert a known failure into a pass. Fix it or report the exact blocker and evidence.

### 6. Close the task

1. Stop every temporary server or debug helper started for testing.
2. Leave the intentional persistent injector running only when the user wants the skin active.
3. Restore the user selected theme after cross theme testing.
4. Report changed files, exact automated results, manual evidence, remaining failures, and recovery instructions.
5. Say the skin is release ready only when the strict audit report has `releaseReady: true`.

## Included resources

1. `scripts/run-strict-audit.ps1` runs deterministic static and live gates, stores raw logs, checks screenshot evidence, and validates the manual review manifest.
2. `references/design-workflow.md` defines image analysis and adaptive UI decisions.
3. `references/strict-audit-contract.md` defines the mandatory audit matrix, manual manifest, and failure policy.
