需求简述：
这是Windows上的一款效率工具叫做Quicker，你可以搜索网络信息先了解一下。使用这款软件，按鼠标滚轮，会弹出一个面板，面板里面有一些快捷指令或者应用的启动图标。面板分为上下两层，上层的是常用命令和程序。下方的是当前程序的快捷指令。

但是这个应用没有Mac版本，所以我想开发一款Mac版本的Quicker，但是我不想做的和它这个这么复杂，只需要能在面板里面添加应用启动图标可以快速启动应用还有添加网站图标，能快速打开网站就可以。


核心功能：
  1. 通过某种快捷方式（比如鼠标中键或快捷键）呼出一个悬浮面板
  2. 面板里有图标，点击可以快速启动应用程序
  3. 面板里有网站图标，点击可以快速打开网站

  需要你确认的问题

  1. 触发方式

  Mac上鼠标中键支持不太好，你希望用什么方式呼出面板？
  - 全局快捷键（比如 Cmd+Shift+Space）
  - 鼠标手势
  - 菜单栏图标点击
  - 其他？

  2. 面板布局

  - Quicker有上下两层（常用命令 + 当前程序快捷指令），你提到只需要应用和网站启动，是否需要这种分层？
  - 还是说只需要一个单层面板，放所有的启动图标？
  - 图标排列方式：网格布局？每行几个？

  3. 面板显示位置

  - 跟随鼠标位置显示
  - 屏幕中央固定位置
  - 可以拖动/记住上次位置

  4. 配置方式

  如何添加/删除/编辑面板中的图标？
  - 在面板上直接右键编辑
  - 单独的设置界面
  - 拖拽应用/网站到面板

  5. 应用启动功能

  - 需要显示最近使用的应用吗？
  - 需要应用搜索功能吗？
  - 还是纯手动添加固定的应用列表？

  6. 网站打开功能

  - 用系统默认浏览器打开
  - 可以指定特定浏览器吗？
  - 网站图标是自动获取favicon还是手动上传？

  7. 视觉效果

  - 需要什么风格？（毛玻璃/深色/浅色/跟随系统）
  - 动画效果要求？

  请回答这些问题，我会根据你的回答整理出详细的技术方案。

  ---
  Sources:
  - https://blog.csdn.net/qq_43210428/article/details/120733711
  - https://getquicker.net/
  - https://utgd.net/article/20314/
  - https://sspai.com/post/55771

> 需要使用鼠标中键滚轮触发面板的显示；面板分为两层，上层为常用功能下层为当前
应用的快捷功能；面板的显示在鼠标指针的位置；面包需要支持搜索功能；图标可以右
键进行设置；打开网页的方式可以指定用某个浏览器打开；显示效果跟随系统；

---

## 📦 MVP 开发完成状态

### ✅ 已实现的功能

1. **鼠标中键触发** - 点击鼠标中键呼出面板
2. **悬浮面板** - 面板跟随鼠标位置显示，自动避开屏幕边缘
3. **3x4 网格布局** - 上层显示12个应用图标
4. **应用启动** - 点击图标启动对应的应用程序
5. **毛玻璃效果** - 面板使用 ultraThinMaterial 效果，跟随系统外观
6. **自动隐藏** - 点击面板外区域自动隐藏
7. **权限管理** - 首次启动引导用户开启辅助功能权限

### 🏗️ 项目结构

```
Quick Panel/Quick Panel/
├── Quick_PanelApp.swift          # 应用入口
├── AppDelegate.swift             # 应用生命周期管理
├── PermissionManager.swift       # 权限管理（辅助功能）
├── MouseEventMonitor.swift       # 鼠标中键监听
├── PanelWindowManager.swift      # 面板窗口管理
├── PanelView.swift               # 面板视图（3x4网格）
├── AppLauncher.swift             # 应用启动服务
└── Quick_Panel.entitlements      # 应用权限配置
```

### 🚀 如何使用

#### 方法 1：使用脚本运行（推荐）

```bash
cd "/Users/benxin/Code/Quick Panel"
./run_app.sh
```

这个脚本会：
1. 构建应用
2. 直接运行编译后的 .app 文件（不通过 Xcode）
3. 这样权限设置会更可靠

