# WorkBuddy Dream Skin

**English:** [README.en.md](./README.en.md) · **License:** [MIT](./LICENSE) · **Contributing:** [CONTRIBUTING.md](./CONTRIBUTING.md) · **Security:** [SECURITY.md](./SECURITY.md) · **Credits:** [CREDITS.md](./CREDITS.md)

> **免责声明**：本项目是 **社区非官方** 的 WorkBuddy 换肤方案。"WorkBuddy" 是 **腾讯** 的商标，本项目 **未** 获得腾讯授权、赞助或背书，与腾讯无任何隶属关系。同理，参考项目 [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin) 里提及的 "Codex" 及相关标识归其各自权利人所有。
>
> _WorkBuddy is a trademark of Tencent. This project is an unofficial community skin, not affiliated with, sponsored by, or endorsed by Tencent. See [NOTICE.md](./NOTICE.md) for full third-party attribution._

许可证：[MIT](./LICENSE)。上游归属和商标声明见 [NOTICE.md](./NOTICE.md)。

WorkBuddy Dream Skin 是面向腾讯 WorkBuddy Windows 桌面端的外置换肤项目。项目通过本机回环地址上的 Chrome DevTools Protocol 连接 Electron 渲染进程，在页面加载后注入可恢复的 CSS、主题变量和装饰层。

整个实现不会修改 `WorkBuddy.exe`、`app.asar`、签名文件或 WorkBuddy 安装目录。关闭注入器并执行恢复脚本后，WorkBuddy 会回到官方界面。

当前版本为 `0.7.3`，已针对 WorkBuddy `5.2.6` 与 Electron `37` 完成适配和实机验证。

## 项目来源

本项目的设计思路参考了 [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)。参考仓库为 Codex Desktop 提供外置主题能力，核心思路是通过本机 CDP 完成可逆注入，并保持官方应用包不变。

本项目在该思路上完成了 WorkBuddy 专项实现，包括 WorkBuddy 页面识别、运行时探针、主题格式、图片分层、页面样式、悬停状态修复、主题库、切换命令和自动化审计。当前工作区中保留了一份原始参考仓库，位于相邻目录 `../Codex-Dream-Skin-main`，它与本项目已经完全拆分。

## 当前能力

1. 为 WorkBuddy 主界面、会话、输入区、侧栏、设置中心和业务页面应用随图片气质变化的明暗主题。
2. 支持背景图、主视觉图和完整原图缩略卡三层图片结构。
3. 支持图片位置、尺寸、遮罩强度、面板透明度和整套配色调整。
4. 支持主题预设保存、列出、切换以及切换前自动备份。
5. 支持运行中的 WorkBuddy 热刷新主题。
6. 支持主界面右侧拍立得装饰卡生成。
7. 支持 WorkBuddy 页面重载后自动重新注入。
8. 支持一键恢复官方外观和可选的正常模式重启。
9. 支持主界面、悬停状态、输入区、业务页面、详情弹窗、设置中心和任务场景自动审计。
10. 支持截图和结构化 JSON 结果留档。
11. 支持分析导入图片的综合色相与明度，自动匹配绯樱少女、薄荷花房、晴日校园、鎏金夜宴或深海夜航 UI 色板与明暗模式。
12. 支持主题专属动态挂件，默认复用当前主视觉完整原图，并自动匹配悬浮节奏、摆动姿态、轨道饰物、主题光点和风格化卡片框架。
13. 支持 GIF 动图作为背景、主视觉或自定义挂件。
14. 支持 Windows 系统托盘控制，可刷新皮肤、切换主题、调整挂件和恢复外观。
15. 项目内置 `skills/workbuddy-skin-maker`，用于从图片风格推导明暗界面、制作动态挂件，并执行带历史任务滚动证据和人工复核清单的严格审计。

项目按照最初分析确定的两个阶段推进。阶段一完成可行性验证和安全运行闭环，阶段二完成全页面体验优化、图片分层、主题资产化和自动化验收。详细完成记录见 [阶段实施记录](./docs/PROJECT-STAGES.md)。

当前内置和已保存主题包括：

| 主题标识 | 主题名称 | 视觉特点 |
| --- | --- | --- |
| `deep-sea-layered` | 深海夜航 | 墨蓝、青绿、深色面板 |
| `gilded-night-banquet` | 鎏金夜宴 | 古风人物、金色高光、夜景背景 |
| `sunlit-campus` | 晴日校园 | 校园图片、绿色高光、拍立得装饰卡 |

## 技术栈

