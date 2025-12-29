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
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    // MARK: - Favicon Fetching

    func fetchFavicon(for urlString: String, completion: @escaping (NSImage?) -> Void) {
        print("🧩 fetchFavicon input: \(urlString)")
        guard let url = URLNormalizer.normalizedURL(from: urlString),
              let host = url.host,
              let scheme = url.scheme else {
            print("❌ URL normalization failed for: \(urlString)")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        print("✅ Normalized URL: \(url.absoluteString)")
        // Only try to fetch from the target website itself
        // Try common favicon locations on the target site
        let methods = [
            "\(scheme)://\(host)/favicon.ico",
            "\(scheme)://\(host)/favicon.png",
            "\(scheme)://\(host)/apple-touch-icon.png",
            "\(scheme)://\(host)/apple-touch-icon-precomposed.png"
        ]

        print("🔍 Will try fetching favicon from target website only (no external services)")
        print("🧪 Favicon candidate URLs: \(methods)")
        fetchFaviconFromURLs(methods) { image in
            if let image = image {
                print("✅ Favicon loaded from direct URL list")
                completion(image)
                return
            }

            print("ℹ️ Direct favicon URLs failed, trying HTML parsing")
            self.fetchFaviconLinksFromHTML(baseURL: url) { urls in
                print("🔎 HTML icon links found: \(urls.map { $0.absoluteString })")
                guard !urls.isEmpty else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }

                let urlStrings = urls.map { $0.absoluteString }
                self.fetchFaviconFromURLs(urlStrings, completion: completion)
            }
        }
    }

    private func fetchFaviconFromURLs(_ urls: [String], completion: @escaping (NSImage?) -> Void) {
        guard !urls.isEmpty else {
            print("⚠️ No more favicon URLs to try")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        let currentURL = urls[0]
        let remainingURLs = Array(urls.dropFirst())

        guard let url = URL(string: currentURL) else {
            print("⚠️ Invalid favicon URL string: \(currentURL)")
            fetchFaviconFromURLs(remainingURLs, completion: completion)
            return
        }

        print("🌐 Attempting to fetch favicon from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
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

    // MARK: - HTML Icon Parsing

    private func fetchFaviconLinksFromHTML(baseURL: URL, completion: @escaping ([URL]) -> Void) {
        print("🌐 Fetching HTML for icon links: \(baseURL.absoluteString)")
        var request = URLRequest(url: baseURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,*/*;q=0.8", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ HTML fetch error for \(baseURL.absoluteString): \(error.localizedDescription)")
                completion([])
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("⚠️ HTML fetch status \(httpResponse.statusCode) for \(baseURL.absoluteString)")
                    completion([])
                    return
                }
            }

            guard let data = data else {
                print("⚠️ HTML fetch returned no data for \(baseURL.absoluteString)")
                completion([])
                return
            }

            let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            guard let htmlString = html else {
                print("⚠️ Failed to decode HTML for \(baseURL.absoluteString)")
                completion([])
                return
            }

            print("📄 HTML length: \(htmlString.count) chars")
            let urls = self.extractIconURLs(from: htmlString, baseURL: baseURL)
            completion(urls)
        }.resume()
    }

    private func extractIconURLs(from html: String, baseURL: URL) -> [URL] {
        guard let linkRegex = try? NSRegularExpression(pattern: "(?i)<link\\b[^>]*>", options: []) else {
            print("⚠️ Failed to build link tag regex")
            return []
        }

        let nsHTML = html as NSString
        let matches = linkRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))

        var results: [URL] = []
        var seen = Set<String>()

        for match in matches {
            let tag = nsHTML.substring(with: match.range)

            guard let rel = extractAttribute(named: "rel", from: tag)?.lowercased(),
                  rel.contains("icon") else {
                continue
            }

            guard let href = extractAttribute(named: "href", from: tag),
                  !href.lowercased().hasPrefix("data:") else {
                continue
            }

            guard let resolvedURL = URL(string: href, relativeTo: baseURL)?.absoluteURL,
                  let scheme = resolvedURL.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                continue
            }

            let key = resolvedURL.absoluteString
            if !seen.contains(key) {
                seen.insert(key)
                results.append(resolvedURL)
            }
        }

        print("🧾 Parsed \(results.count) icon URLs from HTML")
        return results
    }

    private func extractAttribute(named name: String, from tag: String) -> String? {
        let quotedPattern = "(?i)\\b\(name)\\s*=\\s*([\"'])(.*?)\\1"
        if let regex = try? NSRegularExpression(pattern: quotedPattern, options: []) {
            let nsTag = tag as NSString
            if let match = regex.firstMatch(in: tag, options: [], range: NSRange(location: 0, length: nsTag.length)),
               match.numberOfRanges >= 3 {
                return nsTag.substring(with: match.range(at: 2))
            }
        }

        let unquotedPattern = "(?i)\\b\(name)\\s*=\\s*([^\\s>]+)"
        if let regex = try? NSRegularExpression(pattern: unquotedPattern, options: []) {
            let nsTag = tag as NSString
            if let match = regex.firstMatch(in: tag, options: [], range: NSRange(location: 0, length: nsTag.length)),
               match.numberOfRanges >= 2 {
                return nsTag.substring(with: match.range(at: 1))
            }
        }

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

enum URLNormalizer {
    static func normalizedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return url
        }

        if let url = URL(string: "https://\(trimmed)"), url.host != nil {
            return url
        }

        return nil
    }
}
