# Credits

## Image assets

All theme visuals and screenshots shipped with this repository are **AI-generated**. They are original works produced by the project maintainers; no third-party stock photos, scraped web images, or copyrighted material is included.

| Path | What it is | Source |
| --- | --- | --- |
| `assets/themes/sunlit-campus.png` | Hero image for the `sunlit-campus` theme (校园女生跳跃场景) | AI-generated |
| `assets/themes/sunlit-campus-card.svg` | Polaroid card SVG for the `sunlit-campus` theme | Hand-authored SVG (this project) |
| `assets/themes/gilded-night-banquet.png` | Hero image for the `gilded-night-banquet` theme (宫廷夜宴女像) | AI-generated |
| `assets/themes/pink-mint-botanical-decoration.png` | Decoration image referenced by the `pink-dream` / `mint-bloom` palettes | AI-generated |
| `Pictures/1.png` `2.png` `3.png` | README example screenshots | AI-generated composites / rendered captures |

Use of these images is covered by the same [MIT license](./LICENSE) as the rest of the repository. If you fork the project and want to ship your own theme images, please replace these files — the file paths are stable, so downstream themes keep working.

## Decoration SVG shapes

The five in-tree decoration shapes (`stamp` / `sticker` / `pressed-leaf` / `heart` / `porthole`) are hand-authored SVG + CSS, defined in `assets/renderer-inject.js` and `assets/css/60-chrome.css`. No external SVG libraries are used.

## Runtime dependencies

Node.js side: **no npm dependencies**. Uses only built-in APIs (`WebSocket`, `fs`, `path`, `crypto`, `child_process`, `zlib`).

PowerShell side: **no external modules**. Uses only Windows PowerShell 5.1 built-ins and .NET Framework `System.Windows.Forms` / `System.Drawing` for the tray.

## Third-party attribution

The runtime injection pattern (external CDP, package-untouched, resumable via a state file) is adapted from [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin) (MIT). See [NOTICE.md](./NOTICE.md) for the full attribution and license text.

## Trademarks

- **WorkBuddy** and 腾讯 are trademarks of Tencent. This project is an unofficial community skin, not affiliated with, sponsored by, or endorsed by Tencent.
- **Codex** and related marks referenced via the upstream project belong to their respective rights holders.

## Contributors

Everyone who lands a commit on `main` is credited here at release-tag time. Add your name via PR to this file when you contribute — or leave the maintainers to add it in the release notes.

<!-- CONTRIBUTORS-START -->
_(Names will be listed here as the project accumulates public contributions.)_
<!-- CONTRIBUTORS-END -->
