# 用户使用指南

> 目标读者：**只想给 WorkBuddy 换个好看外观的普通用户**。
> 开发/贡献相关请看 [CONTRIBUTING.md](../CONTRIBUTING.md)，架构原理请看 [ARCHITECTURE.md](./ARCHITECTURE.md)。

---

## 这是什么

给腾讯 WorkBuddy Windows 桌面端换外观的工具。**不改官方安装包**，注入的是可撤销的 CSS + 图片；不喜欢一条命令就恢复原样。

- 内置 11 套主题（深海夜航、鎏金夜宴、赤霄科幻、电音葱绿、红火财神、无 Bug 神社等，见 [README 主题表](../README.md#当前能力)）
- 支持自己丢一张图，脚本按图片色调自动匹配 UI 配色
- Windows 系统托盘一键切换主题、换图、恢复外观

---

## 先决条件

| 项 | 版本 |
|----|------|
| 系统 | Windows 10 / 11 |
| WorkBuddy | 已安装（官方桌面端）|
| PowerShell | 5.1 或更高（Windows 自带）|
| Node.js | 22 或更高（[官网下载](https://nodejs.org/) LTS 就行）|

**不需要** `npm install`，脚本只用 Node 自带能力。

---

## 5 分钟上手

### 1. 关掉 WorkBuddy，保存好当前对话

首次启用需要重启 WorkBuddy（换成带调试端口的启动方式），保险起见先存工作。

### 2. 打开 PowerShell 走到项目目录

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd <你把仓库放在哪>\WorkBuddy-Dream-Skin
```

> `Set-ExecutionPolicy -Scope Process Bypass` **只对当前这个窗口生效**，关掉就没了，不改系统策略。

### 3. 一键启用

```powershell
.\scripts\install-workbuddy-skin.ps1 -StartNow -RestartExisting
```

这行做四件事：
1. 在桌面和开始菜单建 `WorkBuddy Dream Skin` 快捷方式
2. 启动 WorkBuddy 并注入皮肤
3. 拉起系统托盘（右下角小图标）
4. 应用默认主题 `deep-sea-layered`（深海夜航）

看到 WorkBuddy 长得不一样了 + 托盘出现皮肤图标 → 装好了。

以后**双击桌面「WorkBuddy Dream Skin」快捷方式**就能启动，不用再走命令行。

---

## 日常使用（都在托盘里）

右键点右下角托盘皮肤图标，菜单如下——**90% 的操作都在这个菜单**：

| 菜单项 | 用途 |
|--------|------|
| **状态：已启用 · <主题名>** | 当前状态显示（灰色不可点） |
| **启用或刷新皮肤** | 智能——已在跑就热刷新不重启，没跑就启动 |
| **重启 WorkBuddy 并启用** | 硬重启（皮肤显示异常时用）|
| **切换主题 ▸** | 选内置或自己保存的主题（**热切换，不重启**）|
| **挂件显示 ▸** | 右上角小挂件卡的显示开关：自动 / 始终 / 关闭 |
| **导入或更换图片** | 选一张图片，脚本自动生成主题（推荐用法）|
| **打开主题目录** | 在文件管理器里打开预设保存目录 |
| **恢复官方外观** | 撤销注入，回到默认 WorkBuddy 界面 |
| **恢复并正常重启** | 同上 + 重启 WorkBuddy（回到官方启动方式）|
| **退出托盘** | 只退托盘，不影响皮肤 |

### 换主题

托盘 → **切换主题 ▸** → 挑一个。**热切换**——正在写的对话不会打断，皮肤秒变。

### 用自己的图当皮肤（推荐）

托盘 → **导入或更换图片** → 选图。脚本会：
1. 分析图片色调，自动匹配一套 UI 配色（粉、绿、青、金、蓝五档中选一）
2. 生成一套新主题并应用

**图片建议**：
- 尺寸：1800×1000 / 1920×1080 附近，横构图
- 主体（人物、主视觉）**放右边 60–70%**，左侧留白给 WorkBuddy 会话面板
- 支持 PNG / JPG / JPEG / WebP / GIF / SVG，单张 ≤ 16MB
- **GIF 会保持动画**——想做动态背景直接丢 GIF

### 挂件（右上角小卡片）怎么控制

- **自动**（默认）：主题预设决定。项目内置主题里，人物向的皮肤默认关（避免和 hero 图重复），纯场景向的默认开
- **始终显示**：不管什么主题都强开
- **关闭**：不管什么主题都强关

### 想回到原来的官方界面

托盘 → **恢复官方外观**。皮肤会被卸掉但 WorkBuddy 不重启，你的对话不打断。

想连 WorkBuddy 也重启一下（有时热恢复没干净）：**恢复并正常重启**。

### 完全卸载

命令行走一次：

```powershell
.\scripts\restore-workbuddy-skin.ps1 -RestartNormally -Uninstall
```

会：
- 撤销皮肤
- 正常方式重启 WorkBuddy
- 删掉本项目在桌面/开始菜单建的快捷方式

**你在 `%LOCALAPPDATA%\WorkBuddyDreamSkin\themes\` 保存的自定义主题不会被删**，想彻底清就手动删这个目录。

---

## 常见问题（Troubleshooting）

### Q1：托盘图标不见了 / 换主题没反应

打开 PowerShell 手动拉一下托盘：

```powershell
.\scripts\workbuddy-skin-tray.ps1
```

### Q2：换主题后界面变奇怪 / CSS 加载失败

托盘 → **重启 WorkBuddy 并启用**。硬重启会重新注入。

### Q3：WorkBuddy 直接从桌面 / 开始菜单点开的，皮肤没生效

这是**没走本项目的启动器**，WorkBuddy 少了 `--remote-debugging-port` 参数，注入器连不上。

**解决**：以后从「WorkBuddy Dream Skin」快捷方式启动；或者托盘 → **重启 WorkBuddy 并启用**。

### Q4：报错 `无法运行脚本，因为在此系统上禁止运行脚本`

PowerShell 执行策略太严。开脚本前先跑：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

只影响当前这个窗口，不改系统。

### Q5：Node.js 找不到 / `node: 命令未找到`

装 [Node.js 22 LTS](https://nodejs.org/)，装完把 PowerShell 窗口关掉重开（PATH 才会刷新）。

### Q6：换了个自定义图片，配色很怪

自动匹配是按图片色调打分给内置 5 套色板中的一套。**如果想强制指定风格**，走命令行：

```powershell
.\scripts\customize-workbuddy-theme.ps1 -ImagePath "你的图片路径" -Style GildedNight -SavePreset "my-gold-theme"
```

`-Style` 可选：`PinkDream` / `MintBloom` / `SunlitCampus` / `GildedNight` / `DeepSea` / `Auto` / `Current`。

### Q7：想把两套主题分别设为"工作日 / 周末"自动切换

现在没有内置定时切换。可以自己写一个 Windows 计划任务定时调 `switch-workbuddy-theme.ps1 <主题名>`。

### Q8：WorkBuddy 更新之后皮肤挂了

WorkBuddy 主版本升级偶尔会改渲染器结构。本项目当前适配 WorkBuddy `5.2.6` + Electron `37`。如遇不兼容：

1. 先跑「恢复官方外观」保证 WorkBuddy 能正常用
2. 到 [Issues](https://github.com/anthropics/claude-code/issues) 提 bug（贴 WorkBuddy 版本号）
3. 等新版适配

### Q9：本项目安不安全？会不会读我的聊天记录？

**不会**。安全边界：
- CDP 端口只监听本机回环（`127.0.0.1`）
- 注入器只往 WorkBuddy 页面挂 CSS + 图片 Blob URL
- 不读也不发送任何页面内容
- 完整威胁模型见 [SECURITY.md](../SECURITY.md)

代码全部 MIT 开源，源码不长，可自查。

---

## 进阶：想深度定制 / 做自己的主题

看这三个文档：

1. [主题格式](./THEME-SCHEMA.md)：`theme.json` 每个字段是什么
2. [开发与验证](./DEVELOPMENT.md)：怎么改 CSS、跑 preflight、验证注入
3. [CONTRIBUTING.md](../CONTRIBUTING.md)：贡献流程（PR / issue / 提交主题）

或者最简单的路径——直接改 `%LOCALAPPDATA%\WorkBuddyDreamSkin\themes\<主题名>\theme.json` 里的颜色 / 遮罩 / 图片位置字段，保存后托盘「启用或刷新皮肤」热刷新即可。

---

## 反馈

- Bug / 建议：[GitHub Issues](https://github.com/anthropics/claude-code/issues)
- 安全问题：私有 Security Advisory，见 [SECURITY.md](../SECURITY.md)
- 想贡献主题：[CONTRIBUTING.md](../CONTRIBUTING.md)