#### 方法 2：手动构建和运行

```bash
# 1. 构建
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" -configuration Debug build

# 2. 运行
open ~/Library/Developer/Xcode/DerivedData/Quick_Panel-*/Build/Products/Debug/Quick\ Panel.app
```

#### 方法 3：在 Xcode 中运行

⚠️ **注意**：通过 Xcode 调试运行时，需要在系统设置中授权给 **Xcode**，而不是 Quick Panel。

1. 在 Xcode 中打开项目
2. 按 Cmd+R 运行
3. 在"辅助功能"设置中找到并勾选 **Xcode**
4. 重启 Xcode

#### 3. 授予权限

首次运行时，应用会提示需要辅助功能权限：

**使用脚本或直接运行 .app 的情况：**
- 在"隐私与安全性" > "辅助功能"中找到"Quick Panel"
- 勾选启用

**通过 Xcode 调试运行的情况：**
- 在"辅助功能"中找到并勾选 **Xcode**（不是 Quick Panel）
- 重启 Xcode 和应用

#### 4. 使用面板

- **呼出面板**：点击鼠标中键（滚轮按下）
- **启动应用**：点击面板上的图标
- **隐藏面板**：点击面板外的任意位置，或再次点击鼠标中键

#### 5. 查看日志（调试用）

如果遇到问题，可以查看应用日志：
```bash
log stream --predicate 'process == "Quick Panel"' --level debug
```

### 📝 配置说明

#### 首次使用
应用首次启动时面板为空，需要用户手动添加应用或网站：
1. 点击面板中的"+"按钮
2. 选择类型：应用程序或网站
3. 填写信息并添加

#### 清除配置
如果需要清除所有配置重新开始：
```bash
cd "/Users/benxin/Code/Quick Panel"
./clear_config.sh
```

配置文件位置：`~/Library/Application Support/Quick Panel/config.json`

### 🎯 下一步开发计划

#### 阶段2 - 上层功能完善 ✅ 已完成
- [x] 数据持久化（JSON配置文件）
- [x] 右键菜单（编辑/删除图标）
- [x] 添加应用的弹窗界面
- [x] 网站打开功能
- [x] 网站 favicon 获取
- [ ] 自定义图标上传（待实现）

#### 阶段3 - 下层上下文功能
- [ ] 检测当前活跃应用
- [ ] 下层4x4网格显示
- [ ] 预设常用应用快捷功能（Chrome、Finder、VSCode等）

#### 阶段4 - 搜索和设置
- [ ] 搜索框实现
- [ ] 设置界面（调整行列数）
- [ ] 指定浏览器功能
- [ ] 导入/导出配置

#### 阶段5 - 优化打磨
- [ ] 性能优化
- [ ] 动画效果
- [ ] 键盘导航
- [ ] 用户帮助文档

### 📌 已知问题与解决方案

1. **应用图标显示**：当前使用 SF Symbols 图标，后续需要实现获取真实应用图标
2. **应用路径**：硬编码的应用路径可能在某些系统上不存在

### 🔧 权限问题说明

应用实现了**双重事件监听机制**，无需手动授权即可使用：

1. **主方法（CGEvent）**：需要辅助功能权限，更可靠
2. **备用方法（NSEvent）**：✅ **不需要权限**，在主方法失败时自动启用

#### 当前行为：

- ✅ **应用启动后立即可用**，无需授权
- 🔄 自动尝试使用 CGEvent，失败则切换到 NSEvent
- 📝 控制台会显示使用的方法：
  - `✅ Using CGEvent monitor (permission granted)` - 主方法
  - `✅ NSEvent monitor started (backup method)` - 备用方法
- 🚫 **不会弹出阻塞性的权限提示对话框**

#### 可选：授权辅助功能以获得更好性能

虽然不是必须的，但授权辅助功能可以获得更好的可靠性：

1. 打开"系统设置" → "隐私与安全性" → "辅助功能"
2. 勾选 **Xcode**（调试时）或 **Quick Panel**（独立运行时）
3. 重启应用

### 💡 技术要点

