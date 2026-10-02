# 图标与宣传图最终提示词

生成方式：Codex 内置 imagegen。原始生成文件保留于默认 generated_images 目录；最终资源已复制到仓库。图标仅通过 sips 导出平台尺寸，未重新绘制。宣传图是功能示意，不是实际应用截图。

## 极简图标

```text
Use case: logo-brand
Asset type: final macOS application icon for Quick Panel, 1024x1024 PNG with transparent outside the rounded app tile.
Primary request: redesign the icon of a mouse-middle-click floating two-layer app-and-website launcher in an extremely minimal monochrome style. A single centered flat graphite-black rounded square tile, occupying approximately 82% of canvas. Inside it is one bold warm-white geometric symbol: four solid rounded rectangular cards arranged in two horizontal rows, representing a two-layer quick-launch panel. In the top row the left card is wide and right card narrow; in the bottom row the left card is narrow and right card wide. The symbol overall forms a centered compact square, with uniform generous gaps and identical corner radii. The cards are plain, without markings. Icon must be readable at 16px and 32px. Exactly two opaque solid colors, charcoal #202124 and warm white #F5F5F2; outer canvas fully transparent.
Style: Swiss geometric graphic design, simple flat vector-like raster, precise proportions, quiet utilitarian native macOS identity.
Constraints: square app icon, centered bold symbol, transparent outside app tile, no text, letters, numbers or watermark. No gradients, colored accents, multicolor, metallic effects, glossy glass, glow, shadows, strokes, border, 3D, perspective, mouse, rocket, gear, magnifying glass, browser logos or real brand trademarks. Produce one standalone icon, no contact sheet or mockup.
```

## 横版宣传图

参考图：`app-icon-source.png`，作为品牌图标参考。

```text
Use case: ads-marketing
Asset type: 1536x1024 landscape editorial launch cover for a real open-source macOS app, Quick Panel.
Input image 1: approved product identity reference; place this exact monochrome app icon small next to the brand name. Preserve its graphite tile and four white asymmetric grid cards, do not redesign it.
Primary request: minimalist product announcement, warm off-white background, exclusively graphite black and neutral gray. Premium Swiss editorial typography with generous negative space. All graphics monochrome. No colorful gradients.
Composition: top-left icon plus name, large left headline, large tall floating translucent macOS quick panel on right, a small simple white mouse below left text with its middle wheel called out. Fine black hairline callouts connect to upper and lower panel sections. Schematic interface, no invented real screenshot.
Text exactly:
"Quick Panel"
"常用入口，"
"就在鼠标旁。"
"macOS 快捷启动面板"
"中键呼出"
"上层：常用入口"
"下层：随应用切换"
"MIT 开源 · macOS 26.2+"
Tiny footer "界面示意"
Panel: clean rounded glass floating panel, narrow grab handle at top, two stacked sections and subtle divider. Upper section title "常用功能"; grid four columns x three rows, generic grayscale app/website tiles with short Chinese labels such as "浏览器", "终端", "文档", "笔记", a few empty plus slots. Lower section title "当前应用"; four columns x three rows of generic grayscale app/website tiles and empty plus slots, labels "开发文档", "代码仓库", "参考资料". Both have small pagination dots. No search bar, no AI, no command execution buttons, no fake browser chrome. Keep UI realistically sized, no distorted cards.
Constraints: final polished ready-to-post cover, legible Chinese, safe margins, flat clean graphic composition with subtle realistic glass only on panel, no shadows or 3D on logo, no third-party logos, no QR codes or metrics.
```

## 竖版宣传图

参考图：`app-icon-source.png`，作为品牌图标参考。

```text
Use case: ads-marketing
Asset type: portrait social-media launch poster, 1024x1536, for Quick Panel.
Input image 1: product brand icon reference, insert small exact graphite tile with asymmetric four white cards next to name. Do not redesign icon.
Primary request: an extremely minimal black, white and neutral gray Chinese product poster for a macOS mouse-middle-click quick launcher. Clean warm white paper background, bold black Chinese typography, no colorful elements. Editorial layout.
Composition: top quarter strong headline, middle half a small white three-button mouse on left and tall translucent native-style floating two-layer panel on right, bottom quarter concise benefit lines and MIT/system requirements. Airy margins. Fine pointer line from mouse wheel to panel. All interface symbols monochrome.
Text verbatim:
"Quick Panel"
"给 Mac 的中键，"
"一个快捷面板。"
"应用与网站，一点就开"
"上层放常用入口"
"下层随当前应用切换"
"MIT 开源"
"macOS 26.2+"
Tiny bottom footer "界面示意"
Panel schematic must show two sections titled "常用功能" and "当前应用", upper 4 columns x 3 rows, lower 4 columns x 3 rows, some dotted empty slots with plus signs, small pagination dots, grab handle on top, thin divider. Generic solid icon shapes. Only use tiles for APPLICATIONS and WEBSITES with labels "浏览器", "终端", "笔记", "邮件", "开发文档", "代码仓库", "参考网站", "社区". Do not imply files/folders, search, keyboard commands, AI or workflows. Glass panel realistically narrow, modest shadows. One physical white mouse with visibly defined center scroll wheel.
Constraints: all Chinese text exact, avoid extra unrequested text, no QR code, no URL, no brands, no saturated colors, no giant 3D decoration, no metrics. Native calm utility mood, readable on phone, one complete ready-to-post image.
```
