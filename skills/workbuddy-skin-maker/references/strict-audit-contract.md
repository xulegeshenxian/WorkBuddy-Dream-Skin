# Strict audit contract

## Contents

1. Pass policy
2. Static gates
3. Live automated gates
4. Historical task sampling
5. Manual visual matrix
6. Manual review manifest
7. Evidence and cleanup

## Pass policy

1. A nonzero command exit is a failure.
2. A missing control, page, sample, screenshot, or metric is a failure.
3. A known compatibility issue remains a failure until fixed or explicitly reported as a blocker.
4. A retry may confirm a transient failure. Never discard the first failure without recording its cause.
5. Automated success does not replace original resolution screenshot review.
6. Partial audits cannot support a release ready claim.
7. Release readiness requires the strict report field `releaseReady` to equal `true`.
8. `LiveGates` may isolate a failing audit during diagnosis. A partial gate can never set `releaseReady` to `true`.

## Static gates

Require all of these:

1. Parse every project PowerShell script.
2. Check `scripts/injector.mjs` and `assets/renderer-inject.js` with Node.js.
3. Build and validate the injection payload.
4. Parse `assets/theme.json` and every tested preset `theme.json`.
5. Confirm `VERSION` matches the payload version.
6. Confirm required project files and restore scripts exist.
7. Confirm text files added for validation use UTF 8 without BOM when encoding affects parsers.

## Live automated gates

Run all project audits against a verified loopback CDP endpoint:

1. General verification with a screenshot.
2. Hover audit.
3. Composer and popover audit.
4. Welcome scene audit.
5. Page and historical task audit.
6. Expert, project, automation, and authorization detail audit.
7. Settings section audit.

Require loopback binding, listener ownership, WorkBuddy page identity, injected version, live image variables, a pointer transparent decoration root, no horizontal overflow, required contrast, and exactly one intended injector.

## Historical task sampling

1. Open at least four visible and distinct historical tasks.
2. Include different content shapes when available, such as a short answer, long answer, Markdown, file attachment, and artifact output.
3. Wait for each task to settle after opening.
4. Scroll to the true top, wait, set the top again, and capture.
5. Scroll to the true bottom, wait, set the bottom again, and capture.
6. Require visible text, a visible composer, hidden welcome decoration, and a real scroll container.
7. Repeat contrast, pseudo element, and overflow checks at both positions.
8. Record Markdown, code block, table, artifact, scroll top, scroll maximum, and viewport height metrics.
9. Require four top screenshots and four bottom screenshots.
10. Require every matched top and bottom screenshot pair to have different file hashes. Identical hashes indicate a failed scroll audit.
11. Inspect the final response and artifact shelf above the composer. No content may remain permanently hidden behind the composer.

## Manual visual matrix

Review all applicable cells at original resolution:

| Area | Required states |
| --- | --- |
| Themes | At least one light theme and one dark theme |
| Window | Maximized and narrow |
| Welcome | Default, each scene tab, recommendation hover |
| Sidebar | Default, selected, hover, expanded history, collapsed history |
| Composer | Empty, populated, model menu, permission menu, keyboard focus |
| Conversation | First message, middle, final message, long Markdown, code, table, blockquote |
| Artifacts | One item, multiple items, file metadata, hover, focus, view all |
| Overlays | Search, user menu, dialogs, tooltips, settings |
| Motion | Normal motion and reduced motion |
| Decoration | Welcome placement, narrow placement, chat hidden state, pointer pass through |

For every cell inspect readability, hierarchy, clipping, overlap, hover, focus, hit targets, empty strips, image focal point, animation restraint, and horizontal overflow.

## Manual review manifest

Create a JSON file only after completing the visual matrix. The strict script requires this shape:

```json
{
  "schemaVersion": 1,
  "reviewedAt": "2026-07-18T18:00:00+08:00",
  "reviewer": "Codex",
  "themes": [
    { "id": "sunlit-campus", "appearance": "light", "passed": true },
    { "id": "deep-sea-watch", "appearance": "dark", "passed": true }
  ],
  "checks": {
    "welcome": true,
    "sidebar": true,
    "composer": true,
    "historyTopBottom": true,
    "longConversation": true,
    "markdownCodeTable": true,
    "artifactShelf": true,
    "overlaysAndSettings": true,
    "narrowWindow": true,
    "maximizedWindow": true,
    "keyboardFocus": true,
    "reducedMotion": true,
    "decorationNonBlocking": true,
    "noOcclusionOrOverflow": true
  },
  "evidenceDirectory": "artifacts/strict-audit-release"
}
```

Require at least one passed light theme and one passed dark theme. Require every listed check to equal `true`. Require the evidence directory to exist.

## Evidence and cleanup

1. Store raw command logs, screenshots, and the final report under a versioned artifact directory.
2. Keep the original failed evidence when a later retry passes.
3. Record the active theme, WorkBuddy version, window size, and tested theme IDs.
4. Restore the user selected theme after cross theme testing.
5. Stop temporary servers and debug helpers started for the audit.
6. Keep the persistent injector only when the user wants the skin active.