| 技术 | 用途 |
| --- | --- |
| PowerShell 5.1 | 启动、安装、恢复、进程发现、端口校验、主题管理和审计入口 |
| Node.js 22 | CDP WebSocket 客户端、页面探针、运行时注入、截图和审计逻辑 |
| Chrome DevTools Protocol | 连接 Electron 页面、执行脚本、监听导航、模拟悬停和截取页面 |
| JavaScript | 渲染进程中的样式挂载、图片 Blob URL 管理、清理和重载恢复 |
| CSS | 页面主题、分层背景、半透明面板、交互状态和兼容性修复 |
| JSON | 主题 Schema、运行状态和审计结果 |
| SVG | 内置背景和拍立得装饰卡 |

项目没有 npm 依赖，Node.js 部分仅使用运行时自带能力。

## 环境要求

1. Windows 10 或 Windows 11。
2. WorkBuddy Windows 桌面端。
3. Node.js 22 或更高版本。
4. Windows PowerShell 5.1 或更高版本。

## 快速开始

请先保存 WorkBuddy 中正在进行的工作。首次启用需要让 WorkBuddy 携带本机调试参数启动。

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd <path-to-repo>\WorkBuddy-Dream-Skin
.\scripts\start-workbuddy-skin.ps1 -RestartExisting
```

> **关于 `Set-ExecutionPolicy -Scope Process Bypass`**：仅对**当前这个 PowerShell 会话**生效，不改动系统策略；关闭窗口即失效。用于允许运行仓库里未签名的 `.ps1` 脚本。如果你已经用 `RemoteSigned` 或者更宽松的策略，可以省略该行。

验证运行状态并保存截图：

```powershell
.\scripts\verify-workbuddy-skin.ps1 -ScreenshotPath .\artifacts\manual-verify.png
```

验证成功时会检查目标页面、主题版本、根节点、背景图片、装饰层、文字对比度、横向溢出、任务内容和任务准备界面。

## 更换皮肤

查看已保存主题：

```powershell
.\scripts\switch-workbuddy-theme.ps1
```

切换到指定主题：

```powershell
.\scripts\switch-workbuddy-theme.ps1 sunlit-campus
.\scripts\switch-workbuddy-theme.ps1 gilded-night-banquet
.\scripts\switch-workbuddy-theme.ps1 deep-sea-layered
```

运行中切换会自动刷新注入器。当前主题会先备份到 `%LOCALAPPDATA%\WorkBuddyDreamSkin\themes\_autosave-current`。

使用同一张图片作为背景和主视觉：

```powershell
.\scripts\customize-workbuddy-theme.ps1 `
  -ImagePath "C:\Users\<YourName>\Pictures\theme.jpg" `
  -Name "我的主题" `
  -Accent "#5EE6C4" `
  -Background "#071318" `
  -Panel "#0B2025" `
  -SavePreset "my-theme"
```

分别设置背景、主视觉和人物装饰图：

```powershell
.\scripts\customize-workbuddy-theme.ps1 `
  -BackgroundImagePath "C:\Users\<YourName>\Pictures\background.jpg" `
  -HeroImagePath "C:\Users\<YourName>\Pictures\hero.jpg" `
  -CharacterImagePath "C:\Users\<YourName>\Pictures\character.png" `
  -HeroPosition "50% 35%" `
  -CharacterPosition "right 28px bottom 86px" `
  -CharacterSize "320px auto" `
  -SavePreset "layered-theme"
```

图片支持 PNG、JPG、JPEG、WebP、GIF 和 SVG，单张图片上限为 16 MB。GIF 会在 Chromium 渲染器中保持动画，建议优先用于挂件或局部主视觉。完整字段说明见 [主题格式](./docs/THEME-SCHEMA.md)。

省略 `Style` 时会自动分析图片。也可以先预览识别结果，或者显式指定视觉方向：

```powershell
.\scripts\customize-workbuddy-theme.ps1 -ImagePath "C:\Users\<YourName>\Pictures\pink-girl.jpg" -AnalyzeOnly
.\scripts\customize-workbuddy-theme.ps1 -ImagePath "C:\Users\<YourName>\Pictures\pink-girl.jpg" -Style PinkDream -SavePreset "pink-dream"
.\scripts\customize-workbuddy-theme.ps1 -ImagePath "C:\Users\<YourName>\Pictures\flower-room.jpg" -Style MintBloom -SavePreset "mint-bloom"
.\scripts\customize-workbuddy-theme.ps1 -ImagePath "C:\Users\<YourName>\Pictures\campus.jpg" -Style SunlitCampus -SavePreset "sunlit-campus"
```

可用风格为 `Auto`、`Current`、`PinkDream`、`MintBloom`、`SunlitCampus`、`GildedNight` 和 `DeepSea`。`Current` 会保留当前色板，只替换图片。显式传入颜色参数时，该颜色会覆盖风格色板中的对应值。

挂件支持 `Auto`、`On` 和 `Off` 三种模式。自动模式会校验挂件所属风格，并在窗口空间不足时隐藏：

