# Quick Panel

Quick Panel 是一个 macOS 快捷面板工具，定位为精简版 Quicker。应用常驻后台，通过鼠标中键或可选的全局快捷键呼出悬浮面板，在鼠标附近快速启动应用或打开网站。

当前代码版本以双层面板为核心：
- 上层是“常用功能”
- 下层是“按当前前台应用分组的项目”
- 两层都支持分页、分组命名、拖拽换位和右键编辑

本文档已按当前代码状态更新，主要以源码实现为准，而不是历史开发记录。

版本管理与发布规范见：[docs/release.md](/Users/benxin/Code/Quick%20Panel/docs/release.md)

更新记录见：[CHANGELOG.md](/Users/benxin/Code/Quick%20Panel/CHANGELOG.md)

## 当前版本

- App 版本：`1.2.7`
- Build：`10`
- Bundle ID：`com.benxin.Quick-Panel`
- 部署目标：`macOS 26.2+`
- 技术栈：`SwiftUI + AppKit`
- 依赖情况：无第三方依赖，无 SPM / CocoaPods / Carthage
- 测试情况：当前没有测试 target，仅支持手动验证

## 版本管理

- 对外版本号使用 `MARKETING_VERSION`
- 构建号使用 `CURRENT_PROJECT_VERSION`
- 当前项目实际配置位于 `Quick Panel/Quick Panel.xcodeproj/project.pbxproj`
- 设置页、关于页、更新检查均从 `CFBundleShortVersionString` / `CFBundleVersion` 读取
- 正式发布建议创建 Git Tag，格式为 `v<MARKETING_VERSION>`

## 当前已实现功能

### 呼出与窗口

- 鼠标中键呼出/隐藏面板
- 可选全局快捷键呼出/隐藏面板
- 菜单栏图标常驻，可打开设置、显示/隐藏面板、查看关于页、退出应用
- 面板显示在鼠标附近，并做边缘避让
- 面板点击外部区域自动隐藏
- 面板顶部可拖动
- 单实例运行，重复启动时会主动退出后启动的实例

### 面板交互

- 上下双层网格布局
- 每层独立分页
- 支持滚轮翻页
- 空白卡槽点击可直接添加项目
- 已添加项目支持右键编辑/删除
- 同层内拖拽交换顺序
- 每页可新建、删除页面
- 每页支持自定义分组名称，双击页标题可编辑

### 项目类型

- 应用项目：启动本地 `.app`
- 网站项目：使用默认浏览器打开网址
- 网站图标支持自动抓取 favicon
- 应用和网站都支持手动选择自定义图标
- 下层项目可绑定到某个前台应用的 `bundle identifier`

### 设置与系统能力

- 网格设置：上下层列数、行数、项目间距
- 外观设置：面板透明度
- 管理页面：集中查看和删除项目
- 高级设置：全局快捷键、开机自启动、辅助功能权限状态、恢复默认设置、检查更新
- 关于窗口：显示版本信息并提供检查更新入口
- 自动更新检查：启动 5 秒后静默检查 Gitee 最新 Release

## 当前未接入或半完成能力

以下内容在代码中存在痕迹，但当前产品流里没有完整接通，文档按“现状”说明：

- 搜索功能：未实现
- 指定浏览器打开网站：`PanelItem.browserPath` 和 `AppLauncher.openWebsite` 已支持，但添加/编辑界面目前没有浏览器选择 UI，正常使用下仍走系统默认浏览器
- 预设上下文动作：`ContextAction`、`PresetConfiguration`、`ShortcutExecutor` 已存在，但主面板当前展示的是“用户手动配置的下层项目”，不是这些预设动作
- 权限引导弹窗：启动时如果缺少辅助功能权限且已退回备用监听方案，会主动弹出引导；设置页“高级”也可查看权限状态并打开系统设置
- `NewPanelView`：保留了旧版/实验性面板实现，当前实际使用的是 `PanelView`
- `ContentView`：默认模板残留，未参与实际功能

## 运行与开发

### 构建

```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" -configuration Debug build
```

### 构建并运行

```bash
./run_app.sh
```

`run_app.sh` 会：
- 构建 Debug 版本
- 查找 DerivedData 中的 `Quick Panel.app`
- 杀掉现有的 `Quick Panel` 进程
- 直接启动构建产物

### 清理

```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" clean
```

### 查看日志

```bash
log stream --predicate 'process == "Quick Panel"' --level debug
```

## 权限说明

### 鼠标中键监听

应用优先使用 `CGEvent.tapCreate` 监听全局鼠标中键，这通常依赖辅助功能权限。

