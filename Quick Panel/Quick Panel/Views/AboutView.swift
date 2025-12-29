//
//  AboutView.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import SwiftUI

struct AboutView: View {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let appIcon = NSApplication.shared.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .shadow(radius: 5)
            }

            // App Name
            Text("Quick Panel")
                .font(.system(size: 28, weight: .bold))

            // Version
            Text("版本 \(appVersion) (\(buildNumber))")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            // Description
            Text("macOS 快捷面板工具")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text("通过鼠标中键快速访问常用应用和网站")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Copyright
            Text("© 2025 Quick Panel")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400, height: 420)
    }
}
