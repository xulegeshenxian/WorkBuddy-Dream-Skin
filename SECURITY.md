# Security policy

## Supported versions

Only the latest tagged release receives security fixes. See [`CHANGELOG.md`](./CHANGELOG.md) for the current version and [`VERSION`](./VERSION).

## Threat model

This project attaches to a locally running WorkBuddy renderer via Chrome DevTools Protocol and injects CSS + a small runtime into it. The important surfaces:

- **Loopback CDP endpoint.** WorkBuddy is launched with `--remote-debugging-port` bound to `127.0.0.1` / `::1` only. If your machine already exposes loopback to a remote peer (e.g., an SSH tunnel or reverse-proxied dev tool), that peer would see the port too. Anything with access to the port has full renderer control — this is a Chromium property, not a project decision.
- **Injected payload.** The skin evaluates one JavaScript string and one CSS string in the WorkBuddy renderer context. Both are read from local files under the repo (or `%LOCALAPPDATA%\WorkBuddyDreamSkin`). We treat those files as trusted — an attacker who can write there could already run arbitrary code as the user.
- **Theme images.** Loaded from local paths, wrapped as `blob:` URLs, and used as CSS `background-image`. Not evaluated as script. Maximum accepted size is 16 MB per file; SVG is accepted for shapes only (`customize-workbuddy-theme.ps1:47`).
- **PowerShell entry points.** Scripts are not code-signed. Users run them with `-ExecutionPolicy Bypass` scoped to the current PowerShell process. That scope does not persist and does not affect the system policy.
- **State files.** `%LOCALAPPDATA%\WorkBuddyDreamSkin\state.json` records `port`, `injectorPid`, `workBuddyPid`, `workBuddyPath`. `restore-workbuddy-skin.ps1` only terminates injector PIDs whose recorded command line matches, to avoid killing an unrelated Node process.

## Not in scope

- The WorkBuddy client itself, its shipped `app.asar`, or any Tencent-owned service. Report bugs in WorkBuddy to Tencent through their official channels.
- Windows title bar / menu bar rendering — outside the Electron renderer DOM, cannot be affected by this project.
- Non-Windows platforms — not supported yet, so no security assertions apply.

## Reporting a vulnerability

**Please do not open a public issue for suspected security problems.**

- **Preferred:** open a private [Security Advisory](https://docs.github.com/en/code-security/security-advisories/repository-security-advisories/creating-a-repository-security-advisory) via GitHub's *Security → Advisories → New draft security advisory* on this repository.
- If that is unavailable, contact the maintainers by opening a normal issue titled `security: contact request` and asking for a private channel. Do not include vulnerability details in the public issue.

When reporting, please include:

- Affected version (`VERSION` or the commit hash you tested).
- Reproduction steps or a proof-of-concept.
- Impact (renderer takeover, local file exfil, privilege escalation, denial-of-service, …).
- Your suggested disclosure timeline if you have one.

## Response expectations

- Acknowledgement: **within 5 working days** of receiving the report.
- Fix targeting: severity-dependent, but we aim to publish a patched tag within **30 days** for high-severity issues.
- Credit: reporters who wish to be credited are named in the release notes and in `NOTICE.md` unless they ask otherwise.

## Coordinated disclosure

We follow standard responsible-disclosure timing (typically 90 days, or when a patch is publicly available, whichever is sooner). If the issue affects an upstream project — for example [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin) whose injection pattern we build on — we will notify that project's maintainers before public disclosure.
