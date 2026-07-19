# Manual review guide

`run-strict-audit.ps1 -ManualReviewManifest artifacts\strict-audit-release\manual-review-manifest.json` 会读同目录的 `manual-review-manifest.json`。要拿到 `releaseReady: true`，需要 **两套主题（一 light + 一 dark）都过复核**、**14 项 checks 全部 true**，并且 `evidenceDirectory` 存在（本目录已建好）。

## 准备

1. 用托盘：**切换主题 → sunlit-campus**（light 基线），启用皮肤，把 WorkBuddy 拉到最大化。
2. 每一项检查按下面的"看什么 / 存哪"两列做完，light 全过之后再托盘切 **deep-sea-watch** 重来一遍。
3. 存图统一命名 `<check>-<light|dark>.png`，放在对应 `artifacts/strict-audit-release/light/` 或 `dark/`。
4. 复核完把 manifest 里对应字段翻成 `true`；两套主题都过时把 `themes[i].passed` 翻 `true`，填 `reviewer` 和 `reviewedAt`。

## 14 项 checks

| id | 看什么（在哪里） | 存哪 |
|---|---|---|
| `welcome` | 首屏欢迎页：文案对齐、主视觉不被挂件挡；scene tabs 三个 pill 视觉一致；recommendation hover 有 accent 反馈 | `<light\|dark>/welcome.png` |
| `sidebar` | 左侧会话列表：默认 / 选中 / hover 三态视觉；顶部搜索按钮 hit 区正常；`NIGHT WATCH / 01` 标签存在（深色）或对应 light 变体 | `<light\|dark>/sidebar.png` |
| `composer` | 输入区：空态占位、光标可见、model / permission 触发器 hover 反馈明显、`--wbds-on-accent` 让 primary 按钮文字读得清 | `<light\|dark>/composer.png` |
| `historyTopBottom` | 打开 4 条历史任务，滚到顶再滚到底：文字压不到装饰、代码块背景层次清晰、气泡上下对比度足 | `<light\|dark>/history-top.png` + `<light\|dark>/history-bottom.png` |
| `longConversation` | 找一条 20+ 消息的长会话：滚到中段，检查气泡分组、日期分隔线、markdown 换行不糊 | `<light\|dark>/long-conversation.png` |
| `markdownCodeTable` | 找一条含 markdown 代码块 + 表格的响应：代码块 `.cb-markdown-pre` 背景与正文有层次；表格边框可读；行内 `code` 有底色 | `<light\|dark>/markdown-code-table.png` |
| `artifactShelf` | 有产物的任务：`.artifact-slot-panel__card` 边框金色微光可见，hover 上抬动效对；不遮住 composer | `<light\|dark>/artifact-shelf.png` |
| `overlaysAndSettings` | 顶部搜索模态、user-menu 弹层、settings 12 section（重点看 `agent-mailbox` 面板的 title/desc/agreement 文字对比度） | `<light\|dark>/settings.png` + `<light\|dark>/overlays.png` |
| `narrowWindow` | 把 WorkBuddy 拉到 800px 左右宽：无横向滚动、装饰自动让位、composer 不断行 | `<light\|dark>/narrow.png` |
| `maximizedWindow` | 最大化：主视觉不糊、背景网格不喧宾夺主、右上装饰在合理位置 | `<light\|dark>/maximized.png` |
| `keyboardFocus` | Tab 进入 sidebar 项、conversation 项、composer、settings：`:focus-visible` outline 用 `--wbds-accent` 可见，2px offset | `<light\|dark>/focus.png` |
| `reducedMotion` | 系统开启"减少动画"（Windows: 设置 → 辅助功能 → 视觉效果 → 动画效果关掉）后：装饰不再摇摆、光点不闪 | `<light\|dark>/reduced-motion.png` |
| `decorationNonBlocking` | Console 里对 `.wbds-character, .wbds-charm-orbit, #workbuddy-dream-skin-chrome` 各元素查 `getComputedStyle(el).pointerEvents === 'none'`；顶部 hero 不吞点击 | `<light\|dark>/decoration-passthrough.png`（可截控制台） |
| `noOcclusionOrOverflow` | 每个页面（新建任务 / assistant / projects / experts / skills / connectors / automation）滑到底：无横向溢出、composer 不被浮层永久挡、`document.documentElement.scrollWidth > clientWidth` 为 false | `<light\|dark>/no-overflow.png` |

## 光/暗主题切换

托盘 → 切换主题 → 选新预设 → 会弹重启确认（`0.6.5` 起）→ 确认 → 皮肤自动重新启用。等 workbuddy 起来后跑一次静态验证：

```
node scripts/injector.mjs --verify --port <当前端口>
```

## 跑最终门禁

两套主题都存完图、manifest 里 `themes[*].passed` 都翻 `true`、14 项 checks 全 `true`、`reviewer` / `reviewedAt` 填了之后：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  skills\workbuddy-skin-maker\scripts\run-strict-audit.ps1 `
  -ManualReviewManifest artifacts\strict-audit-release\manual-review-manifest.json
```

期望：`automatedPass: true`、`releaseReady: true`、`nextActions` 里出现 "releaseReady=true. Cut a release only after..."。
