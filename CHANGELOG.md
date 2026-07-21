# Changelog

## Unreleased

### `zero-bug-shrine` 重命名为 "Bug神社"

* 显示名从 "无 Bug 神社" 改为 "Bug神社"（中间无空格）。preset id / style 不变，切换、状态和主题库路径都不受影响。同步了 `assets/theme-presets/zero-bug-shrine/theme.json` 与 `assets/style-palettes.json`。

### 主题库扩充到 12 套

* 修正 `deep-sea-layered` preset 的 `name` 字段，去掉"分层版"后缀，托盘"切换主题"菜单恢复为纯 "深海夜航"。
* 补齐 `mint-bloom-studio`（薄荷花房）preset，之前只在 `style-palettes.json` 里有 palette、库里没预设，附带一张 SVG 主视觉（叶片）。`pink-dream` 由用户自定义的 `my-theme` 覆盖，未再新增占位 preset。
* 新增 4 套霓虹夜色 preset：
  - `crimson-scifi`（赤霄科幻）—— 红白 HUD、雷达网格、黑面板；
  - `neon-hatsune`（电音葱绿）—— 青葱霓虹 + 粉红辅色，赛博地面网格；
  - `violet-midnight`（紫夜限定）—— 星云紫、点状星野、深夜面板；
  - `stage-blackgold`（舞台黑金）—— 追光锥、金色台沿、黑色舞台。
* `assets/style-palettes.json` 同步登记这 4 套新 style；style 值非典范，`manage-workbuddy-themes.ps1` 的 palette-heal 会自动跳过，preset 里的色值直接生效。
* 再新增 2 套"梗系" preset：
  - `fortune-crimson`（红火财神）—— 中国红 + 金，灯笼、金币、"福"字大字，招财版；
  - `zero-bug-shrine`（无 Bug 神社）—— 通过绿 + 鸟居朱，御守、`EXIT 0` 终端图腾、"安"字大字，求编译一次通过版。
* 与 `stage-blackgold`（发布会调性）明确分家：黑金走演示台，红金走过年，绿朱走求 build 平安。
* 无 Bug 系列再拆一个变体（同 palette / 同 `style: zero-bug-shrine`，主视觉走不同人设）：
  - `zero-bug-shrine-maid`（除虫女仆）—— 甜妹猫耳女仆 + 长猫耳的终端窗口，配 `nya~` 对话泡泡、爱心和"萌"字底纹；`secondary` 从灰绿换成甜粉 `#F4A8C0`。
* `README.md` / `README.en.md` 主题表格从 3 行扩到 9 行，`ROADMAP.md` 相关 "补 preset" 与 "gallery" 条目更新到 2026-07-20。

### 面向普通用户的使用指南

* 新增 [`docs/USER-GUIDE.md`](docs/USER-GUIDE.md)，任务导向：装完 5 分钟上手 + 托盘每项菜单说明 + 9 个 Q&A（托盘不见、CSS 挂了、绕过启动器、执行策略、Node 找不到、配色跑偏、定时切换、升级不兼容、隐私安全）。README 文档索引里把它排在第一条 + 加粗。

### 内置 12 套 preset 随仓库发布，clone 即用

