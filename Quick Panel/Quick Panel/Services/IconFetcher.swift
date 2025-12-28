//
//  IconFetcher.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import AppKit

class IconFetcher {
    static let shared = IconFetcher()

    private init() {}

    // MARK: - Favicon Fetching

    func fetchFavicon(for urlString: String, completion: @escaping (NSImage?) -> Void) {
        guard let url = URL(string: urlString),
              let host = url.host else {
            completion(nil)
            return
        }

        // Try multiple methods
        let methods = [
            "https://\(host)/favicon.ico",
            "https://www.google.com/s2/favicons?domain=\(host)&sz=128",
            "https://icons.duckduckgo.com/ip3/\(host).ico"
        ]

        fetchFaviconFromURLs(methods, completion: completion)
    }

    private func fetchFaviconFromURLs(_ urls: [String], completion: @escaping (NSImage?) -> Void) {
        guard !urls.isEmpty else {
            completion(nil)
            return
        }

        let currentURL = urls[0]
        let remainingURLs = Array(urls.dropFirst())

        guard let url = URL(string: currentURL) else {
            fetchFaviconFromURLs(remainingURLs, completion: completion)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data,
               let image = NSImage(data: data),
               image.isValid {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                // Try next URL
                self.fetchFaviconFromURLs(remainingURLs, completion: completion)
            }
        }.resume()
    }

    // MARK: - App Icon Fetching

    func fetchAppIcon(at path: String) -> NSImage? {
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        return NSWorkspace.shared.icon(forFile: path)
    }
}

extension NSImage {
    var isValid: Bool {
        return self.size.width > 0 && self.size.height > 0
    }
}