如果没有权限：
- `CGEvent` 监听可能失败
- 应用会自动退回 `NSEvent.addGlobalMonitorForEvents`
- 退回方案可用，但稳定性和覆盖范围可能不如前者

### 调试运行与直接运行

如果通过 Xcode 调试运行，系统里通常需要授权给 `Xcode`。

如果直接运行打包后的 `Quick Panel.app`，系统里通常需要授权给 `Quick Panel` 本身。

## 使用方式

### 呼出面板

- 点击鼠标中键
- 或在设置中启用全局快捷键
- 或通过菜单栏菜单中的“显示/隐藏面板”

### 添加项目

可以通过以下入口添加：
- 面板中的空白卡槽
- 设置页“管理”标签中的“添加”按钮

添加时支持：
- 选择上层或下层
- 选择应用程序或网站
- 为网站自动拉取图标
- 为任意项目选择本地图标
- 在下层将项目绑定到当前应用

### 编辑项目

- 在面板项目上右键
- 选择“编辑”或“删除”

## 数据存储

数据保存在：

```text
~/Library/Application Support/Quick Panel/
```

当前使用的文件有：

- `config.json`：项目列表
- `settings.json`：应用设置
- `groups.json`：页面分组名称
- `pagecounts.json`：每层页数

JSON 输出格式使用：
- `prettyPrinted`
- `sortedKeys`

## 项目结构

```text
Quick Panel/
├── README.md
├── CLAUDE.md
├── AGENTS.md
├── run_app.sh
├── clear_config.sh
└── Quick Panel/
    ├── Quick Panel.xcodeproj/
    └── Quick Panel/
        ├── Quick_PanelApp.swift
        ├── AppDelegate.swift
        ├── PanelWindowManager.swift
        ├── PanelView.swift
        ├── MouseEventMonitor.swift
        ├── PermissionManager.swift
        ├── AppLauncher.swift
        ├── ContentView.swift
        ├── Models/
        │   ├── ItemType.swift
        │   ├── PanelItem.swift
        │   ├── PageGroup.swift
        │   └── ContextAction.swift
        ├── Views/
        │   ├── AddItemView.swift
        │   ├── SettingsView.swift
        │   ├── AboutView.swift
        │   └── NewPanelView.swift
        └── Services/
            ├── DataManager.swift
            ├── SettingsManager.swift
            ├── AddItemWindowManager.swift
            ├── SettingsWindowManager.swift
            ├── AboutWindowManager.swift
            ├── StatusBarManager.swift
            ├── LoginItemManager.swift
            ├── HotkeyManager.swift
            ├── UpdateManager.swift
            ├── IconFetcher.swift
            ├── ContextDetector.swift
            └── ShortcutExecutor.swift
```

## 架构摘要

### 应用入口

- `Quick_PanelApp.swift` 使用 `@NSApplicationDelegateAdaptor`
- 通过 `Settings { EmptyView() }` 避免默认主窗口出现
- 主流程由 `AppDelegate` 统一启动

### 核心单例服务

- `PanelWindowManager`：主面板窗口创建、显示、隐藏、滚轮路由、设置生效
- `DataManager`：项目、页分组、页数持久化
- `SettingsManager`：设置持久化与变更广播
- `StatusBarManager`：菜单栏图标与菜单
- `HotkeyManager`：Carbon 全局快捷键注册
- `UpdateManager`：版本检查与下载
- `LoginItemManager`：开机自启

### 视图层

- `PanelView` 是当前实际使用的主面板
- `AddItemView` / `EditItemView` 用于添加和编辑项目
- `SettingsView` 分为“网格 / 外观 / 管理 / 高级”四个标签
- `AboutView` 显示版本与更新状态

### 通信方式

- 共享状态主要通过 `ObservableObject + @Published`
- 跨模块事件使用 `NotificationCenter`
- 目前主面板依赖的通知包括：
  - `hidePanel`
  - `panelWillShow`
  - `scrollPreviousPage`
  - `scrollNextPage`

## 脚本说明

### `run_app.sh`

用于本地开发阶段的快速构建和运行。

### `clear_config.sh`

当前会删除以下文件并恢复默认状态：

- `config.json`
- `settings.json`
- `groups.json`
- `pagecounts.json`

## 已知事实

- 当前没有自动化测试
- 当前没有 Release 打包脚本
- 当前没有导入/导出配置功能
- 当前没有搜索栏
- 当前没有指定浏览器的设置入口

## 后续维护建议

如果后续继续迭代，建议优先保持以下文档同步：

- `README.md`：面向项目功能与开发说明
- `CLAUDE.md` / `AGENTS.md`：面向代码代理或协作者的仓库说明
- 版本说明：与 `MARKETING_VERSION`、`CURRENT_PROJECT_VERSION` 保持一致
