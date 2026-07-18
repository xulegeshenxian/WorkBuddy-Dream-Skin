# 实现架构

## 目标

WorkBuddy Dream Skin 为 WorkBuddy Windows 桌面端提供可逆、可更新、可验证的外置主题。架构选择优先满足四个条件：

1. 不修改官方应用包。
2. 不破坏签名和自动更新。
3. 可以随时恢复官方外观。
4. 可以通过脚本自动验证真实运行效果。

## 总体链路

```text
PowerShell 启动器
  发现 WorkBuddy.exe 和 Node.js
  选择本机回环端口
  启动或复用带 CDP 的 WorkBuddy
  校验端口归属
    Node.js 注入器
      查询 CDP 页面目标
      识别 WorkBuddy 渲染页面
      读取 CSS、主题 JSON 和图片
      建立 WebSocket 会话
        渲染器注入脚本
          写入主题 CSS
          设置 CSS 变量
          创建装饰层
          创建图片 Blob URL
          监听 DOM 和页面重载
          提供清理函数
```

## 启动阶段

`scripts/start-workbuddy-skin.ps1` 是主入口。

1. `Resolve-WorkBuddyExecutable` 按显式路径、运行进程、卸载注册表和常见安装目录寻找 `WorkBuddy.exe`。
2. `Resolve-NodeExecutable` 确认 Node.js 主版本不低于 22。
3. 如果 WorkBuddy 已经通过本项目启动，脚本会读取 `%LOCALAPPDATA%\WorkBuddyDreamSkin\state.json` 并复用经过验证的端口。
4. 如果 WorkBuddy 正在普通模式运行，调用者需要关闭应用，或使用 `RestartExisting` 参数允许安全重启。
5. 新启动参数为 `--remote-debugging-address=127.0.0.1` 和动态端口。
6. 启动器检查 `/json/list` 中存在本地文件协议页面。
7. 启动器继续检查监听地址和进程可执行文件，确保端口属于目标 WorkBuddy。
8. Node.js 注入器以隐藏后台进程运行，并将输出写入本地状态目录。
9. 启动器循环执行实时验证，只有验证通过才报告启用成功。

系统托盘由独立的 PowerShell Windows Forms 进程提供。托盘只调用现有启动、主题、定制和恢复脚本，不直接操作 WorkBuddy 渲染器。托盘使用互斥锁保持单实例，并通过独立状态文件支持安全卸载。

## CDP 目标识别

`scripts/injector.mjs` 通过 CDP 列出页面目标。候选页面必须使用 `file:` 或 `vscode-file:` 协议。连接后还会在渲染器中执行探针，检查页面标题、`#root` 以及 WorkBuddy 相关结构。

两层识别用于避免把主题脚本注入其他 Electron 页面，也用于降低错误端口带来的风险。

## 载荷组装

注入器从以下来源构建载荷：

1. `assets/workbuddy-skin.css`，包含所有页面样式和兼容规则。
2. `assets/theme.json`，包含内置主题配置。
3. `%LOCALAPPDATA%\WorkBuddyDreamSkin\theme`，存在时覆盖内置主题。
4. 主题引用的本地图片。
5. `assets/renderer-inject.js`，包含渲染器生命周期逻辑。
6. `VERSION`，用于注入结果与源代码版本一致性检查。

重复图片角色只编码一次。渲染器根据图片内容创建 Blob URL，并在下一次应用或清理时撤销旧 URL，避免长时间切换主题造成资源积累。GIF 使用 `image/gif` Blob URL，因此 Chromium 可以保留原始帧动画。

## 渲染器生命周期

渲染器注入逻辑具有幂等性。

1. 应用新载荷前先调用上一版本的清理函数。
2. 页面中只保留一个主题样式节点。
3. 页面中只保留一个装饰层根节点。
4. 主题元数据和颜色通过 CSS 变量传递。
5. `MutationObserver` 以防抖方式观察 WorkBuddy 工作区变化。
6. CDP 页面加载事件会触发完整重新注入。
7. 清理函数会移除样式、类名、装饰节点、观察器和 Blob URL。

## CSS 分层

主题图片分为三个角色：

| 角色 | 典型用途 | 显示范围 |
| --- | --- | --- |
| background | 全局底图 | 主内容区域和需要背景的业务页面 |
| hero | 欢迎页主视觉 | 欢迎页和新建任务首页 |
| character | 拍立得、人物卡或小装饰图 | 仅欢迎页，避免遮挡会话和设置内容 |

面板使用主题色、明暗模式和透明度变量形成匹配图片气质的玻璃效果。绯樱、薄荷和校园风格使用明亮表面，鎏金和深海风格使用暗色表面。交互修复覆盖 `hover`、`focus-visible`、弹窗、浮层、工具提示、输入控件、设置页面、Markdown、代码块和表格。

CSS 同时映射部分 VS Code 颜色变量，因为 WorkBuddy 渲染器内部使用了相关变量体系。

## 主题热刷新

主题管理脚本写入活动主题后，会检查状态文件中的 CDP 端口。如果 WorkBuddy 仍处于有效会话，脚本重新执行启动入口。启动入口会终止上一注入器，启动新注入器并重新验证，WorkBuddy 主进程无需重启。

## 恢复机制

`scripts/restore-workbuddy-skin.ps1` 执行以下操作：

1. 只终止状态文件记录且命令行路径匹配的注入器进程。
2. 通过 CDP 调用渲染器清理函数。
3. 删除状态文件。
4. 可选地关闭当前 WorkBuddy，并在不携带调试参数的情况下重新启动。
5. 可选地删除本项目创建的快捷方式。

由于官方安装目录从未被修改，恢复不需要修复应用文件或重建签名。

## 自动验证模型

验证分为静态检查和实时检查。

静态检查包括 PowerShell 解析、Node.js 语法、载荷组装、主题 JSON 和版本一致性。

实时检查包括端口归属、页面身份、主题节点、图片变量、装饰层、文字对比度、横向溢出、页面结构、悬停状态和特定业务页面。专项审计通过 CDP 鼠标事件和 DOM 探针访问真实交互状态。

完整门禁清单见 [QA inventory](../references/qa-inventory.md)。

## 原生标题栏边界

WorkBuddy 顶部约 30 像素的 Windows 标题栏和菜单栏位于 Electron 渲染器之外。CDP 和页面 CSS 无法访问这一区域。更改该区域需要替换窗口框架并重新实现拖拽、菜单、最小化、最大化和关闭控件，风险超出当前无侵入方案的边界。
