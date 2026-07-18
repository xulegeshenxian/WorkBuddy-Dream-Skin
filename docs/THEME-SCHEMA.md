# 主题格式

## 存储位置

内置主题位于 `assets/theme.json`。用户活动主题位于 `%LOCALAPPDATA%\WorkBuddyDreamSkin\theme`。主题预设位于 `%LOCALAPPDATA%\WorkBuddyDreamSkin\themes\主题标识`。

每个主题目录包含一个 `theme.json` 和该配置引用的本地图片。图片文件名使用相对路径，不能引用远程 URL。

## Schema 2 示例

```json
{
  "schemaVersion": 2,
  "id": "example-theme",
  "style": "mint-bloom",
  "appearance": "light",
  "name": "示例主题",
  "eyebrow": "WORKBUDDY VISUAL THEME",
  "tagline": "让工作空间拥有自己的气质。",
  "status": "LOCAL LINK ACTIVE",
  "images": {
    "background": "background-image.jpg",
    "hero": "hero-image.jpg",
    "character": null
  },
  "layout": {
    "backgroundPosition": "50% 50%",
    "backgroundSize": "cover",
    "heroPosition": "50% 35%",
    "heroSize": "cover",
    "characterPosition": "right 14px top 170px",
    "characterSize": "154px auto"
  },
  "effects": {
    "backgroundOverlay": 0.82,
    "heroOverlay": 0.58,
    "characterOpacity": 1,
    "panelOpacity": 0.94
  },
  "decoration": {
    "mode": "auto",
    "style": "mint-bloom",
    "source": "hero-full",
    "variant": "full-image-card"
  },
  "colors": {
    "background": "#071318",
    "panel": "#0B2025",
    "panelAlt": "#102B30",
    "accent": "#58E6C2",
    "accentAlt": "#8BF3D8",
    "secondary": "#2F96A3",
    "highlight": "#F2B866",
    "text": "#E8F7F3",
    "muted": "#91AAA5",
    "line": "rgba(88, 230, 194, .22)"
  }
}
```

## 字段说明

### 基本信息

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `schemaVersion` | number | 当前值为 2 |
| `id` | string | 主题内部标识 |
| `style` | string | 视觉风格标识，用于记录自动或手动选择的综合色调 |
| `appearance` | string | 界面明暗模式，可用值为 `light` 或 `dark` |
| `name` | string | 界面中展示的主题名称 |
| `eyebrow` | string | 顶部品牌副标题 |
| `tagline` | string | 主题标语 |
| `status` | string | 右下角状态文字 |

### 图片

| 字段 | 说明 |
| --- | --- |
| `images.background` | 通用背景图 |
| `images.hero` | 欢迎页主视觉图 |
| `images.character` | 可选的自定义挂件图。默认完整原图卡使用 `null`，并复用 `images.hero` |

图片支持 PNG、JPG、JPEG、WebP、GIF 和 SVG，单张图片最大 16 MB。同一个文件可以同时承担背景和主视觉角色，注入器会复用编码结果。GIF 会保持动画，建议用于挂件或局部主视觉以控制资源占用。

### 布局

| 字段 | 说明 | 示例 |
| --- | --- | --- |
| `backgroundPosition` | 背景定位 | `50% 50%` |
| `backgroundSize` | 背景尺寸 | `cover` |
| `heroPosition` | 主视觉定位 | `50% 35%` |
| `heroSize` | 主视觉尺寸 | `cover` |
| `characterPosition` | 装饰图定位 | `right 14px top 170px` |
| `characterSize` | 装饰图尺寸 | `154px auto` |

位置允许使用方向词、百分比和像素。尺寸允许使用 `cover`、`contain`、`auto`、百分比、像素和视口单位。

### 效果

| 字段 | 范围 | 说明 |
| --- | --- | --- |
| `backgroundOverlay` | 0 到 1 | 背景色覆盖强度。亮色主题用于柔化图片，暗色主题用于压低亮度 |
| `heroOverlay` | 0 到 1 | 欢迎页主视觉遮罩强度 |
| `characterOpacity` | 0 到 1 | 装饰图透明度 |
| `panelOpacity` | 0.35 到 1 | 面板不透明度 |

### 挂件

| 字段 | 说明 |
| --- | --- |
| `decoration.mode` | `auto` 自动响应窗口空间，`on` 开启，`off` 关闭 |
| `decoration.style` | 挂件所属主题风格，必须与主题 `style` 一致 |
| `decoration.source` | 素材来源，默认 `hero-full`，也可使用 `custom` 或 `none` |
| `decoration.variant` | 视觉变体，完整原图卡使用 `full-image-card` |

切换主题时会同步挂件风格。默认模式复用 `images.hero`，在风格化卡框中以 `contain` 完整显示原图。关闭模式会隐藏挂件。显式提供人物或图片挂件时，脚本会将其登记为当前主题专属素材。

### 颜色

脚本参数接受 `#RRGGBB` 格式。`line` 可以在 JSON 中使用带透明度的 CSS 颜色。

| 字段 | 用途 |
| --- | --- |
| `background` | 页面底色 |
| `panel` | 主面板颜色 |
| `panelAlt` | 次级面板颜色 |
| `accent` | 主高亮色 |
| `accentAlt` | 次高亮色 |
| `secondary` | 辅助色 |
| `highlight` | 强调色 |
| `text` | 主文字颜色 |
| `muted` | 次级文字颜色 |
| `line` | 边框和分隔线颜色 |

## 兼容 Schema 1

旧主题的单个 `image` 字段会自动映射到 `images.background` 和 `images.hero`。转换时会补齐默认布局和效果字段。保存后使用 Schema 2。

## 使用脚本创建主题

推荐通过脚本创建，因为脚本会校验图片格式、文件大小、颜色、布局和透明度，并复制所有资源到活动主题目录。

传入图片且未指定 `Style` 时，脚本会采样图片综合色相与明度，自动选择 `pink-dream`、`mint-bloom`、`sunlit-campus`、`gilded-night` 或 `deep-sea` 色板，并同步决定明暗模式。使用 `-AnalyzeOnly` 可以只查看判断结果。使用 `-Style Current` 可以仅更换图片并保留当前配色。

```powershell
.\scripts\customize-workbuddy-theme.ps1 `
  -BackgroundImagePath "D:\Pictures\background.jpg" `
  -HeroImagePath "D:\Pictures\hero.jpg" `
  -CharacterImagePath "D:\Pictures\card.png" `
  -Name "新主题" `
  -Accent "#A9E84E" `
  -BackgroundOverlay 0.78 `
  -HeroOverlay 0.58 `
  -PanelOpacity 0.94 `
  -SavePreset "new-theme"
```

清除人物装饰图：

```powershell
.\scripts\customize-workbuddy-theme.ps1 -ClearCharacter -SavePreset "no-character"
```

恢复内置主题：

```powershell
.\scripts\customize-workbuddy-theme.ps1 -Reset
```

## 手工制作主题的注意事项

1. `theme.json` 必须保存为 UTF 8，建议不带 BOM。
2. 图片路径必须相对于主题目录。
3. 图片文件必须与配置一起复制。
4. 装饰图尽量使用透明 PNG 或 SVG。
5. 人物主体不要靠近输入区和主要按钮。
6. 背景图片较亮时优先选择明亮风格色板，再微调遮罩强度，确保正文和输入控件可读。
7. 完成后运行通用验证和三个首页场景审计。
