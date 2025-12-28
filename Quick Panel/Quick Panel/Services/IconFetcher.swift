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
              let host = url.host,
              let scheme = url.scheme else {
            completion(nil)
            return
        }

        // Only try to fetch from the target website itself
        // Try common favicon locations on the target site
        let methods = [
            "\(scheme)://\(host)/favicon.ico",
            "\(scheme)://\(host)/favicon.png",
            "\(scheme)://\(host)/apple-touch-icon.png",
            "\(scheme)://\(host)/apple-touch-icon-precomposed.png"
        ]

        print("🔍 Will try fetching favicon from target website only (no external services)")
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

        print("🌐 Attempting to fetch favicon from: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Favicon fetch error for \(url.absoluteString): \(error.localizedDescription)")
                // Try next URL
                self.fetchFaviconFromURLs(remainingURLs, completion: completion)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode) for \(url.absoluteString)")

                // Only accept successful status codes
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("⚠️ Non-success status code, trying next URL")
                    self.fetchFaviconFromURLs(remainingURLs, completion: completion)
                    return
                }
            }

            if let data = data {
                print("📦 Received \(data.count) bytes of data")

                // Try to create image from data
                if let image = self.createImageFromData(data, sourceURL: url.absoluteString) {
                    print("✅ Successfully created image from: \(url.absoluteString)")
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } else {
                    print("⚠️ Failed to create image from data, trying next URL")
                    // Try next URL
                    self.fetchFaviconFromURLs(remainingURLs, completion: completion)
                }
            } else {
                print("⚠️ No data received from: \(url.absoluteString)")
                // Try next URL
                self.fetchFaviconFromURLs(remainingURLs, completion: completion)
            }
        }.resume()
    }

    // MARK: - Image Processing

    private func createImageFromData(_ data: Data, sourceURL: String) -> NSImage? {
        // Try direct NSImage creation first
        if let image = NSImage(data: data), image.isValid {
            print("✓ Direct NSImage creation succeeded")
            return image
        }

        // For ICO files, try to extract the largest representation
        if sourceURL.hasSuffix(".ico") {
            print("🔄 Attempting ICO format conversion...")
            return convertICOToImage(data)
        }

        print("✗ All image creation methods failed")
        return nil
    }

    private func convertICOToImage(_ data: Data) -> NSImage? {
        // Try to create NSImage from ICO data
        // NSImage on macOS should support ICO, but sometimes needs special handling
        guard let image = NSImage(data: data) else {
            print("✗ Failed to create NSImage from ICO data")
            return nil
        }

        // ICO files often contain multiple resolutions
        // Try to find the best representation
        if let bestRep = image.representations.max(by: { rep1, rep2 in
            let size1 = rep1.pixelsWide * rep1.pixelsHigh
            let size2 = rep2.pixelsWide * rep2.pixelsHigh
            return size1 < size2
        }) {
            print("✓ Found ICO representation: \(bestRep.pixelsWide)x\(bestRep.pixelsHigh)")

            // Create a new image with the best representation
            let newImage = NSImage(size: NSSize(width: bestRep.pixelsWide, height: bestRep.pixelsHigh))
            newImage.addRepresentation(bestRep)

            if newImage.isValid {
                print("✓ ICO conversion succeeded")
                return newImage
            }
        }

        // If we got an image but couldn't optimize it, return the original
        if image.isValid {
            print("✓ Using original ICO image")
            return image
        }

        print("✗ ICO conversion failed")
        return nil
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