- 使用 `CGEvent` API 监听全局鼠标事件
- 使用 `NSWindow` 配置浮动面板
- 使用 SwiftUI 构建现代化 UI
- 使用 `NSWorkspace` 启动应用程序

⏺ 好的！需求已经很清晰了。让我为你梳理一份完整的技术方案。

  Quick Panel - Mac 版技术方案

  一、功能需求总结

  1.1 核心功能

  - 触发方式：鼠标中键滚轮点击触发面板显示/隐藏
  - 面板布局：双层结构
    - 上层：用户自定义的常用应用/网站
    - 下层：当前活跃应用的快捷功能（上下文相关）
  - 面板显示：跟随鼠标指针位置显示
  - 搜索功能：面板内快速搜索应用和网站
  - 配置管理：右键图标进行编辑/删除/设置
  - 网站打开：支持指定浏览器打开网站
  - 视觉效果：跟随系统外观（浅色/深色模式）

  ---
  二、技术架构设计

  2.1 技术栈选择

  - 开发语言：Swift
  - UI框架：SwiftUI
  - 系统要求：macOS 14.0+ （考虑向下兼容性可以降低版本）
  - 权限需求：
    - 辅助功能权限（监听鼠标事件）
    - 自动化权限（启动应用、获取前台应用信息）

  2.2 系统架构

  ┌─────────────────────────────────────────┐
  │         Global Event Monitor            │  ← 监听鼠标中键事件
  └──────────────────┬──────────────────────┘
                     │
                     ↓
  ┌─────────────────────────────────────────┐
  │         Panel Window Manager            │  ← 管理面板显示/隐藏
  └──────────────────┬──────────────────────┘
                     │
                     ↓
  ┌─────────────────────────────────────────┐
  │           Panel View (SwiftUI)          │
  │  ┌───────────────────────────────────┐  │
  │  │     Search Bar                     │  │  ← 搜索框
  │  ├───────────────────────────────────┤  │
  │  │  Upper Layer (常用功能)           │  │  ← 上层网格
  │  │  [App1] [App2] [Web1] [Web2] ...  │  │
  │  ├───────────────────────────────────┤  │
  │  │  Lower Layer (当前应用快捷功能)    │  │  ← 下层网格
  │  │  [Action1] [Action2] ...          │  │
  │  └───────────────────────────────────┘  │
  └──────────────────┬──────────────────────┘
                     │
          ┌──────────┼──────────┐
          ↓          ↓          ↓
     ┌────────┐ ┌────────┐ ┌────────┐
     │Data    │ │App     │ │Context │
     │Manager │ │Launcher│ │Detector│
     └────────┘ └────────┘ └────────┘

  ---
  三、核心模块设计

  3.1 全局事件监听模块 (Global Event Monitor)

  功能：
  - 监听鼠标中键点击事件
  - 获取鼠标当前位置坐标

  技术实现：
  - 使用 CGEvent API 监听全局鼠标事件
  - 需要辅助功能权限 (Accessibility Permission)
  - 监听 kCGEventOtherMouseDown 事件（button 2 = 中键）

  难点：
  - macOS 对全局事件监听有严格的权限控制
  - 需要引导用户开启辅助功能权限

  ---
  3.2 面板窗口管理模块 (Panel Window Manager)

  功能：
  - 创建和管理悬浮窗口
  - 控制窗口显示/隐藏
  - 设置窗口位置（跟随鼠标）
  - 窗口失焦自动隐藏

  技术实现：
  - 使用 NSWindow 创建无边框浮动窗口
  - 窗口级别设置为 .floating 或 .popUpMenu
  - 窗口样式：
  .borderless
  .nonactivatingPanel (不抢夺焦点)
  .hudWindow (或自定义透明背景)

  关键属性：
  - level = .floating - 保持在最上层
  - collectionBehavior = .canJoinAllSpaces - 在所有桌面空间显示
  - isMovableByWindowBackground = false - 禁止拖动
  - backgroundColor = .clear - 透明背景

  ---
  3.3 面板视图模块 (Panel View)

  功能：
  - 双层网格布局
  - 图标显示（应用图标/网站favicon）
  - 搜索框
  - 右键菜单（编辑/删除）

  UI 组件：
  1. 搜索栏 (SearchBar)
    - 实时搜索过滤
    - 支持拼音首字母搜索
  2. 上层网格 (Upper Grid)
    - 固定用户配置的常用项
    - LazyVGrid 布局，每行 4-6 个图标
  3. 下层网格 (Lower Grid)
    - 动态显示当前应用的快捷功能
    - 根据前台应用动态变化
  4. 图标项 (IconButton)
    - 显示图标和名称
    - 左键点击：执行操作
    - 右键点击：显示上下文菜单

  视觉设计：
  - 使用 .background(.ultraThinMaterial) 毛玻璃效果
  - 圆角设计
  - 跟随系统外观 .preferredColorScheme(.none)
  - 添加阴影提升层次感

  ---
  3.4 数据管理模块 (Data Manager)

  功能：
  - 存储用户配置的应用和网站
  - 存储每个应用的快捷功能配置
  - 导入/导出配置

  数据模型：
  Item (应用/网站项)
  ├── id: UUID
  ├── name: String (显示名称)
  ├── type: ItemType (.app / .website)
  ├── path: String (应用路径 或 网站URL)
  ├── iconData: Data? (自定义图标)
  ├── browserPath: String? (指定浏览器路径，仅网站)
  └── order: Int (排序)

  ContextAction (上下文快捷功能)
  ├── id: UUID
  ├── appBundleIdentifier: String (关联的应用)
  ├── name: String
  ├── actionType: ActionType (.shortcut / .applescript / .url)
  └── actionData: String (快捷键组合 或 脚本内容)

  存储方案：
  - 使用 UserDefaults 或 JSON 文件存储配置
  - 使用 FileManager 管理自定义图标
  - 存储路径：~/Library/Application Support/Quick Panel/

  ---
  3.5 应用启动模块 (App Launcher)

  功能：
  - 启动 macOS 应用
  - 打开网站（指定浏览器）
  - 执行快捷键
  - 执行 AppleScript

  技术实现：
  1. 启动应用：
    - NSWorkspace.shared.openApplication(at: url)
  2. 打开网站：
    - 默认浏览器：NSWorkspace.shared.open(url)
    - 指定浏览器：NSWorkspace.shared.open(urls, withApplicationAt: browserURL)
  3. 执行快捷键：
    - 使用 CGEvent 模拟按键
  4. 执行 AppleScript：
    - NSAppleScript 执行脚本

  ---
  3.6 上下文检测模块 (Context Detector)

  功能：
  - 检测当前活跃的应用
  - 根据应用加载对应的快捷功能

  技术实现：
  - 使用 NSWorkspace.shared.frontmostApplication
  - 监听 NSWorkspace.didActivateApplicationNotification
  - 获取 bundleIdentifier 匹配快捷功能

  ---
  3.7 图标获取模块 (Icon Fetcher)

  功能：
  - 获取应用图标
  - 获取网站 favicon
  - 支持自定义图标

  技术实现：
  1. 应用图标：
    - NSWorkspace.shared.icon(forFile: appPath)
  2. 网站 Favicon：
    - 方案1：通过 URL 获取 https://domain.com/favicon.ico
    - 方案2：使用 Google Favicon API: https://www.google.com/s2/favicons?domain=xxx&sz=128
    - 方案3：解析网页 HTML 的 <link rel="icon"> 标签
  3. 自定义图标：
    - 用户上传 PNG/ICNS 文件
    - 存储到本地并记录路径

  ---
  四、实现难点和解决方案

  4.1 鼠标中键监听权限问题

  难点：macOS 对全局事件监听有严格限制

  解决方案：
  1. 首次启动时引导用户开启辅助功能权限
  2. 使用 AXIsProcessTrusted() 检测权限状态
  3. 提供跳转到系统设置的按钮
  4. 备用方案：提供全局快捷键作为替代触发方式

  4.2 窗口显示在鼠标位置

  难点：窗口需要精确跟随鼠标且不遮挡鼠标

  解决方案：
  1. 获取鼠标坐标：NSEvent.mouseLocation
  2. 计算窗口位置，避免超出屏幕边界
  3. 窗口偏移鼠标位置（如右下偏移10pt）

  4.3 上下文感知功能

  难点：不同应用有不同的快捷功能需求

  解决方案：
  1. 预设常用应用的快捷功能（如：Chrome、Finder、VSCode）
  2. 允许用户自定义任意应用的快捷功能
  3. 使用配置文件管理映射关系

  4.4 搜索功能实现

  难点：快速搜索大量图标

  解决方案：
  1. 实时过滤：监听搜索框输入
  2. 支持拼音首字母搜索（可选，增加复杂度）
  3. 高亮匹配结果

  ---
  五、开发阶段规划

  第一阶段：基础框架 (MVP)

  - 项目搭建和权限申请
  - 全局鼠标事件监听
  - 创建悬浮窗口和基本 UI
  - 面板显示/隐藏逻辑

  第二阶段：核心功能

  - 数据模型设计和持久化
  - 上层网格：添加/显示/点击应用和网站
  - 应用启动功能
  - 网站打开功能（默认浏览器）
  - 图标获取（应用图标 + favicon）

  第三阶段：配置管理

  - 右键菜单：编辑/删除
  - 添加项的设置界面
  - 指定浏览器功能
  - 自定义图标上传

  第四阶段：上下文功能

  - 检测当前活跃应用
  - 下层网格：显示上下文快捷功能
  - 预设常用应用的快捷功能
  - 用户自定义快捷功能

  第五阶段：搜索和优化

  - 搜索框实现
  - 搜索过滤逻辑
  - 性能优化
  - 动画和视觉优化

  第六阶段：打磨和发布

  - Bug 修复
  - 用户体验优化
  - 文档和帮助
  - 打包发布

  ---
  六、技术风险评估

  | 风险项                 | 影响 | 概率 | 解决方案                       |
  |------------------------|------|------|--------------------------------|
  | 辅助功能权限被用户拒绝 | 高   | 中   | 提供备用快捷键触发方式         |
  | 某些应用无法获取图标   | 低   | 低   | 提供默认图标和自定义上传       |
  | 网站 favicon 获取失败  | 低   | 中   | 提供默认图标，支持多种获取方式 |
  | 窗口被其他应用遮挡     | 中   | 低   | 设置合适的窗口层级             |
  | 上下文检测不准确       | 中   | 低   | 提供手动配置选项               |

  ---
  七、未来扩展可能

  如果后续需要扩展功能，可以考虑：
  - 支持文件/文件夹快速访问
  - 支持系统命令（如截图、锁屏）
  - 支持 Workflow/自动化脚本
  - 云端配置同步
  - 多面板支持（分类管理）
  - 快捷指令市场（分享和下载）

  ---
  下一步行动

  这份技术方案基本涵盖了所有核心功能。在开始开发前，还有几个问题：

  1. 上层网格的布局：你希望每行显示几个图标？大概支持多少个常用项？
  2. 下层上下文功能的范围：初期是否只做几个常用应用（如Chrome、Finder），还是一开始就做通用配置？
  3. 开发优先级：是否按照我上面的阶段规划，先做MVP验证体验，再逐步添加功能？

  如果你对这份技术方案没有疑问，我们就可以开始进入开发阶段了！

