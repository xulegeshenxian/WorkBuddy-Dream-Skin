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
- [ ] **目标：拿到项目历史上第一次 `releaseReady: true`** —— 需要跑全量 LiveGates + 提供 manual review manifest。Settings audit 已不再是阻塞项

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

- [x] `scripts/injector.mjs` 非审计模式（`once` / `remove` / `probe`）失败时静默退 0。修复：新增 `NON_AUDIT_EXIT_CODES = { verify:2, once:6, remove:10 }` 与 `isRunResultFailed(mode, result)`，`remove` 结果按 bool、`probe` 视作永远成功、`once`/`verify` 按 `.pass` 判定；`runOneShot` 尾部用二者取 exit code。CI 门禁现在能看到静态注入 / 卸载失败（`_pending_`, 2026-07-19）
- [x] 4 处硬编码 `#041713 / #031512 / #061714`（深海调深绿黑）在 `pink-dream / mint-botanical / sunlit-campus` 主题上把按钮文字染成绿黑。修复：`00-base.css` 里新增 `--wbds-on-accent` token（暗色默认 `color-mix(black 88%, accent)`；light 变体强制 `#fff`），把 10 个 `.atm-detail-btn / .tencent-docs-auth-guide__btn / .wb-scene-tabs / .growth-plan-entry / .ec-* / .create-project-dialog__action-btn / .connector-card button / .account-panel__avatar-placeholder / .daily-checkin-btn-primary / button[class*="primary"] / ::selection / --vscode-button-foreground` 全部改成 `var(--wbds-on-accent)`（`_pending_`, 2026-07-19）
- [x] `scripts/injector.mjs` 截图用 `captureBeyondViewport: false` + `fromSurface: true`，HiDPI 下物理/CSS 像素易错乱。修复：`capture()` 先 `Page.getLayoutMetrics` 拿 `cssVisualViewport` 的 CSS 尺寸，用 `clip: { x:0, y:0, width, height, scale:1 }` 归一化到 CSS 像素，无论 devicePixelRatio 输出恒定。metrics 拿不到时回退旧行为，不会中断截图（`93963c1`, 2026-07-19）
- [ ] `renderer-inject.js` 三保险策略（`MutationObserver` `childList+subtree` + 5s `setInterval` + 180ms debounce），SPA 频繁 mount/unmount 时 CPU 占用高。改成"只观察 `#root` 直接子节点 + 页面 `visible` 才 tick"
- [ ] SVG 导入：`.svg` 在 `customize-workbuddy-theme.ps1:47` 允许列表里，但 16 MB 尺寸检查对 SVG 没意义，应改成节点数 / 内嵌 `<script>` 白名单

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
