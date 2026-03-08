//
//  AboutView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI

struct AboutView: View {
    @ObservedObject var updateManager = UpdateManager.shared

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .shadow(radius: 5)
            }

            Text("Quick Panel")
                .font(.system(size: 28, weight: .bold))

            Text("版本 \(appVersion) (\(buildNumber))")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            Text("macOS 快捷面板工具")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("通过鼠标中键快速访问常用应用和网站")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                if updateManager.isChecking {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("检查更新中...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else if updateManager.hasUpdate, let latest = updateManager.latestVersion {
                    VStack(spacing: 6) {
                        Text("🎉 发现新版本 v\(latest)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                        Button("立即更新") {
                            updateManager.downloadAndInstall()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                } else {
                    Button("检查更新") {
                        updateManager.checkForUpdates(silent: false)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Spacer()

            Text("© 2025 Quick Panel")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400, height: 460)
    }
}
