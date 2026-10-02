# Quick Panel 极简图标

采用石墨黑与暖白两种中性色。四块卡片分为上下两行，表达双层面板；错落的宽度让轮廓有辨识度。保留透明外边缘，适合 macOS 应用图标。

![新版图标](app-icon-1024.png)

- `app-icon-source.png`：内置 imagegen 生成的原始图，保留透明度。
- `app-icon-1024.png`：1024 × 1024 主文件。
- `prompts.md`：最终提示词与宣传图提示词。
- `export-app-icon.sh`：将主图按既有 Contents.json 导出为 10 个 AppIcon 文件，并更新 `logo/Quick Panel.png`。

```bash
bash design/quick-panel-minimal/export-app-icon.sh
```

现有图标资源已更新。已安装应用和此前发布的 DMG 不会自动改变，需要重新构建、打包并安装。