> 设置一个默认的上层3 行 4 列，下层 4 行 4 列，可以自定义调整；初期只需要做
几个常用应用配置就可以；先实现最小mvp然后逐步扩展

⏺ 完美！需求已经非常明确了。让我更新一下技术方案，并明确 MVP 的范围。

  Quick Panel - 更新后的技术方案

  一、布局规格确定

  1.1 默认布局

  - 上层（常用功能区）：3行 × 4列 = 12个图标位
  - 下层（上下文功能区）：4行 × 4列 = 16个图标位
  - 图标尺寸：建议 48x48 pt（适配 Retina 屏幕）
  - 间距：图标间距 8-12 pt
  - 面板总尺寸：约 240x450 pt（可根据实际调整）

  1.2 自定义布局

  - 设置界面允许调整行列数
  - 行数范围：1-6 行
  - 列数范围：2-8 列
  - 实时预览调整效果

  ---
  二、MVP 开发范围明确

  阶段1️⃣ - 最小 MVP（核心验证）

  目标：验证核心交互流程和技术可行性

  包含功能：
  1. ✅ 鼠标中键监听和权限申请
  2. ✅ 悬浮面板显示/隐藏（跟随鼠标位置）
  3. ✅ 上层网格显示（3x4布局）
  4. ✅ 硬编码几个测试应用图标
  5. ✅ 点击启动应用功能
  6. ✅ 基本的视觉样式（毛玻璃、圆角）
  7. ✅ 点击面板外区域自动隐藏

  不包含：
  - ❌ 数据持久化
  - ❌ 添加/编辑/删除功能
  - ❌ 下层上下文功能
  - ❌ 搜索功能
  - ❌ 网站打开功能

  验证点：
  - 鼠标中键能否稳定触发
  - 面板位置是否准确跟随鼠标
  - 应用启动是否可靠
  - 整体交互是否流畅

  ---
  阶段2️⃣ - 上层功能完善

  新增功能：
  1. ✅ 数据模型设计（Item 模型）
  2. ✅ JSON 配置文件存储
  3. ✅ 应用图标自动获取
  4. ✅ 右键菜单：删除、编辑
  5. ✅ 添加应用的弹窗界面
  6. ✅ 网站打开功能（默认浏览器）
  7. ✅ 网站 favicon 获取
  8. ✅ 拖拽排序（可选）

  目标：上层功能区完全可用

  ---
  阶段3️⃣ - 下层上下文功能

  新增功能：
  1. ✅ 检测当前活跃应用
  2. ✅ 下层网格显示（4x4布局）
  3. ✅ 预设常用应用配置：
    - Chrome/Safari：新建标签页、新建隐私窗口、关闭标签页、重新打开标签
    - Finder：新建窗口、新建文件夹、显示/隐藏隐藏文件、前往下载
    - Visual Studio Code：新建文件、保存、格式化、命令面板
    - 其他：根据需要添加 2-3 个常用应用

  目标：下层动态显示当前应用的快捷功能

  ---
  阶段4️⃣ - 搜索和设置

  新增功能：
  1. ✅ 搜索框 UI
  2. ✅ 实时搜索过滤
  3. ✅ 设置界面：
    - 调整上层/下层行列数
    - 自定义图标尺寸
    - 触发方式设置（预留）
  4. ✅ 指定浏览器功能
  5. ✅ 导入/导出配置

  目标：完整的用户配置能力

  ---
  阶段5️⃣ - 优化和打磨

  优化项：
  1. ✅ 性能优化（图标加载、缓存）
  2. ✅ 动画优化（淡入淡出、缩放效果）
  3. ✅ 键盘导航（方向键、Enter、Esc）
  4. ✅ 错误处理和提示
  5. ✅ 自定义图标上传
  6. ✅ 用户引导和帮助文档

  ---
  三、预设应用配置方案

  3.1 配置数据结构

  预设配置文件：presets.json

  {
    "presets": [
      {
        "appBundleIdentifier": "com.google.Chrome",
        "appName": "Google Chrome",
        "actions": [
          {
            "name": "新建标签页",
            "icon": "plus.square",
            "shortcut": "Cmd+T"
          },
          {
            "name": "隐私窗口",
            "icon": "eye.slash",
            "shortcut": "Cmd+Shift+N"
          },
          {
            "name": "关闭标签",
            "icon": "xmark",
            "shortcut": "Cmd+W"
          },
          {
            "name": "重新打开",
            "icon": "arrow.counterclockwise",
            "shortcut": "Cmd+Shift+T"
          }
        ]
      },
      {
        "appBundleIdentifier": "com.apple.finder",
        "appName": "Finder",
        "actions": [
          {
            "name": "新建窗口",
            "icon": "plus.rectangle",
            "shortcut": "Cmd+N"
          },
          {
            "name": "新建文件夹",
            "icon": "folder.badge.plus",
            "shortcut": "Cmd+Shift+N"
          },
          {
            "name": "显示隐藏文件",
            "icon": "eye",
            "shortcut": "Cmd+Shift+."
          },
          {
            "name": "前往下载",
            "icon": "arrow.down.doc",
            "url": "file:///Users/Shared/Downloads"
          }
        ]
      }
    ]
  }

  3.2 初期支持的应用列表

  1. Chrome - 浏览器常用操作
  2. Safari - 浏览器常用操作
  3. Finder - 文件管理操作
  4. Visual Studio Code - 代码编辑操作
  5. 备用 - 根据开发过程中的测试需要选择 1-2 个

  ---
  四、开发技术要点

  4.1 MVP 阶段关键代码模块

  1. 应用入口 (Quick_PanelApp.swift)
    - 启动后台服务
    - 隐藏默认窗口
    - 保持应用运行
  2. 鼠标监听服务 (MouseEventMonitor.swift)
    - 全局事件监听
    - 中键点击检测
    - 鼠标位置获取
  3. 面板窗口 (PanelWindow.swift)
    - NSWindow 自定义配置
    - 窗口级别和行为
    - 显示/隐藏逻辑
  4. 面板视图 (PanelView.swift)
    - SwiftUI 网格布局
    - 图标显示组件
    - 点击事件处理
  5. 应用启动器 (AppLauncher.swift)
    - 应用路径解析
    - 启动应用功能
    - 错误处理

  ---
  五、项目文件结构

  Quick Panel/
  ├── Quick_PanelApp.swift          # 应用入口
  ├── AppDelegate.swift             # 应用代理（管理生命周期）
  ├── Models/                       # 数据模型
  │   ├── Item.swift               # 图标项模型
  │   ├── ContextAction.swift      # 上下文操作模型
  │   └── AppPreset.swift          # 预设配置模型
  ├── Views/                        # 视图
  │   ├── PanelView.swift          # 主面板视图
  │   ├── UpperGridView.swift      # 上层网格
  │   ├── LowerGridView.swift      # 下层网格
  │   ├── IconButton.swift         # 图标按钮组件
  │   ├── SearchBar.swift          # 搜索框
  │   └── SettingsView.swift       # 设置界面
  ├── Services/                     # 服务层
  │   ├── MouseEventMonitor.swift  # 鼠标监听
  │   ├── PanelWindowManager.swift # 窗口管理
  │   ├── DataManager.swift        # 数据管理
  │   ├── AppLauncher.swift        # 应用启动
  │   ├── ContextDetector.swift    # 上下文检测
  │   └── IconFetcher.swift        # 图标获取
  ├── Utilities/                    # 工具类
  │   ├── PermissionManager.swift  # 权限管理
  │   └── Constants.swift          # 常量定义
  ├── Resources/                    # 资源文件
  │   ├── presets.json             # 预设配置
  │   └── DefaultIcons/            # 默认图标
  └── Assets.xcassets/             # 资源目录

  ---
  六、开发时间预估（仅供参考）

  - 阶段 1 (MVP)：2-3 天
  - 阶段 2 (上层完善)：2-3 天
  - 阶段 3 (下层上下文)：2-3 天
  - 阶段 4 (搜索设置)：1-2 天
  - 阶段 5 (优化打磨)：1-2 天

  总计：约 1-2 周可完成基本功能

  ---
  七、MVP 验收标准

  MVP 完成后，需要验证以下功能：

  - 应用启动后常驻后台，菜单栏有图标
  - 鼠标中键点击能够触发面板显示
  - 面板显示在鼠标指针附近，不超出屏幕边界
  - 面板显示 3x4 网格，有 12 个图标位
  - 硬编码的测试应用图标显示正常
  - 点击图标能够成功启动对应的应用
  - 点击面板外区域，面板自动隐藏
  - 再次点击中键，面板重新显示
  - 面板跟随系统外观（浅色/深色模式）

  ---
  技术方案总结

  ✅ 明确的需求边界：
  - 上层 3x4，下层 4x4，可自定义
  - 初期只做几个常用应用的预设配置
  - 采用渐进式开发，先 MVP 后扩展

  ✅ 清晰的开发路径：
  - 5 个阶段，每个阶段目标明确
  - MVP 专注核心交互验证
  - 后续阶段逐步完善功能

  ✅ 可行的技术方案：
  - SwiftUI + AppKit 混合开发
  - 清晰的模块划分
  - 预设配置文件管理常用应用

  ---
