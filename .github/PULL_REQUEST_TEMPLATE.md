<!--
Thanks for the PR! A quick checklist keeps preflight green and reviews fast.
中文 PR 描述完全欢迎。
-->

## Summary

<!-- One or two sentences: what the PR changes, at the user-visible level. -->

## Why

<!-- The user-facing reason. If it's fixing a bug, link the issue. If it's a design
     choice (e.g. new decoration shape), cite the relevant ROADMAP section. -->

## Scope of change

- [ ] Cosmetic / new preset
- [ ] Decoration-shape system (`assets/renderer-inject.js` + `assets/css/60-chrome.css` + `scripts/injector.mjs` whitelist)
- [ ] Injector / audit / preflight
- [ ] Tray / launch / restore
- [ ] Docs / README / examples
- [ ] Other (please describe)

## Verification

- [ ] `npm run preflight` → `PASS: 8/8`
- [ ] `npm run verify` against a running WorkBuddy (attach the screenshot below)
- [ ] Visual changes: light theme screenshot attached
- [ ] Visual changes: dark theme screenshot attached
- [ ] `CHANGELOG.md` updated under the next unreleased version
- [ ] README.md **and** README.en.md updated if the change is user-facing

## Screenshots (visual changes only)

<!-- Drag-drop images here. -->

## Breaking changes

<!-- List anything that changes the theme.json schema, script parameters, tray menu items,
     or the injected DOM shape. If none, write "None." -->

## Notes for the reviewer

<!-- Optional. Anything the reviewer should look at first, or explicitly not review. -->
