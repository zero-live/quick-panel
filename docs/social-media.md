# Quick Panel 社媒发布文案

以下正文可直接复制。源码链接使用 GitHub，安装包下载仍由 Gitee Releases 提供。文案以当前代码版本 1.5.0 为准。

## 配图

| 图片 | 建议用途 |
| --- | --- |
| [竖版宣传图](assets/quick-panel-social-portrait.png) | 小红书首图、即刻配图 |
| [横版宣传图](assets/quick-panel-cover.png) | X 配图、公众号正文首图、技术社区 |
| [新版图标](../design/quick-panel-minimal/app-icon-1024.png) | 项目介绍、版本更新配图 |

图片统一使用黑白石墨色。图中的面板为功能示意，已标注「界面示意」。如另外附实际界面截图，请避免展示私人网址和项目。

## 小红书

标题建议（选一）：

- 给 Mac 做了个鼠标中键面板
- 常用应用和网站，放到鼠标旁
- 我的 Mac 中键，终于有用了

正文：

最近把自己做的 Mac 小工具整理开源了，叫 Quick Panel。

它做的事情很简单：按一下鼠标中键，在光标旁边弹出一个快捷面板，点击就能打开常用应用和网站。

我比较喜欢的是它的上下两层设计：

上层放日常都会用到的入口，比如浏览器、终端和笔记。
下层可以给不同应用单独配置。比如在 Xcode 里放开发文档和代码仓库，切到浏览器后，就显示给浏览器配置的那组网站。

常用入口不用挤在同一页里，可以分页、拖拽整理，也能自己改图标。外观用了 macOS 原生液态玻璃，面板会根据屏幕大小适配。

没有中键鼠标也可以用全局快捷键。需要 macOS 26.2+，中键监听需要辅助功能权限。

项目采用 MIT 许可证。如果你也习惯用鼠标操作，欢迎试试，想听听大家会怎么安排自己的面板。

源码：https://github.com/zero-live/quick-panel
下载：https://gitee.com/zerolive/quick-panel/releases

#Mac工具 #效率工具 #开源项目 #独立开发 #macOS

配图顺序：竖版宣传图 → 自己配置好的真实面板截图 → 实际切换前台应用的截图。只有当前两张宣传素材时，先发竖版即可。

## 即刻

把最近做的 macOS 小工具整理开源了：Quick Panel。

按一下鼠标中键，常用应用和网站就在光标旁边展开。

面板分两层：上层放通用入口，下层放你为当前应用配置的入口。比如在 Xcode 里看开发文档、开代码仓库，切到浏览器后换成另一组网站。

支持分页、拖拽整理、跨页移动和原生液态玻璃，也可以用全局快捷键呼出。SwiftUI + AppKit，没有第三方依赖，MIT 许可证。

需要 macOS 26.2+，中键监听需要辅助功能权限。欢迎体验，也想听听你会放哪些入口。

源码：https://github.com/zero-live/quick-panel
下载：https://gitee.com/zerolive/quick-panel/releases

配图：竖版宣传图或横版宣传图，选一张。

## X / Twitter

中文单条：

把做的 macOS 小工具整理开源了：Quick Panel。

鼠标中键呼出，在光标旁打开应用和网站。上层放常用入口，下层显示为当前应用配置的入口。

SwiftUI + AppKit，MIT 许可证。需要 macOS 26.2+。

https://github.com/zero-live/quick-panel

英文单条：

Meet Quick Panel, my open-source macOS launcher.

Middle-click to open apps and websites near your cursor. Keep everyday links on top and configure app-specific links below.

SwiftUI + AppKit. MIT licensed. macOS 26.2+.

https://github.com/zero-live/quick-panel

可接在首条后面的补充：

Supports pagination, drag-to-reorder, custom icons, Liquid Glass, and adaptive sizing across displays. You can also use a global hotkey.

App-specific links are configured manually. Middle-click monitoring needs Accessibility permission.

Download: https://gitee.com/zerolive/quick-panel/releases

配图：横版宣传图。中英文首条各自独立发布即可，不需要同时放在一条里。

## 公众号 / 技术社区

标题：我开源了一个 macOS 中键快捷面板：Quick Panel

摘要：按下鼠标中键，在光标附近打开常用应用和网站。用上下两层面板，整理通用入口与应用专属入口。

正文：

每天使用 Mac，总有一些会重复访问的入口：一个应用、一个文档网站、一个代码仓库。它们分散在 Dock、启动器和浏览器书签里。我想给这些入口一个更顺手的位置，于是做了 Quick Panel，并把项目整理出来开源。

![Quick Panel 功能示意](assets/quick-panel-cover.png)

它的交互很直接：按下鼠标中键，面板在光标附近出现，点击项目即可打开应用或网址。也支持全局快捷键和菜单栏入口。

双层面板是这个项目的核心。上层用于常用入口，下层用于当前应用的专属入口。比如给 Xcode 配置开发文档与代码仓库，给浏览器配置常用资料网站。切换前台应用后再次呼出面板，下层会展示对应的配置。所有入口都由用户自己添加。

整理方面，上下层可以独立分页，支持滚轮翻页、分组命名、拖拽排序和跨页移动。网站标题和图标可以自动获取，也可以使用自定义图标。外观支持原生液态玻璃和系统毛玻璃材质，网格、间距、透明度可调，面板能适配触发所在屏幕的可见区域。

开发上，项目使用 SwiftUI + AppKit，没有第三方依赖。SwiftUI 负责界面，AppKit 负责非激活悬浮面板和窗口生命周期，全局中键监听优先使用 CGEvent，快捷键使用 Carbon。面板配置以本地 JSON 保存，布局和文档序列化已有单元测试。

当前版本为 1.5.0，最低支持 macOS 26.2。稳定监听中键需要辅助功能权限；没有中键鼠标可以启用全局快捷键。目前功能集中在应用与网站入口，搜索、配置导入导出和完整自动化工作流尚未提供。

如果你习惯用鼠标操作，或者正在学习 SwiftUI 与 AppKit 混合开发，欢迎看看这个项目。项目采用 MIT 许可证，欢迎反馈问题或参与改进。

源码：https://github.com/zero-live/quick-panel
安装包：https://gitee.com/zerolive/quick-panel/releases

## 附：短演示拍摄脚本

建议另录一段约 15 秒的实际操作视频：

1. 0–3 秒：在桌面按中键，面板在鼠标旁出现。
2. 3–6 秒：点击上层的一个应用或网站，展示启动结果。
3. 6–11 秒：切换两个已配置入口的前台应用，分别呼出面板，展示下层变化。
4. 11–15 秒：展示拖拽或翻页，最后停在项目名与仓库地址。

以上是拍摄建议，当前交付不包含视频。
