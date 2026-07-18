# 开发与验证

## 开发环境

推荐环境为 Windows 10 或 Windows 11、Windows PowerShell 5.1、Node.js 22 及 WorkBuddy 5.2.5。项目当前不需要执行 `npm install`。

进入项目目录：

```powershell
cd D:\code\Codex\dream-skin\WorkBuddy-Dream-Skin
Set-ExecutionPolicy -Scope Process Bypass
```

## 常用开发循环

1. 运行 `rg` 找到对应页面选择器和已有规则。
2. 修改 `assets/css/*.css`（按 `assets/css/manifest.json` 声明顺序拼接）、`assets/renderer-inject.js` 或相关脚本。新增分层时在 manifest 里插入对应位置，不要依赖文件系统排序。
3. 执行静态检查。
4. 运行启动脚本完成热刷新。
5. 执行通用验证。
6. 执行与改动范围对应的专项审计。
7. 人工检查截图和真实悬停状态。
8. 更新版本和变更记录。

## 静态检查

PowerShell 解析检查：

```powershell
$allErrors = @()
Get-ChildItem .\scripts\*.ps1 | ForEach-Object {
  $tokens = $null
  $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
  $allErrors += $errors
}
$allErrors
if ($allErrors.Count -gt 0) { exit 1 }
```

Node.js 和载荷检查：

```powershell
node --check .\scripts\injector.mjs
node .\scripts\injector.mjs --check-payload
Get-Content .\assets\theme.json -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
```

## 实时验证

启动或刷新：

```powershell
.\scripts\start-workbuddy-skin.ps1 -RestartExisting
```

通用验证：

```powershell
.\scripts\verify-workbuddy-skin.ps1 -ScreenshotPath .\artifacts\verify.png
```

直接探测 WorkBuddy 结构：

```powershell
.\scripts\probe-workbuddy.ps1
```

## 专项审计选择

| 修改内容 | 必须执行的审计 |
| --- | --- |
| 侧栏、列表、按钮悬停 | `audit-workbuddy-hover.ps1` |
| 输入区、模型和权限菜单 | `audit-workbuddy-composer.ps1` |
| 首页场景和推荐标签 | `audit-workbuddy-scenes.ps1` |
| 主导航或通用页面容器 | `audit-workbuddy-pages.ps1` |
| 专家、项目、自动化和授权弹窗 | `audit-workbuddy-details.ps1` |
| 设置中心 | `audit-workbuddy-settings.ps1` |
| 任务准备、任务结果、Markdown | 通用验证加人工任务页检查 |

所有审计都可使用 `ScreenshotDirectory` 保存逐页截图。建议每次版本发布将最终截图放在 `artifacts`，并使用包含版本号的文件名。

## 脚本职责

| 文件 | 职责 |
| --- | --- |
| `common-workbuddy.ps1` | 路径、进程、端口、状态和通用安全函数 |
| `start-workbuddy-skin.ps1` | 启动 WorkBuddy、启动注入器和验证 |
| `restore-workbuddy-skin.ps1` | 清理渲染器、停止注入器和可选恢复正常启动 |
| `install-workbuddy-skin.ps1` | 安装独立运行副本和快捷方式 |
| `injector.mjs` | CDP 客户端、注入、验证、截图和审计核心 |
| `customize-workbuddy-theme.ps1` | 创建或修改活动主题和预设 |
| `manage-workbuddy-themes.ps1` | 列出和应用预设 |
| `switch-workbuddy-theme.ps1` | 简化的一条命令主题切换入口 |
| `new-workbuddy-polaroid.ps1` | 从普通图片生成 SVG 拍立得装饰卡 |
| `workbuddy-skin-tray.ps1` | Windows 系统托盘控制器和主题快捷菜单 |

## 调试信息

运行时目录为 `%LOCALAPPDATA%\WorkBuddyDreamSkin`。优先检查：

1. `injector-error.log` 是否出现连接、解析或注入错误。
2. `state.json` 中的端口、WorkBuddy 路径和 `skinRoot` 是否正确。
3. `Get-NetTCPConnection` 中该端口是否只监听回环地址。
4. 监听进程是否为状态文件记录的 WorkBuddy。
5. `probe-workbuddy.ps1` 是否识别到 WorkBuddy 根节点。
6. `verify-workbuddy-skin.ps1` 的失败字段指向哪类页面。

大型会话可能让一次 CDP DOM 查询超过超时时间。先重新执行相同验证。如果重复失败，再缩小探针范围或提高特定审计的安全超时，避免直接放宽所有操作。

## CSS 维护建议

1. 优先使用稳定语义类名、页面根节点和 VS Code 变量。
2. 哈希类名只作为局部补充，避免让整个规则依赖构建哈希。
3. 新增浅色表面修复时同时检查普通、悬停、选中、禁用和聚焦状态。
4. 对二维码等功能性图像保留必要白底。
5. 不要隐藏原生控件来换取视觉统一。
6. 新增装饰元素时确保不会拦截指针，也不会产生横向溢出。

## 版本发布清单

1. 更新 `VERSION`。
2. 在 `CHANGELOG.md` 记录用户可见变化。
3. 完成全部静态检查。
4. 完成通用实时验证。
5. 根据影响范围完成专项审计。
6. 手工检查欢迎页、长会话、代码块、表格、任务准备页、任务完成页、设置页和窄窗口。
7. 列出主题并至少切换一次预设。
8. 确认只有一个注入器监视进程。
9. 确认注入器命令行来自当前项目或已安装副本。
10. 确认没有遗留临时调测服务。
