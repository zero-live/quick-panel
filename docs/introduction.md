# Quick Panel：把常用入口放到鼠标旁

## 一句话简介

Quick Panel 是一款 macOS 快捷启动面板：鼠标中键呼出，快速打开应用和网站，支持随当前应用切换的双层布局。

英文仓库简介：

A native macOS quick-launch panel for apps and websites. Open it with a middle click and configure context-specific shortcuts for each app.

## 项目介绍

每天在电脑上工作，总会反复做几件小事：打开应用、找一个常用网站、切到文档页。单次操作并不复杂，但这些入口往往散落在 Dock、浏览器书签和不同窗口里。

Quick Panel 想把这些常用入口收拢到鼠标附近。按下鼠标中键，一个悬浮面板就在光标附近出现，点击即可打开应用或网址。也可以启用全局快捷键，或从菜单栏打开。

![Quick Panel 双层快捷面板示意](assets/quick-panel-cover.png)

*配图为界面示意。*

面板分为上下两层。上层放你随时会用到的应用和网站；下层放为当前前台应用配置的专属入口。比如给 Xcode 配置开发文档和代码仓库，给浏览器配置常用资料网站。切换应用后，再次呼出面板，下层就会展示对应的入口。专属入口由用户手动配置，不会自动生成。

项目支持独立分页、分组命名、滚轮翻页、拖拽排序和跨页移动。添加网站时可以自动获取标题和图标，也能使用自己的图标。网格、间距、背景透明度和系统材质可调整，面板可根据笔记本或外接显示器的可见区域自动适配。

Quick Panel 使用 SwiftUI 与 AppKit 开发，没有第三方依赖，常驻菜单栏。它适合习惯用鼠标操作、希望给常用入口找到固定位置的 macOS 用户，也可以作为学习 SwiftUI 与 AppKit 混合开发、非激活悬浮面板和全局事件监听的源码案例。

当前代码版本为 1.5.0，最低支持 macOS 26.2。中键监听需要辅助功能权限；没有中键鼠标时，可启用全局快捷键。当前功能集中在应用与网站启动，搜索、配置导入导出和完整自动化工作流尚未提供。

项目采用 MIT 许可证，欢迎体验、反馈问题和参与改进。

- [源码](https://github.com/zero-live/quick-panel)
- [安装包入口](https://gitee.com/zerolive/quick-panel/releases)
- [使用与开发说明](../README.md)