* 新增 `assets/theme-presets/` 目录，仓库内置全部 12 套主题预设（`theme.json` + 压缩到 JPG q88 的 hero 图，合计 ~4.2MB，源 PNG 约 24MB 压掉 82%）。视觉几乎无损，Electron 对 JPG / PNG 一视同仁。补齐 `pink-dream-petals`（绯樱少女）作为公开发布版本；清理开发期遗留的 `Pictures/1-3.png` 早期源图（代码零引用）。
* `install-workbuddy-skin.ps1` 加入首次种子逻辑：把 `assets/theme-presets/*` 拷到 `%LOCALAPPDATA%\WorkBuddyDreamSkin\themes\`，**已存在的目录默认保留不覆盖**，防止踩掉用户改过的本地 preset。加 `-ResetBuiltinPresets` switch 可强制覆盖到仓库最新版。
* `.gitignore` 排除 `Pictures/*.png`（AI 源图上百 MB），保留已跟踪的 `1/2/3.png` 兼容既有历史。仓库里的正式发布图放在 `assets/theme-presets/<name>/*.jpg`。

### 快捷方式启动不再弹 PS 窗口

* `install-workbuddy-skin.ps1` 生成的桌面 / 开始菜单快捷方式默认加 `-WindowStyle Hidden` + `WindowStyle = 7`（最小化）双保险。双击后不再看到黑色 PS 窗口在 30 秒验证轮询期间碍眼，直接等托盘图标出现即可。旧快捷方式重跑 install 或用一行 WScript.Shell 脚本原地打补丁生效。

### 开源发布准备（ROADMAP § J）

* 新增 `LICENSE`（MIT），版权行 "Copyright (c) 2026 WorkBuddy Dream Skin contributors"，与上游 `Fei-Away/Codex-Dream-Skin` 兼容。
* 新增 `NOTICE.md`：商标声明（WorkBuddy = 腾讯商标）、上游归属、素材声明。
* 新增 `CREDITS.md`：说明所有图片素材均为 AI 生成，MIT 覆盖，允许下游 fork 直接替换文件路径。
* 新增 `SECURITY.md`：威胁模型、私有 Security Advisory 上报流程、5 天 ack / 30 天修复 SLA、协调披露条款。
* 新增 `CODE_OF_CONDUCT.md`：Contributor Covenant 2.1 原文。
* 新增 `CONTRIBUTING.md`：仓库结构、开发循环、preflight 门禁要求、"如何加主题"的三级路径（preset / palette / decoration shape）、PR 检查清单。
* 新增 `README.en.md` 英文精简版，README.md 顶部加中英语言切换 + FAQ 段（覆盖本轮遇到的 7 类常见问题） + `Set-ExecutionPolicy` 解释段。
* 新增 `.github/`：`ISSUE_TEMPLATE/{bug_report.md, feature_request.md, config.yml}`、`PULL_REQUEST_TEMPLATE.md`、`workflows/preflight.yml`（在 Windows + Node 22 上跑 `npm run preflight`，产物保留 14 天）。
* `docs/AI-HANDOFF.md` → `.github/AI/HANDOFF.md`：从公共文档索引里挪出。
* `AGENTS.md` / `SKILL.md` 顶部加中英双语横幅，明确"给 AI 协作者用，人类看 CONTRIBUTING / README"。
* `preflight.mjs` 新增 `VERSION sync with package.json` 检查，双源同步失配立即 fail（当前 9/9 pass）。
* `package.json` 移除 `"private": true`、加 `"license": "MIT"`、description 改英文。
* README + docs 里硬编码的 `D:\code\Codex\dream-skin\WorkBuddy-Dream-Skin` 与 `D:\Pictures\` 路径全部换成占位符。

### 挂件系统重做（ROADMAP § H）

* `theme.json` 新增 `decoration.shape` 字段（`polaroid` 默认 / `stamp` / `sticker` / `pressed-leaf` / `heart` / `porthole`）与 `layout.decorationAnchor` 字段（`top-right` 默认 / `bottom-right` / `top-left` / `bottom-left`）。
* `renderer-inject.js` 依据 `data-workbuddy-dream-skin-decoration-shape` / `-anchor` 分派：内容形状（stamp / sticker / pressed-leaf）替换整个装饰卡内容，框形（heart / porthole）在 `<img>` 上加 clip-path + SVG 边框叠层。
* 五种新形状全部落在 `assets/css/60-chrome.css` 文件末尾，避免被 per-style card 覆盖。

### live-gate 结构性修复（ROADMAP § D）

* 历史上第一次 `automatedPass: true`：14/14 automated gates + 7/7 live gates 全部通过 `run-strict-audit.ps1`。修补包括：
  - `auditPagesSession` 打开 user-menu 时 `allowClipped: true`，避开 5.2.6 底栏 813 > innerHeight 800 的裁剪。
  - `hasLightRgb` 改成正则匹配 rgba 三通道 ≥240，避免把 `#F2B866` 金橙 accent 误报为近白面。
  - `auditComposerSession` / `auditScenesSession` 起头强制回到"新建任务"页。
  - 场景切换从 350ms 硬 sleep 换成最多 8×400ms 轮询快速动作元素。
  - 历史任务首帧 settle 加 6×700ms 轮询，等 `initial.visibleTextCount > 0`。

### 稳定性 & 视觉修复（ROADMAP § G / 用户 2026-07-19 反馈）

* 骨架加载器（`.chat-container__message-skeleton-content` 等）背景 `background:` 简写归零透明度导致 hero cover 透出的问题：拆成 `background-color: color-mix(panel 90%, transparent)` 底 + `background-image: linear-gradient(...)` 闪光。
* 代码块 `.cb-markdown-pre` / `.cb-markdown-pre code` 硬编码 `color: #e5f5ef` 在 light 主题下几乎看不见：换 `var(--wbds-text)`，token 层自动切明暗。
* `agent-mail-activation` 面板文字继承 WorkBuddy 未 themed 的黑色 rgba：`__title` → `--wbds-text`，`__desc / __agreement-prefix` → `--wbds-muted`，`__agreement-link` → `--wbds-accent-alt`。
* 深海调深绿黑（`#041713 / #031512 / #061714`）在 pink-dream / mint-botanical / sunlit-campus 上把按钮文字染成绿黑：新增 `--wbds-on-accent` token（dark 模式 `color-mix(black 88%, accent)`；light 模式 `#fff`），13 处硬编码值全部路由到该 token。
* 托盘"切换主题"子菜单打开时 `.NET Framework` 未处理异常（strict-mode 下访问缺失的 `presetId`）：改用 `$activeTheme.PSObject.Properties['presetId']` 探测后再读。
* `injector.mjs` 截图 HiDPI 归一化：`capture()` 先读 `cssVisualViewport`，用 `clip: { scale:1 }` 让输出恒为 CSS 像素尺寸。
* `once` / `remove` / `probe` 模式失败时静默退 0：新增 `NON_AUDIT_EXIT_CODES = { verify:2, once:6, remove:10 }` 与 `isRunResultFailed()` 归一化判定。

## 0.7.3

* 新增项目内 Skill `skills/workbuddy-skin-maker`，固化图片分析、自适应明暗主题、动态挂件、历史任务阅读面板和产物卡片的制作流程。
* 新增严格审计契约，要求静态检查、七类实时审计、至少四条历史任务上下滚动、截图哈希差异校验，以及明暗主题人工复核。
* 新增可执行门禁脚本 `run-strict-audit.ps1`，保存逐项原始日志、耗时和结构化报告，任何非零退出码都会保留为失败。
* 支持按单项实时门禁诊断失败，但只有完整实时审计与人工复核全部通过时才能输出 `releaseReady: true`。

## 0.7.2

* 历史任务正文新增高透明度阅读面板、稳定文字底色和更舒适的段落行高，避免正文直接叠在高亮背景图上。
* 用户消息气泡、技能标签与运行状态改为独立层级，缩短输入区顶部渐隐，减少滚动状态中的内容混叠。
* 任务产物区域升级为卡片组，增加强调边、标题层级、柔和阴影、悬停抬升和独立查看入口。
* 文件与附件卡片统一使用主题化边框、背景和阴影。
* 空运行节点不再生成无意义的圆角占位条，历史任务页同时隐藏会遮挡产物区域的原生 Buddy 形象。

## 0.7.1

* 页面审计新增历史任务步骤，默认打开四条已有任务并检查聊天内容、输入区、任务产物区域与页面布局。
* 每条历史任务都会滚动到顶部，再回到底部，并在两个位置重复检查文字对比度、伪元素与横向溢出。
* 历史任务审计要求聊天页至少显示一条消息、输入区可见，并确认首页挂件和品牌装饰已经避让。
* 审计结果新增 Markdown、代码块、表格、产物和滚动位置数据，完成后自动返回新建任务，全程不发送消息。

## 0.7.0

* 五套风格新增明确的明暗模式，绯樱少女、薄荷花房和晴日校园使用明亮面板与深色文字，鎏金夜宴和深海夜航继续使用暗色界面。
* 图片自动分析新增暖金暗调识别，并在应用色板时同步写入 `appearance`。
* 旧版标准风格主题首次应用时自动迁移到对应的新色板，解决旧校园主题继续沿用深色配色的问题。
* 挂件新增悬浮、摆动、轨道饰物和错峰闪烁光点，并为五种主题调整运动节奏与装饰轮廓。
* 页面和悬停审计改为识别当前明暗模式，在两种模式下都以文字对比度和色调一致性作为验收依据。

## 0.6.6

* 托盘挂件显示子菜单为当前模式增加对钩，并在每次展开时同步活动主题配置。
* 主题切换子菜单为当前皮肤增加对钩，切换后立即更新单选标记。
* 活动主题记录来源预设标识，手动定制后自动清除，避免主题对钩标错。

## 0.6.5

* 托盘“启用或刷新皮肤”会识别活动调试端口，普通模式下明确请求重启确认。
* 托盘主题切换支持在确认后依次应用主题、重启 WorkBuddy 和启用皮肤。
* 用户取消重启时仍会保存所选主题，并通过托盘通知说明下次启用时生效。
* 主题管理脚本新增显式的 `RestartExisting` 串联入口，避免主题已保存但界面无变化。

## 0.6.4

* 修复托盘“切换主题”缺少子菜单箭头、无法展开主题列表的问题。
* 主题菜单增加初始占位项，打开时动态刷新当前可切换皮肤。
* 托盘探针增加主题数量和主题标识检查。

## 0.6.3

* 修复托盘将挂件从关闭切换为自动或始终显示时只恢复边框、没有恢复图片的问题。
* 挂件重新启用时会自动绑定当前主题主视觉，并恢复对应风格、位置、尺寸和透明度。
* 渲染器对空挂件素材增加隐藏防护，避免出现塌缩的空边框。

## 0.6.2

* 桌面和开始菜单统一为一个 `WorkBuddy Dream Skin` 启动入口。
* 安装或升级时自动清理恢复、定制、主题和托盘控制等旧快捷方式。
* 托盘新增导入或更换图片入口，原有主题切换、挂件控制和恢复功能继续保留。

## 0.6.1

* 标准皮肤启动入口现在默认确保系统托盘存在，无需单独打开控制快捷方式。
* 托盘启动增加状态文件和命令行双重核验，已有实例会直接复用。
* 启动脚本新增 `NoTray` 开关，供自动化或显式无托盘场景使用。

## 0.6.0

* 背景、主视觉、自定义挂件和拍立得素材新增 GIF 动图支持，继续执行 16 MB 单文件限制。
* 新增 Windows 系统托盘控制器，可刷新皮肤、重启启用、切换主题、调整挂件、打开主题目录和恢复外观。
* 托盘使用单实例和独立状态记录，卸载时只结束经过命令行核验的托盘进程。
* 安装流程新增托盘快捷方式，使用 `StartNow` 时会同时启动托盘控制器。

## 0.5.2

* 挂件增加主题专属姿态，绯樱、薄荷、校园、鎏金和深海风格分别使用不同倾角与轮廓。
* 挂件边框增加缎带、花瓣、叶片、胶带、金饰和冷光标记等非对称点缀。
* 优化挂件漂浮幅度与旋转支点，并继续保持装饰层不接管鼠标操作。

## 0.5.1

* 完成任务搜索弹窗的深色主题覆盖，补齐输入框、任务列表、时间、悬停与聚焦状态。
* 完成右侧产物和设计工作区外壳的主题覆盖，统一标签栏、标题栏、预览区与工具按钮。
* 补齐输入区按钮和进度环颜色变量，优化增强提示、语音及相关圆形控件的悬停反馈。
* 强化生成回复期间嵌套状态文字的颜色继承，避免动画子节点重新落入低对比深色。
* 页面审计新增任务搜索弹窗，并将右侧详情工作区加入亮色表面检查。

## 0.5.0

* 挂件默认复用当前主题主视觉，以完整原图缩略卡展示，不再依赖额外生成素材。
* 主视觉继续使用 `cover` 填充页面，缩略卡使用 `contain` 保留原图完整构图。
* 五套风格新增各自的缩略卡边框、圆角、阴影和安全位置。
* 补齐 WorkBuddy 运行态 `--cb-text-*` 变量，修复深度思考、生成回复和权限文字对比度。
* 为闪动加载文字增加主题化高对比渐变，保留运行动画和可读性。
* 修复运行中消息队列的浅灰底，并覆盖聊天页权限按钮内部标签颜色。

## 0.4.0

* 新增主题专属挂件规则，挂件记录所属风格、来源、变体和显示模式。
* 新增自动、开启和关闭三种挂件模式，自动模式会在窄窗口或低高度窗口隐藏。
* 切换主题时校验挂件风格，旧挂件不匹配时自动生成对应风格 SVG。
* 新增粉色花卉、薄荷标本、校园卡片、鎏金月影和深海声呐五类生成模板。
* 新增粉薄荷花卉透明 PNG 挂件，并绑定到当前花房主题。
* 预设切换流程新增挂件同步，兼容旧主题中的校园、鎏金和深海配色。
* 完成 WorkBuddy 5.2.6 实机验证，记录代码开发场景快捷操作审计的页面内容差异。

## 0.3.0

* 新增图片风格自动分析，可识别绯樱少女、薄荷花房、晴日校园和深海夜航四类视觉方向。
* 新增四套完整 UI 色板，统一驱动背景、面板、按钮、文字、边框、遮罩和交互状态。
* 自定义脚本新增 `Style` 与 `AnalyzeOnly` 参数，并开放全部十项颜色令牌的显式覆盖。
* 背景与首页遮罩改为从主题底色动态生成，避免粉色、薄荷色和校园主题残留深海青色调。
* 保存主题预设时同步更新主题标识，便于验证器准确识别当前主题。

## 0.2.3

* 修复强制关闭 WorkBuddy 后只等待 700 毫秒，导致较慢退出时误报失败的问题。
* 强制关闭后最多等待 8 秒，并以 250 毫秒间隔确认主进程已经退出。
* 将 WorkBuddy 项目从原始参考仓库中拆分为独立顶层目录。
* 恢复原始参考仓库内容，并完成逐文件哈希一致性验证。
* 重写项目 README，补充技术栈、功能、命令、目录、安全边界和文档索引。
* 新增实现架构、开发验证、主题格式和 AI 接手文档。
* 新增阶段一与阶段二实施记录，整理每个阶段的目标、完成项、验收依据和演进关系。

## 0.2.2

* 修复任务准备页使用浅色背景导致状态文字难以辨认的问题。
* 修复任务完成后代码块、代码标题栏和表格仍显示浅色背景的问题。
* 修复侧栏查看更多、收起和空间标题悬停时变为白色的问题。
* 验证器新增任务内容区和任务准备页表面检查，悬停审计新增三个侧栏目标。

## 0.2.1

* 新增拍立得装饰图生成器，可从主视觉图片生成右下角透明卡片。
* 新增单命令主题切换入口，省略编号时可直接查看主题库。
* 安装后的主题快捷方式改为使用简化切换入口。

## 0.2.0

* 新增背景图、首页横幅图和透明角色图三层主题结构
* 新增背景、横幅与角色的裁切位置和尺寸参数
* 新增背景遮罩、横幅遮罩、角色透明度和面板透明度参数
* 新增主题预设保存、列表与切换脚本
* 兼容旧版单图主题配置并自动迁移到第二版主题结构
* 修复热刷新换图时复用旧 Blob URL 的问题
* 验证器新增背景、横幅与角色装饰层检查

## 0.1.0

* 修复输入区模型按钮与工作空间按钮悬停时的浅色背景和文字消失问题
* 修复默认权限按钮悬停时文字和图标对比度过低的问题
* 修复日常办公、代码开发和设计创意场景选中快捷入口后推荐标签显示浅色背景的问题
* 修复代码开发推荐标签横向溢出提示仍使用白色渐变的问题
* 修复模型说明浮层未被通用提示框规则覆盖而显示白底的问题
* 新增输入区模型选择完整交互链路专项审计

* 新增 WorkBuddy Windows 外置主题实现
* 新增“深海夜航”默认主题及响应式样式
* 新增回环 CDP 启动、注入、热重载、验证和恢复流程
* 新增 WorkBuddy 进程与监听端口所有权校验
* 新增本地图片和颜色自定义功能
* 新增开始菜单与桌面快捷方式安装器
* 新增静态载荷检查、运行探针和截图验证能力
* 兼容代理终端中的 `ELECTRON_RUN_AS_NODE` 环境变量
* 修复单进程查询在 PowerShell 严格模式下的集合展开问题
* 修复同版本主题内容无法热更新的问题
* 完成 WorkBuddy 5.2.5 浅色模式下的深色主题覆盖与实机验证
* 修复聊天页顶部栏、选中任务和加载骨架的低对比度问题
* 新增顶部栏、选中项对比度与聊天页装饰避让验收门槛
* 修复任务卡片、更多入口、快捷操作和活动入口的浅色悬停状态
* 修复提示气泡、菜单浮层和输入区伪元素的浅色残留
* 新增真实鼠标命中、悬停表面和浮层文本对比度审计
* 修复用户菜单签到卡片、操作按钮和文字在深色主题下的清晰度
* 完成项目、专家、技能、连接器、自动化和设置页的深色主题覆盖
* 修复侧栏当前入口及快捷按钮在悬停和激活状态下的白色背景
* 修复非首页装饰文字遮挡页面标题和列表内容的问题
* 新增九个主要页面的安全导航、亮色面、文字对比度、伪元素和横向溢出审计
* 修复专家详情、新建项目和自动化编辑器的浅色弹窗与表单控件
* 修复更多菜单选中项、腾讯文档授权页和设置左栏底部的浅色残留
* 修复助理入口快捷操作区域在悬停状态下的白色背景
* 新增五个深层场景的安全导航与视觉审计
* 完成设置中心十一项页面的逐项深色主题覆盖
* 修复账户额度卡片、快捷键表格与键帽、记忆卡片、模型空状态的浅色残留
* 修复助理绑定区、个性化输入框、数据管理条目和安全中心卡片的浅色残留
* 新增设置中心专项安全导航与视觉审计，并保留二维码扫码所需白底
