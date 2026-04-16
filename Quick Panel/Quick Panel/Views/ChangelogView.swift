//
//  ChangelogView.swift
//  Quick Panel
//
//  Created by Codex on 2026/04/16.
//

import SwiftUI

struct ChangelogView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @State private var selectedVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    private let releases = ChangelogManager.shared.releases

    private var selectedRelease: ChangelogRelease? {
        releases.first(where: { $0.version == selectedVersion }) ?? releases.first
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 760, height: 520)
        .onAppear {
            if !releases.contains(where: { $0.version == selectedVersion }) {
                selectedVersion = releases.first?.version ?? currentVersion
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("更新日志")
                    .font(.system(size: 20, weight: .semibold))
                Text("查看各版本新增、优化与修复内容")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("当前版本")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentVersion)
                            .font(.system(size: 18, weight: .semibold))
                        Text("构建号 \(currentBuild)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(updateManager.hasUpdate ? "可更新" : "最新")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(updateManager.hasUpdate ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((updateManager.hasUpdate ? Color.green : Color.secondary).opacity(0.12))
                        .cornerRadius(8)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(releases) { release in
                        versionRow(for: release)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 240)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let release = selectedRelease {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("版本 \(release.version)")
                                .font(.system(size: 24, weight: .semibold))
                            if let build = release.build {
                                Text("(\(build))")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(release.status)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        Button("检查更新") {
                            updateManager.checkForUpdates(silent: false)
                        }
                        .buttonStyle(.bordered)
                        .disabled(updateManager.isChecking)

                        Button("复制版本信息") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString("Quick Panel \(currentVersion) (\(currentBuild))", forType: .string)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(release.sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(sectionColor(for: section.title))

                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(section.items, id: \.self) { item in
                                        HStack(alignment: .top, spacing: 8) {
                                            Circle()
                                                .fill(sectionColor(for: section.title))
                                                .frame(width: 5, height: 5)
                                                .padding(.top, 6)
                                            Text(item)
                                                .font(.system(size: 13))
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(14)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor).opacity(0.35))
    }

    private func versionRow(for release: ChangelogRelease) -> some View {
        Button(action: {
            selectedVersion = release.version
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(release.version)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text(release.status)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if release.version == currentVersion {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedVersion == release.version ? Color.accentColor.opacity(0.12) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func sectionColor(for title: String) -> Color {
        switch title {
        case "新增", "首次发布":
            return .green
        case "优化":
            return .blue
        case "修复":
            return .orange
        default:
            return .secondary
        }
    }
}
