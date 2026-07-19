# Contributing

Thanks for taking the time to help. This project is a community skin for a proprietary application; the moving pieces are small but the failure modes are cosmetic-and-visible, so we lean hard on the preflight gate and screenshot evidence.

**Before you open a PR**, please read the [Code of Conduct](./CODE_OF_CONDUCT.md).

**中文说明** —— 本文件目前只提供英文版；欢迎 PR 一份 `CONTRIBUTING.zh.md`。

## Repo layout in one screen

```
WorkBuddy-Dream-Skin/
├── assets/
│   ├── css/                    # Layered CSS payload (9 files + manifest.json)
│   ├── renderer-inject.js      # The runtime that goes into WorkBuddy's page
│   ├── style-palettes.json     # 5 built-in style tokens
│   ├── theme.json              # Default (dev) theme
│   └── themes/                 # Sample theme images
├── scripts/
│   ├── injector.mjs            # CDP client + audit driver (Node.js)
│   ├── preflight.mjs           # Static gate — runs in CI
│   ├── start-workbuddy-skin.ps1
│   ├── restore-workbuddy-skin.ps1
│   ├── customize-workbuddy-theme.ps1
│   ├── workbuddy-skin-tray.ps1
│   ├── audit-workbuddy-*.ps1   # 6 live audit gates (wrappers)
│   └── …
├── docs/                       # Architecture, dev, theme schema
├── skills/workbuddy-skin-maker # Codex skill for skin authoring
├── artifacts/                  # Local audit + preflight output (gitignored)
├── ROADMAP.md                  # Open work, grouped by track
└── README.md / README.en.md
```

## Development loop

**Prerequisites:** Windows 10/11, Node.js ≥ 22, PowerShell 5.1 or 7, WorkBuddy desktop installed.

**No `npm install` step** — the Node.js side uses only built-in APIs.

Boot WorkBuddy with the debug port bound and inject the skin:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd <path-to-repo>\WorkBuddy-Dream-Skin
.\scripts\start-workbuddy-skin.ps1 -RestartExisting
```

Hot-reload CSS after editing anything under `assets/css/`:

```powershell
$state = Get-Content $env:LOCALAPPDATA\WorkBuddyDreamSkin\state.json | ConvertFrom-Json
node scripts/injector.mjs --once --port $state.port --theme-dir "$env:LOCALAPPDATA\WorkBuddyDreamSkin\theme"
```

Verify — captures a screenshot + a structured JSON report:

```powershell
.\scripts\verify-workbuddy-skin.ps1 -ScreenshotPath .\artifacts\manual-verify.png
```

## Required gates before opening a PR

1. **`npm run preflight`** — must be 8/8 pass. Runs `node --check` on the three `.mjs` files + renderer-inject, parses every JSON, parses every PowerShell script, and assembles the CSS payload. This is what CI (`.github/workflows/preflight.yml`) enforces.
2. **`npm run verify`** — visual sanity check against a running WorkBuddy. Attach the screenshot in the PR description if your change is visual.
3. For visual changes: also spot-check on **both** light (`sunlit-campus` or `pink-dream`) and **dark** (`deep-sea-layered`, `gilded-night-banquet`) themes. Attach one shot per appearance.

## Adding a theme

There are three levels of "adding a theme":

### 1. New preset from an existing style family

Fastest path — reuse one of the 5 built-in palettes (`PinkDream` / `MintBloom` / `SunlitCampus` / `GildedNight` / `DeepSea`), just point it at your images:

```powershell
.\scripts\customize-workbuddy-theme.ps1 `
  -ImagePath "C:\Users\<You>\Pictures\my.jpg" `
  -Style SunlitCampus `
  -SavePreset "sunny-porch"
```

Preset lands at `%LOCALAPPDATA%\WorkBuddyDreamSkin\themes\sunny-porch\`. No repo change needed. If you want the preset to ship with the repo, PR it to `assets/themes/sunny-porch/` (theme.json + images).

### 2. New palette (new style family)

Edit `assets/style-palettes.json`, add a new entry alongside the 5 existing ones. Every field is required — copy an existing entry as scaffold. Then:

- Style-specific CSS overrides go under `assets/css/60-chrome.css` at the bottom of the file, using `html.workbuddy-dream-skin[data-workbuddy-dream-skin-style="your-style"] …` selectors. Later rules on equal specificity win over the base `.wbds-character-card` styles.
- Update the whitelist in `scripts/customize-workbuddy-theme.ps1` and the `Style` parameter's `ValidateSet`.
- Add the palette to the README table.

### 3. New decoration shape

The decoration system supports `polaroid` (default) plus five in-tree shapes: `stamp` / `sticker` / `pressed-leaf` / `heart` / `porthole`. Adding a sixth:

1. Extend the whitelist in `scripts/injector.mjs` (`safeChoice(...)` for `decoration.shape`).
2. Add an SVG face template in `assets/renderer-inject.js` (see the existing `insertAdjacentHTML` calls for the pattern).
3. Add a CSS block at the **bottom** of `assets/css/60-chrome.css` — anything using the `[data-workbuddy-dream-skin-decoration-shape="your-shape"]` selector. Shape blocks live at the end of the file so they win over per-style card overrides.

Check `ROADMAP.md` section **H** for background on the shape system's design axes.

## PR checklist

- [ ] Preflight passes locally: `npm run preflight` shows `PASS: 8/8`.
- [ ] Visual changes include one light + one dark screenshot.
- [ ] Any new user-facing behavior is reflected in **README.md** *and* **README.en.md**.
- [ ] `CHANGELOG.md` has a bullet under the next version.
- [ ] If you added a file that has an obvious public/private split (like `AI-HANDOFF.md`), put it in the right place per `ROADMAP.md` section J.
- [ ] Commit messages describe the **why**; hooks aren't skipped (`--no-verify` is not allowed except with an explicit maintainer OK).

## Commit style

- Present-tense, imperative subject line: "Add …", "Fix …", "Route … through …".
- One logical change per commit where practical.
- Squash cosmetic follow-ups into the parent commit before the PR is merged.
- Co-authors welcome — use `Co-Authored-By:` trailers.

## Getting stuck

- **Preflight fails on PowerShell parse** → run `powershell -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile(...)"` on the offending file for details.
- **Injector fails to connect** → confirm `state.json` port, then `Invoke-RestMethod http://127.0.0.1:<port>/json/list`.
- **Live audit hangs at `Page.captureScreenshot`** → the renderer's compositor stalled. Minimize / restore WorkBuddy or restart it from the tray.
- Other WorkBuddy / injector edge cases live in `ROADMAP.md` — many of the "already fixed" entries have the root cause written out.

## Reporting security issues

**Please don't** open a public issue for suspected security problems. See [`SECURITY.md`](./SECURITY.md).
