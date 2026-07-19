# WorkBuddy Dream Skin ROADMAP

工程质量优化清单。每完成一项，在同一 commit 里把状态从 `[ ]` 改成 `[x]` 并附 commit 哈希。新发现的优化点作为 `[ ]` 追加，不静默做。

启动来源：2026-07-18 的项目质量评估（对话记录已归档在会话 handoff）。原推荐是 4 周计划，实际按需推进。

---

## 已完成

- [x] **基线仓库**（`f2b9e3c`, 2026-07-18）
  - `git init` main 分支、`.gitignore` 排除 `artifacts/` `tmp/`、`.gitattributes` 规范行尾
  - `package.json` 锁 Node ≥22，暴露 `preflight` / `check-payload` / `check-node` / `verify`
  - `scripts/preflight.mjs` 一键跑 AGENTS.md 里那 6 项手工检查，报告落 `artifacts/preflight.json`

- [x] **CSS 分层 + 审计注册表**（`0498d1d`, 2026-07-18）
  - `assets/workbuddy-skin.css`（2303 行）拆成 `assets/css/00-base…80-composer-fade` 9 个文件 + `manifest.json`
  - `loadPayload` 按 manifest 顺序拼接；载荷字节完全一致（113621 bytes）
  - `AUDIT_MODES` 表统一了 `parseArgs` 的 6 个 `--audit-*` 分支、`runOneShot` 的 7 路三元、底部 6 个 `exitCode`

---

## 待办（按 ROI 从高到低）

### D. 发布门禁攻坚 ★ 最痛

- [x] 修 `auditSettingsSession` 定位逻辑（settings audit 首次从 5.2.6 上通过）。根因：`.user-menu-trigger` 底部 813 > innerHeight 800，`findControlPoint` 的严格可见性判定把它当不可见 → 触发器从未被点击 → 弹层从未打开 → 所有 section 失败。修复：
  - `findControlPoint` 分裂为 `findControlPointDetail`（返回诊断信息）+ 薄封装（保持旧签名）；点击失败时报 `reason / rawMatches / textMatches / innerHeight / nearMiss`
  - 新增 `spec.allowClipped` 选项，允许"中心在视口内"的判定，专给 docked 底栏控件用
  - 设置入口选择器改成 `.user-menu-popover .user-menu-item-label, [class*="user-menu"] .user-menu-item-label, [class*="user-menu"] *`
  - 补上漏掉的 `agent-mailbox`（智能体邮箱）section
  - CSS：`_sceneTag_` 芯片和 `.agent-mail-activation` 面板路由到 WBDS 主题令牌，light/dark 都可读
- [x] `run-strict-audit.ps1` 报告结构化（schemaVersion 2，见 commit 下方）：加了 `coverage`、`failedItems`、`nextActions`；`pass policy` 未变。契约文档同步更新到 `strict-audit-contract.md` 第 8 节
- [ ] 全量实时门禁拆成"必过 5 项 + 尽力 2 项"，避免一个环境不稳定项拉低整体。**注意 contract 第 6/7/8 条 pass policy 不允许"partial audit → releaseReady=true"**。真要做，需要先在契约里定义"best-effort gate 有 waiver 时不阻塞 releaseReady"的新规则并让用户 review
- [x] Settings audit `agent-mailbox` section 在 5.2.6 深色主题下失败（`agent-mail-activation__title/desc/agreement-prefix/agreement-link` 继承 WorkBuddy 未 themed 的 `rgba(0,0,0,0.9)`、`rgba(0,0,0,0.5)`、`rgb(65,106,161)`，叠在 WBDS 深海面板上 contrast 1.25 / 3.05）。修复：`40-pages.css` 里为 `.agent-mail-activation__title` 路由 `--wbds-text`；`__desc / __agreement-prefix` 路由 `--wbds-muted`；`__agreement-link` 路由 `--wbds-accent-alt`。live audit-settings 现在 12/12 pass，audit-hover / audit-composer / audit-scenes 也全 pass（`1b4dacf`, 2026-07-19）
- [x] Fix live-gate 结构性阻塞（`814782b`, 2026-07-19）：
  - `auditPagesSession` 里 `.user-menu-trigger` 点击少了 `allowClipped: true`；同一 5.2.6 底栏裁剪问题（bottom 813 > innerHeight 800）让 pages-audit 里的 settings 入口 popover 从未打开（rawMatches=12 / textMatches=0）。加上 `allowClipped: true` 并把 settings 选择器升级到跟 `auditSettingsSession` 一致的三段式（`.user-menu-popover .user-menu-item-label, [class*="user-menu"] .user-menu-item-label, [class*="user-menu"] *`）
  - `hasLightRgb` 只查 R 通道前缀，把 `#F2B866` 金橙 accent 当近白面板 → `.artifact-slot-panel__card::before` (history-task) 与 `.ec-featured-scenes-section::before` (experts) 都被误伤。改成正则匹配 rgba 全部三通道 ≥240 才判定
  - `.ec-featured-scenes-section` 伪元素 WorkBuddy 原生渲染 `rgba(250,250,250,0.92)` 的白边渐变，深色主题上确实是真近白面。`40-pages.css` 里把两个伪元素 background 覆盖成 `linear-gradient(90deg, transparent, color-mix(background 92%, transparent))`
  - `auditComposerSession` / `auditScenesSession` 依赖调用方停在 new-task 页，跑在 audit-details/audit-pages 之后就找不到 `.composer-*-trigger` / `.wb-scene-tabs__pill`。两处开头都加 `restore-new-task` 点击
  - Scene chip 切换后 `.quick-actions__item` 的过渡长过原来的 350ms sleep；提升到 700ms 并把 action 查找改成最多 8 次 400ms 轮询