```powershell
.\scripts\customize-workbuddy-theme.ps1 -ImagePath "C:\Users\<YourName>\Pictures\theme.jpg" -DecorationMode Auto -SavePreset "adaptive-theme"
.\scripts\customize-workbuddy-theme.ps1 -DecorationMode On -Style Current
.\scripts\customize-workbuddy-theme.ps1 -DecorationMode Off -Style Current
```

每次更换风格都会同步挂件样式。默认挂件直接复用当前主视觉图片，卡片内部使用 `contain` 完整展示原图，页面主视觉继续使用 `cover`。显式传入 `CharacterImagePath` 时，该图片会登记为当前主题的专属挂件并覆盖默认来源。

## 生成拍立得装饰卡

```powershell
.\scripts\new-workbuddy-polaroid.ps1 `
  -ImagePath "C:\Users\<YourName>\Pictures\photo.jpg" `
  -OutputPath ".\assets\themes\my-card.svg" `
  -Title "SUNLIT CAMPUS" `
  -Caption "MEMORIES IN MOTION"
```

生成后可通过 `customize-workbuddy-theme.ps1` 的 `CharacterImagePath` 参数应用并保存为预设。

## 安装快捷方式

```powershell
.\scripts\install-workbuddy-skin.ps1 -StartNow -RestartExisting
```

默认安装到 `%LOCALAPPDATA%\WorkBuddyDreamSkin\app`，并在桌面和开始菜单各创建一个 `WorkBuddy Dream Skin` 入口。安装或升级会清理旧的恢复、定制、主题和控制快捷方式。安装脚本会复制本项目的运行文件，不会写入 WorkBuddy 安装目录。

启动 `WorkBuddy Dream Skin` 会同时启用皮肤和系统托盘。使用 `StartNow` 时也会自动启动托盘：

```powershell
.\scripts\install-workbuddy-skin.ps1 -StartNow -RestartExisting
```

也可以直接从项目目录启动托盘：

```powershell
.\scripts\workbuddy-skin-tray.ps1
```

托盘菜单提供皮肤刷新、重启启用、主题切换、挂件显示、导入或更换图片、主题目录、恢复官方外观和退出托盘。恢复官方外观不会自动退出托盘，方便之后再次启用。

标准的 `WorkBuddy Dream Skin` 启动入口会默认启动或复用托盘。仅在自动化或明确不需要托盘时使用：

```powershell
.\scripts\start-workbuddy-skin.ps1 -NoTray
```

## 恢复和卸载

仅移除当前渲染器中的皮肤：

```powershell
.\scripts\restore-workbuddy-skin.ps1
```

移除皮肤并让 WorkBuddy 以普通模式重新启动：

```powershell
.\scripts\restore-workbuddy-skin.ps1 -RestartNormally
```

同时删除本项目创建的快捷方式：

```powershell
.\scripts\restore-workbuddy-skin.ps1 -RestartNormally -Uninstall
```

## 自动化审计

| 命令 | 覆盖范围 |
| --- | --- |
| `audit-workbuddy-hover.ps1` | 会话卡片、更多入口、快捷操作、活动入口和侧栏展开收起 |
| `audit-workbuddy-composer.ps1` | 模型按钮、工作空间、权限按钮、模型列表和说明浮层 |
| `audit-workbuddy-scenes.ps1` | 日常办公、代码开发、设计创意以及推荐标签 |
| `audit-workbuddy-pages.ps1` | 新建任务、四条历史任务及上下滚动、助理、项目、专家、技能、连接器、自动化、用户菜单和设置 |
| `audit-workbuddy-details.ps1` | 专家详情、新建项目、自动化编辑器、更多菜单和腾讯文档授权 |
| `audit-workbuddy-settings.ps1` | 账户、系统、智能体、快捷键、记忆、模型、助理、个性化、数据、安全和帮助 |

示例：

```powershell
.\scripts\audit-workbuddy-settings.ps1 -ScreenshotDirectory .\artifacts\settings
```

审计脚本只执行安全导航和视觉检查，不发送消息，不保存设置，不创建项目，不执行授权，也不进行账号操作。

## 目录结构

```text
WorkBuddy-Dream-Skin
  agents                 Codex 技能元数据
  artifacts              验证截图和审计结果
  assets                 CSS、主题配置、图片和渲染器注入脚本
  docs                   架构、开发、主题格式和交接文档
  references             运行时笔记和 QA 清单
  scripts                启动、恢复、主题管理、注入器和审计脚本
  AGENTS.md               后续维护约束
  CHANGELOG.md            版本变更记录
  README.md               项目入口文档
  SKILL.md                可由 Codex 使用的项目技能说明
  VERSION                 当前注入版本
```

## 运行时数据

运行状态保存在 `%LOCALAPPDATA%\WorkBuddyDreamSkin`：

