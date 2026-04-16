# Quick Panel 版本管理与发布规范

本文档约定 Quick Panel 的版本号、构建号、Git Tag 和发布步骤，后续发布统一按此执行。

## 当前基线

- 对外版本号：`1.2.2`
- 构建号：`5`
- 当前发布分支：`master`
- 当前 Tag 历史：
  - `v1.2.0`
  - `v1.0.1`
  - `v1.0.0`

## 版本号规则

Quick Panel 使用两套版本信息：

### 1. 对外版本号

对应 Xcode 配置中的 `MARKETING_VERSION`，例如：

```text
1.2.0
```

它用于：

- 关于页显示
- 设置页显示
- 更新检查版本比较
- Release 标题与用户可见版本说明

建议使用语义化版本：

```text
主版本.次版本.修订版本
```

推荐规则：

- `主版本`：重大改版、核心交互变化、不兼容调整时增加
- `次版本`：新增功能、明显体验升级时增加
- `修订版本`：修复 bug、小幅优化、不改变主要能力时增加

示例：

- `1.2.0`：新增日志导出、设置页增强
- `1.2.1`：修复日志导出问题
- `1.3.0`：新增日志查看器、配置导入导出
- `2.0.0`：面板结构或交互逻辑发生明显升级

### 2. 构建号

对应 Xcode 配置中的 `CURRENT_PROJECT_VERSION`，例如：

```text
3
```

它用于区分同一对外版本下的不同构建。

规则：

- 构建号必须始终递增
- 即使 `MARKETING_VERSION` 不变，只要重新准备发布包，也要增加构建号
- 构建号不要回退

示例：

- `1.2.0 (3)`
- `1.2.0 (4)`
- `1.2.1 (5)`

## 代码中的版本来源

当前项目里的版本信息主要来自以下位置：

### Xcode 工程配置

文件：

- `Quick Panel/Quick Panel.xcodeproj/project.pbxproj`

当前字段：

- `MARKETING_VERSION = 1.2.0`
- `CURRENT_PROJECT_VERSION = 3`

### 运行时读取位置

这些界面或服务会读取版本号：

- `Quick Panel/Quick Panel/Views/AboutView.swift`
- `Quick Panel/Quick Panel/Views/SettingsView.swift`
- `Quick Panel/Quick Panel/Services/UpdateManager.swift`

它们通过以下 Info 字段读取：

- `CFBundleShortVersionString`
- `CFBundleVersion`

由于当前使用的是 Xcode 自动生成 Info.plist，所以通常只需要维护 `project.pbxproj` 中的两个版本字段。

## Git Tag 规则

每次正式发布都应创建一个 Git Tag。

Tag 格式统一为：

```text
v<MARKETING_VERSION>
```

示例：

- `v1.2.0`
- `v1.2.1`
- `v1.3.0`

约定：

- Tag 只对应正式发布版本
- 同一个 `MARKETING_VERSION` 只打一个正式 Tag
- 如果同版本需要重新打包修复，优先提升修订版本或继续增加构建号后再发布

## 推荐发布流程

每次发布建议按以下顺序执行。

### 1. 确认准备发布的内容

- 功能开发完成
- 关键问题已验证
- 工作区无无关改动

### 2. 更新版本号

根据本次发布内容：

- 需要新功能版本时，更新 `MARKETING_VERSION`
- 每次发布都递增 `CURRENT_PROJECT_VERSION`

### 3. 更新文档与说明

至少同步以下内容：

- README 中“当前版本”
- 发布说明
- 如有必要，同步更新本文件

### 4. 本地验证

执行：

```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" -scheme "Quick Panel" -configuration Debug build
```

如果需要再补一次运行验证：

```bash
./run_app.sh
```

### 5. 提交版本变更

建议单独提交一次版本发布提交，提交信息使用中文。

示例：

- `发布 1.2.1 版本`
- `发布 1.3.0 版本`

### 6. 创建 Tag

示例：

```bash
git tag v1.2.1
```

### 7. 推送代码与 Tag

```bash
git push origin master
git push origin v1.2.1
```

### 8. 生成发布包并发布 Release

建议保证：

- Release 标题与 Tag 一致
- 版本说明与 `MARKETING_VERSION`、`CURRENT_PROJECT_VERSION` 保持一致

## 本项目的实际建议

结合 Quick Panel 当前阶段，建议使用以下策略：

- 开发中的零碎修复：
  - 不必频繁改 `MARKETING_VERSION`
  - 如果不对外发包，可以先不动构建号

- 准备对外发布测试包或正式包时：
  - 必须递增 `CURRENT_PROJECT_VERSION`

- 一轮明确的新功能发布时：
  - 增加 `MARKETING_VERSION` 的次版本或修订版本

### 当前阶段建议示例

如果下一轮主要是修 bug 和稳定性：

- `1.2.1`

如果下一轮加入明显新功能，例如：

- 配置导入导出
- 日志查看器
- 更完善的更新机制

则可以升级到：

- `1.3.0`

## 后续可自动化的部分

当前建议先手动执行，等流程稳定后再自动化。后续可考虑增加：

- 自动递增 build number 脚本
- 自动创建 tag 的脚本
- 自动生成发布提交信息
- 自动校验 README 中版本号是否同步

如果后面要做脚本，优先建议做一个简单的发布辅助脚本，而不是一开始就把全部流程做成复杂自动化。