- [ ] 拿到 **项目历史上第一次 `releaseReady: true`**：走 `artifacts/strict-audit-release/REVIEW-GUIDE.md`（`3096ace` 引入），双主题各截 14 项证据，把 `manual-review-manifest.json` 里 checks + themes[*].passed 翻 true，重跑 `run-strict-audit.ps1 -ManualReviewManifest`
- [x] **项目历史上第一次 `automatedPass: true`** —— `run-strict-audit.ps1` 无 `-StaticOnly` 无 `-ManualReviewManifest` 跑完，`coverage: passed=14/14, liveGates=7/7`。7 个 live gate（verify / hover / composer / scenes / settings / pages / details）+ 6 项静态门禁 + history screenshot evidence 全部 pass，`automatedPass: true`。补丁包含 `a44619c` 里的 history-task 首帧 settle 轮询（初次进入历史任务时 1400ms 太短，`initial.visibleTextCount === 0` 时最多再等 6×700ms = 4.2s）。`releaseReady: true` 现只差 `-ManualReviewManifest`（明暗主题各一份视觉复核 + 证据目录）

### A. 剩余的结构分层

- [ ] `scripts/injector.mjs`（1475 行）拆子模块：`cdp/session.mjs`（CdpSession + listCandidateTargets + connectWorkBuddyTargets + probeSession）+ `payload.mjs`（loadTheme + loadPayload + safe*）+ `audits/*.mjs`（每个审计一个文件）+ `cli.mjs`（parseArgs + dispatch）
- [ ] `scripts/customize-workbuddy-theme.ps1`（367 行）把 `Get-ThemeStyleFromImage` 抽到 `common-workbuddy.ps1` 或独立 `analyze-image.ps1`，方便 tray / skill-maker 复用

### B. 载荷 & CSS 更新链路

- [ ] `renderer-inject.js` 把 4 个 `__WORKBUDDY_SKIN_..._JSON__` 占位符替换改为 `globalThis.__WBDS_CTX__` 注入。占位符碰到 CSS 里同名字面量会炸；`globalThis` 无此风险
- [ ] 探测 WorkBuddy 是否用 `@layer`（跑一次真实运行时探针）。如果没有，把所有 WBDS 规则包进 `@layer wbds`，可以显著减少 `!important` 用量

### C. 图片风格分析升级

- [ ] `Get-ThemeStyleFromImage`（`customize-workbuddy-theme.ps1:81-126`）改成"取 k=4 主色（简单 median-cut）+ 投票 + 平均亮度 + 平均饱和度"。当前用 64×64 `GetPixel` + 4 个硬编码色相区间，边界图易反转、新增第 6 套色板要改硬阈值

### F. 遗留素材决议

