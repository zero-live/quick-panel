# Quick Panel 版本管理与发布

## 当前版本

- 版本：`1.5.1`，构建号：`14`。
- 发布分支：`master`，主远程：`origin`。
- 源码与 Release：https://github.com/zero-live/quick-panel
- 下载与应用内更新均使用公开的 GitHub Releases。
- 版本说明见 [1.5.1](releases/v1.5.1.md)，历史变更见 [CHANGELOG](../CHANGELOG.md)。

GitHub 是后续开发和发布的主仓库。日常代码、标签和 Pull Request 统一使用 GitHub，默认推送到 `origin`；历史备用远程仅在用户明确要求时同步。

## 版本与标签

对外版本来自 Xcode 工程的 `MARKETING_VERSION`，构建号来自 `CURRENT_PROJECT_VERSION`。新增功能提升次版本，修复提升修订版本；每次准备发布包都递增构建号。

设置页、关于页和更新检查从 `CFBundleShortVersionString` / `CFBundleVersion` 读取版本。正式发布标签使用 `v<版本号>`，必须指向对应的发布提交；已经公开的标签不要移动或覆盖。

## 发布流程

1. 完成功能与文档修改，更新工程版本、README、CHANGELOG 和应用内 ChangelogManager。
2. 退出运行中的 Quick Panel，然后构建并运行单元测试。
3. 构建 Universal Release，确认版本、架构、图标与代码签名。
4. 生成 DMG 并挂载检查安装内容。
5. 生成 SHA-256 校验文件。
6. 提交代码、创建标签，并推送到 GitHub。
7. 创建 GitHub Release，附上 DMG、校验文件与对应发布说明，最后验证公开下载与最新版本 API。

### 构建与测试

```bash
xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" \
  -scheme "Quick Panel" -configuration Debug test

xcodebuild -project "Quick Panel/Quick Panel.xcodeproj" \
  -scheme "Quick Panel" -configuration Release \
  -derivedDataPath "dist/github-release-v1.5.1" \
  "ARCHS=arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- build
```

上述 Release 命令使用 ad-hoc 签名。以后取得 Developer ID 证书时，使用实际证书签名并完成 Apple 公证，再在发布说明中更新签名状态。不得将 ad-hoc 包描述为已公证。

### DMG 安装内容

面向用户的 DMG 必须包含：

- `Quick Panel.app`。
- 指向 `/Applications` 的 `Applications` 快捷方式。
- 合理的 Finder 窗口与图标布局。

优先使用 `create-dmg`；安装包和构建目录保存在被 Git 忽略的 `dist/` 中，作为 Release 附件上传，不放进源码仓库。

```bash
create-dmg \
  --volname "Quick Panel" \
  --window-pos 120 120 --window-size 560 310 \
  --icon-size 96 --icon "Quick Panel.app" 150 150 \
  --app-drop-link 400 150 --hide-extension "Quick Panel.app" \
  "dist/Quick.Panel-v1.5.1-universal.dmg" \
  "dist/github-staging-v1.5.1"
```

没有图形环境时，可用 `--skip-jenkins`，并通过 `--add-file .DS_Store <已验证的布局文件> 0 0` 复用仅包含应用与 Applications 快捷方式的 Finder 布局。

### 校验与发布

```bash
cd dist
shasum -a 256 "Quick.Panel-v1.5.1-universal.dmg" > SHA256SUMS.txt
cd ..

git tag v1.5.1
git push origin master
git push origin v1.5.1

gh release create v1.5.1 \
  "dist/Quick.Panel-v1.5.1-universal.dmg" "dist/SHA256SUMS.txt" \
  --repo zero-live/quick-panel --verify-tag --latest \
  --title "Quick Panel 1.5.1" --notes-file docs/releases/v1.5.1.md
```

先挂载 DMG 核对内容、版本和签名，再执行发布命令。发布完成后，通过无登录的 GitHub API 和公开附件地址验证访问及 SHA-256 一致性。

更新服务地址：`https://api.github.com/repos/zero-live/quick-panel/releases/latest`。更新包附件扩展名为 `.dmg`；应用使用 `tag_name`、`body` 和 `assets[].browser_download_url` 读取版本与安装包。