| 路径 | 内容 |
| --- | --- |
| `state.json` | CDP 端口、注入器进程、WorkBuddy 路径、版本和启动时间 |
| `tray-state.json` | 托盘进程、项目路径和启动时间 |
| `injector.log` | 注入器标准输出 |
| `injector-error.log` | 注入器错误输出 |
| `theme` | 当前生效主题 |
| `themes` | 已保存主题预设 |
| `app` | 可选的独立安装副本 |

## 安全边界

1. CDP 只监听 `127.0.0.1` 或 `::1`。
2. 启动脚本会验证监听端口归属于选定的 `WorkBuddy.exe`。
3. 注入器只接受本地 `file:` 或 `vscode-file:` 页面，并再次检查 WorkBuddy 标题和根节点。
4. 主题不会写入 WorkBuddy 官方文件。
5. 装饰层使用 `pointer-events: none`，不会拦截鼠标操作。
6. 恢复脚本只终止状态文件记录且命令行匹配的注入器。
7. Windows 原生标题栏位于渲染器之外，当前方案无法通过 CSS 换肤。

## 文档索引

1. [阶段实施记录](./docs/PROJECT-STAGES.md)
2. [实现架构](./docs/ARCHITECTURE.md)
3. [开发与验证](./docs/DEVELOPMENT.md)
4. [主题格式](./docs/THEME-SCHEMA.md)
5. [AI 接手指南](./.github/AI/HANDOFF.md)（面向大模型协作者）
6. [运行时说明](./references/runtime-notes.md)
7. [质量检查清单](./references/qa-inventory.md)
8. [版本记录](./CHANGELOG.md)

## 常见问题（FAQ）

**Q：需要 `npm install` 吗？**
不需要。Node.js 部分只用运行时自带 API（`ws` 是全局的、`fs` / `path` / `crypto` 都是内置模块），项目也没有 `package-lock.json`。PowerShell 5.1 是 Windows 自带的。

**Q：WorkBuddy 启动了但没换肤怎么办？**
先确认 CDP 端点：`Get-Content $env:LOCALAPPDATA\WorkBuddyDreamSkin\state.json` 应该能看到 `port` 字段。用 `Invoke-RestMethod http://127.0.0.1:<port>/json/list`，返回列表里应该有 `title` 为 `WorkBuddy` 的条目。都没问题的话重新跑 `.\scripts\start-workbuddy-skin.ps1 -RestartExisting`。

**Q：审计脚本卡在 `Page.captureScreenshot` 怎么办？**
是 WorkBuddy 渲染进程的合成器暂时卡住，不是脚本问题。**最小化再还原** WorkBuddy 窗口，或者从托盘"重启启用"，通常就恢复了。已知 WorkBuddy 5.2.6 在部分 GPU 状态下会触发。

**Q：Light 主题下代码块 / 某个面板的字看不见？**
说明那条 CSS 硬编码了深色主题的 hex 值，没走 `--wbds-text` / `--wbds-panel` 令牌。定位到那条选择器，把 `color: #xxxxxx` 改成 `color: var(--wbds-text)` 即可让 token 层自动适配明暗。可参考 `commit ecd95d7` 的做法。

**Q：切换主题时托盘弹 `.NET Framework` 未处理异常？**
`0.7.4` 之前托盘子菜单读活动主题的 `presetId` 时没做 `PSObject.Properties` 探测，遇到手动定制主题（没有 `presetId`）会撞 `Set-StrictMode 2.0`。升级到 `0.7.4+` 或应用 `commit 2a2afda`。

**Q：能在 macOS / Linux 上用吗？**
目前不能。启动 / 恢复 / 托盘全是 PowerShell 加 Windows-only，但核心注入器 `scripts/injector.mjs` 是跨平台的 Node.js。POSIX 前端属于 "PRs welcome" 范畴。

**Q：想加自己的主题该改哪里？**
最快路径：`customize-workbuddy-theme.ps1 -ImagePath <你的图> -Style Auto -SavePreset "<名字>"`。预设会落到 `%LOCALAPPDATA%\WorkBuddyDreamSkin\themes\<名字>\`，不用改仓库代码。若想让主题跟仓库一起发布，PR 到 `assets/themes/<名字>/`（theme.json + 图片）。整套流程参见 [CONTRIBUTING.md](./CONTRIBUTING.md#adding-a-theme)。

## 当前限制

1. Windows 原生标题栏和菜单栏不属于 Electron 页面 DOM，无法被当前注入方式修改。
2. WorkBuddy 大版本升级可能改变页面结构，升级后应执行完整审计。
3. 大型会话页面的 DOM 很多，个别深层审计可能发生瞬时 CDP 超时，重新执行通常可以确认是否为暂态问题。
4. 自动化审计可以覆盖结构、颜色和交互状态，最终发布前仍应进行一次人工视觉检查。