- [ ] `scripts/new-workbuddy-decoration.ps1`（0.4.0 SVG 挂件生成器，默认流程不再调用）：留下并明确标注"高级用户可选"，还是删掉？handoff 7.6 已点名
- [ ] `assets/themes/pink-mint-botanical-decoration.png`、`tmp/imagegen/pink-mint-botanical-key.png`：无运行时引用，删掉之前需要用户批准
- [ ] `assets/theme.json` 内置默认主题 `decoration.mode` 是否从 `off` 改成 `auto`，让首装体验就有欢迎页挂件

### G. 小 bug / 稳定性

- [x] `scripts/injector.mjs` 非审计模式（`once` / `remove` / `probe`）失败时静默退 0。修复：新增 `NON_AUDIT_EXIT_CODES = { verify:2, once:6, remove:10 }` 与 `isRunResultFailed(mode, result)`，`remove` 结果按 bool、`probe` 视作永远成功、`once`/`verify` 按 `.pass` 判定；`runOneShot` 尾部用二者取 exit code。CI 门禁现在能看到静态注入 / 卸载失败（`a79b5d5`, 2026-07-19）
- [x] 4 处硬编码 `#041713 / #031512 / #061714`（深海调深绿黑）在 `pink-dream / mint-botanical / sunlit-campus` 主题上把按钮文字染成绿黑。修复：`00-base.css` 里新增 `--wbds-on-accent` token（暗色默认 `color-mix(black 88%, accent)`；light 变体强制 `#fff`），把 10 个 `.atm-detail-btn / .tencent-docs-auth-guide__btn / .wb-scene-tabs / .growth-plan-entry / .ec-* / .create-project-dialog__action-btn / .connector-card button / .account-panel__avatar-placeholder / .daily-checkin-btn-primary / button[class*="primary"] / ::selection / --vscode-button-foreground` 全部改成 `var(--wbds-on-accent)`（`a79b5d5`, 2026-07-19）
- [x] `scripts/injector.mjs` 截图用 `captureBeyondViewport: false` + `fromSurface: true`，HiDPI 下物理/CSS 像素易错乱。修复：`capture()` 先 `Page.getLayoutMetrics` 拿 `cssVisualViewport` 的 CSS 尺寸，用 `clip: { x:0, y:0, width, height, scale:1 }` 归一化到 CSS 像素，无论 devicePixelRatio 输出恒定。metrics 拿不到时回退旧行为，不会中断截图（`93963c1`, 2026-07-19）
- [x] 托盘"切换主题"子菜单打开时抛 `.NET Framework` 未处理异常（`presetId` 属性找不到）。根因：`common-workbuddy.ps1:1` 全局 `Set-StrictMode -Version 2.0`，`workbuddy-skin-tray.ps1:170-172` 直接读 `$activeTheme.presetId`；手动定制主题（`customize-workbuddy-theme.ps1:199`）会主动删掉 `presetId`，strict-mode 下访问缺失属性抛出，异常冒到 WinForms 消息循环→弹窗。修复：改用 `$activeTheme.PSObject.Properties['presetId']` 探测后再读，`name` 同理。同文件里 `decoration.mode`（第 227 行）与 preset 自己的 `name`（第 164 行）都在 try/catch 里，不会溢出（`2a2afda`, 2026-07-19）
- [x] **所有皮肤都有：进入历史任务时聊天区顶部漂着一大块半透明色块**。根因：`30-composer.css:302-313` 里给 `[class*="skeleton" i], [class*="shimmer" i]` 用了 `background:` 简写 —— 简写会把 `background-color` 归零，只留 8% opacity 的 accent 闪光渐变。骨架容器（`.chat-container__message-skeleton-content` / `_skeletonContainer_` / `_skeletonPair_`）就此没有不透明底色，深色 / 粉色 hero cover 直接从 z 轴后面透出。修：拆成 `background-color: color-mix(panel 90%, transparent)` 底 + `background-image: linear-gradient(...)` 闪光，动画尺寸不变（`aec8410`, 2026-07-19）
- [ ] `renderer-inject.js` 三保险策略（`MutationObserver` `childList+subtree` + 5s `setInterval` + 180ms debounce），SPA 频繁 mount/unmount 时 CPU 占用高。改成"只观察 `#root` 直接子节点 + 页面 `visible` 才 tick"
- [ ] SVG 导入：`.svg` 在 `customize-workbuddy-theme.ps1:47` 允许列表里，但 16 MB 尺寸检查对 SVG 没意义，应改成节点数 / 内嵌 `<script>` 白名单
- [ ] `renderer-inject.js:76-77` chrome positioner 选择器和 `probeSession` / `verifySession` 不一致（前者用 `.colleagues-chat-float__main`，后者用 `.colleagues-chat-float`）。float 聊天页两边看的不是同一个节点。抽成共享常量
- [ ] `renderer-inject.js` 无 `ResizeObserver`：`--wbds-shell-{left,top,width,height}` 只在 MutationObserver / 5s interval tick 时重算，Electron 窗口 resize 后装饰漂移最多 5s。加一个 `ResizeObserver` 挂在 `#root` 或 `window.resize`
- [ ] `renderer-inject.js:122-143` `ensure()` 里死防御——`innerHTML` 刚构完立刻重查 `.wbds-character / .wbds-charm-orbit / .wbds-character-card / .wbds-sparkles`。改成"初次 mount 建结构，后续只更新 img.src / textContent"
- [ ] `injector.mjs:1500-1502` `Page.loadEventFired` 重注入没 debounce，SPA 路由切换 / dev reload 时会排队多份 payload（每份 ~120KB）。存 `lastReinjectTimeout` 到 session，重排前 `clearTimeout`
- [ ] `injector.mjs:1461` audit 模式 stdout 无上限，`lightSurfaces / lowContrast / pseudoLight` 数组会让一次审计输出 >1MB，托盘日志会被截断。加 `maxResults` slice + `truncated: true` 标记
- [ ] `workbuddy-skin-tray.ps1:265-268` 托盘每 2.5s `Invoke-RestMethod http://127.0.0.1:$Port/json/list`，菜单没打开也在轮询。移到 `$menu.Add_Opening`，间隔改成 10s
- [ ] `workbuddy-skin-tray.ps1:255-256, 279-290` `[Drawing.Icon]::ExtractAssociatedIcon(...)` 拿到的 Icon 从未 `Dispose()`，托盘反复重启会漏 GDI handle。存引用 + `finally` 里 dispose
- [ ] `preflight.mjs:88` Windows 只找 `powershell.exe`，PS 7-only 环境（Server Core / Nano）挂。先试 `pwsh` 再回退 `powershell.exe`
- [ ] `install-workbuddy-skin.ps1:33-37` 复装静默 `Remove-Item -Recurse -Force` 掉目标 `assets/`，会带走用户扔在 `assets/themes/` 里的图片。先 diff 或归档到 `$destinationRoot/.backup`
- [ ] 没有任何单元测试（`tests/` 不存在）。`safeColor / safeCssPosition / safeCssSize / safeAssetName / colorWithAlpha / positionValue / decorationWidth / schemaVersion 迁移` 一个都没覆盖。加 `scripts/tests/*.mjs` 用 `node --test`，接进 `npm run verify`
- [ ] `start-workbuddy-skin.ps1:60` `$injectorArgs = @("\"$InjectorPath\"", ...)` 在数组里嵌 `"..."` 字面量，路径带引号 / 空格会崩。改用 `[System.Diagnostics.ProcessStartInfo]::ArgumentList`
- [ ] `common-workbuddy.ps1:91` 主进程识别靠 `app.asar\main|cli` 正则，WorkBuddy 未来 unpacked / ASAR-integrity 打包就废。改用"无 `--type=` + parent PID = 0"
- [ ] `package.json` 缺 `lint` / `test` / `repository` / `license` / `packageManager`；`check-node` 对 `renderer-inject.js` 用 `node --check` 但它是 IIFE，未来加 top-level `import` 会静默过

### E. CI / 打包

- [ ] GitHub Actions 或本地 pre-commit：跑 `npm run preflight`。目前 preflight 已经就绪，30 行 YAML 即可
- [ ] 决定要不要建远程仓库（当前只有本地 `main` 分支）

### 设计侧（可选，需要视觉复核）

- [ ] 五套 palette 都开 `panelOpacity ≥ 0.88`，`deep-sea` 达 0.96，深色主题上 96% 面板不透明 + cover 背景 + `heroOverlay: 0.72` 三层叠加后主视觉几乎看不见。可能是"背景没意义"。设计侧复核

---

## 完成流程

1. 从待办里选一项，在此文件把 `[ ]` 前加 `→` 标记 in-progress
2. 做完后同一 commit 里改成 `[x]` 并追加 commit 哈希与日期
3. 中途发现新问题：以 `[ ]` 追加到最相关的分类下，不静默做
