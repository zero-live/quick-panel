//
//  IconFetcher.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import AppKit

struct WebsiteMetadata {
    let title: String?
    let icon: NSImage?
}

private final class WebsiteMetadataBox: NSObject {
    let metadata: WebsiteMetadata

    init(_ metadata: WebsiteMetadata) {
        self.metadata = metadata
    }
}

class IconFetcher {
    static let shared = IconFetcher()

    private init() {}
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    private let logCategory: AppLogCategory = .network
    private let metadataCache = NSCache<NSString, WebsiteMetadataBox>()
    private let maximumHTMLBytes = 2 * 1024 * 1024
    private let maximumImageBytes = 5 * 1024 * 1024
    private let maximumIconCandidates = 4

    // MARK: - Favicon Fetching

    func fetchFavicon(for urlString: String, completion: @escaping (NSImage?) -> Void) {
        fetchWebsiteMetadata(for: urlString) { metadata in
            completion(metadata.icon)
        }
    }

    func fetchWebsiteMetadata(for urlString: String, completion: @escaping (WebsiteMetadata) -> Void) {
        guard let url = URLNormalizer.normalizedURL(from: urlString),
              let host = url.host,
              let scheme = url.scheme else {
            AppLogger.notice("网站元数据抓取失败：URL 无法规范化，input=\(urlString)。", category: logCategory)
            DispatchQueue.main.async {
                completion(WebsiteMetadata(title: nil, icon: nil))
            }
            return
        }

        let cacheKey = url.absoluteString as NSString
        if let cachedMetadata = metadataCache.object(forKey: cacheKey)?.metadata {
            DispatchQueue.main.async {
                completion(cachedMetadata)
            }
            return
        }

        AppLogger.debug("开始抓取网站元数据：\(url.absoluteString)。", category: logCategory)
        let directCandidates = self.defaultIconCandidates(for: host, scheme: scheme)

        self.fetchWebsiteHTML(baseURL: url) { html in
            let htmlTitle = html.flatMap { self.extractWebsiteTitle(from: $0) }
            let htmlIconCandidates = html.map { self.extractIconCandidates(from: $0, baseURL: url) } ?? []
            let iconCandidates = self.mergeIconCandidates(primary: htmlIconCandidates, fallback: directCandidates)

            self.fetchBestFavicon(from: iconCandidates) { image in
                let metadata = WebsiteMetadata(title: htmlTitle, icon: image)
                self.metadataCache.setObject(WebsiteMetadataBox(metadata), forKey: cacheKey)
                DispatchQueue.main.async {
                    AppLogger.info("网站元数据抓取完成：url=\(url.absoluteString)，title=\(htmlTitle ?? "nil")，icon=\(image != nil ? "yes" : "no")。", category: self.logCategory)
                    completion(metadata)
                }
            }
        }
    }

    private struct IconCandidate {
        let url: URL
        let declaredSize: Int
        let priority: Int
    }

    private func fetchBestFavicon(from candidates: [IconCandidate], completion: @escaping (NSImage?) -> Void) {
        guard !candidates.isEmpty else {
            AppLogger.notice("未找到可用的网站图标候选地址。", category: logCategory)
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            if lhs.declaredSize != rhs.declaredSize {
                return lhs.declaredSize > rhs.declaredSize
            }
            return lhs.url.absoluteString < rhs.url.absoluteString
        }

        var candidatesToTry = Array(sortedCandidates.prefix(maximumIconCandidates))
        if let standardFallback = sortedCandidates.first(where: {
            $0.url.lastPathComponent.lowercased() == "favicon.ico" ||
            $0.url.lastPathComponent.lowercased() == "favicon.png"
        }), !candidatesToTry.contains(where: { $0.url == standardFallback.url }) {
            candidatesToTry.append(standardFallback)
        }

        func fetchCandidate(at index: Int) {
            guard index < candidatesToTry.count else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            fetchImage(at: candidatesToTry[index].url) { image in
                if let image {
                    DispatchQueue.main.async {
                        completion(image)
                    }
                } else {
                    fetchCandidate(at: index + 1)
                }
            }
        }

        fetchCandidate(at: 0)
    }

    private func fetchImage(at url: URL, completion: @escaping (NSImage?) -> Void) {

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                AppLogger.debug("图标请求失败：\(url.absoluteString)，error=\(error.localizedDescription)。", category: self.logCategory)
                completion(nil)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {

                guard (200...299).contains(httpResponse.statusCode) else {
                    AppLogger.debug("图标请求返回非成功状态：\(url.absoluteString)，status=\(httpResponse.statusCode)。", category: self.logCategory)
                    completion(nil)
                    return
                }

                guard httpResponse.expectedContentLength <= 0 || httpResponse.expectedContentLength <= Int64(self.maximumImageBytes) else {
                    AppLogger.notice("图标文件过大，已跳过：\(url.absoluteString)。", category: self.logCategory)
                    completion(nil)
                    return
                }
            }

            guard let data, data.count <= self.maximumImageBytes else {
                if data != nil {
                    AppLogger.notice("图标文件超过大小限制，已跳过：\(url.absoluteString)。", category: self.logCategory)
                }
                completion(nil)
                return
            }

            let image = self.createImageFromData(data, sourceURL: url.absoluteString)
            completion(image)
        }.resume()
    }

    // MARK: - Image Processing

    private func createImageFromData(_ data: Data, sourceURL: String) -> NSImage? {
        // Try direct NSImage creation first
        if let image = NSImage(data: data), image.isValid {
            return image
        }

        // For ICO files, try to extract the largest representation
        if sourceURL.hasSuffix(".ico") {
            return convertICOToImage(data)
        }

        return nil
    }

    private func convertICOToImage(_ data: Data) -> NSImage? {
        // Try to create NSImage from ICO data
        // NSImage on macOS should support ICO, but sometimes needs special handling
        guard let image = NSImage(data: data) else {
            return nil
        }

        // ICO files often contain multiple resolutions
        // Try to find the best representation
        if let bestRep = image.representations.max(by: { rep1, rep2 in
            let size1 = rep1.pixelsWide * rep1.pixelsHigh
            let size2 = rep2.pixelsWide * rep2.pixelsHigh
            return size1 < size2
        }) {

            // Create a new image with the best representation
            let newImage = NSImage(size: NSSize(width: bestRep.pixelsWide, height: bestRep.pixelsHigh))
            newImage.addRepresentation(bestRep)

            if newImage.isValid {
                return newImage
            }
        }

        // If we got an image but couldn't optimize it, return the original
        if image.isValid {
            return image
        }

        return nil
    }

    // MARK: - HTML Icon Parsing

    private func fetchWebsiteHTML(baseURL: URL, completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: baseURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,*/*;q=0.8", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                AppLogger.debug("页面 HTML 请求失败：\(baseURL.absoluteString)，error=\(error.localizedDescription)。", category: self.logCategory)
                completion(nil)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    AppLogger.debug("页面 HTML 返回非成功状态：\(baseURL.absoluteString)，status=\(httpResponse.statusCode)。", category: self.logCategory)
                    completion(nil)
                    return
                }

                guard httpResponse.expectedContentLength <= 0 || httpResponse.expectedContentLength <= Int64(self.maximumHTMLBytes) else {
                    AppLogger.notice("页面内容过大，已跳过元数据解析：\(baseURL.absoluteString)。", category: self.logCategory)
                    completion(nil)
                    return
                }
            }

            guard let data = data, data.count <= self.maximumHTMLBytes else {
                if data != nil {
                    AppLogger.notice("页面内容超过大小限制，已跳过元数据解析：\(baseURL.absoluteString)。", category: self.logCategory)
                }
                completion(nil)
                return
            }

            let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            guard let htmlString = html else {
                completion(nil)
                return
            }

            completion(htmlString)
        }.resume()
    }

    private func extractIconCandidates(from html: String, baseURL: URL) -> [IconCandidate] {
        guard let linkRegex = try? NSRegularExpression(pattern: "(?i)<link\\b[^>]*>", options: []) else {
            return []
        }

        let nsHTML = html as NSString
        let matches = linkRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))

        var results: [IconCandidate] = []
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
                results.append(
                    IconCandidate(
                        url: resolvedURL,
                        declaredSize: extractDeclaredIconSize(from: tag),
                        priority: iconPriority(for: rel, url: resolvedURL)
                    )
                )
            }
        }

        return results
    }

    private func extractWebsiteTitle(from html: String) -> String? {
        if let ogTitle = extractMetaContent(property: "og:title", from: html) {
            return normalizedWebsiteTitle(ogTitle)
        }

        if let twitterTitle = extractMetaContent(property: "twitter:title", from: html) {
            return normalizedWebsiteTitle(twitterTitle)
        }

        guard let titleRegex = try? NSRegularExpression(pattern: "(?is)<title[^>]*>(.*?)</title>", options: []) else {
            return nil
        }

        let nsHTML = html as NSString
        guard let match = titleRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }

        return normalizedWebsiteTitle(nsHTML.substring(with: match.range(at: 1)))
    }

    private func extractMetaContent(property: String, from html: String) -> String? {
        let pattern = "(?is)<meta\\b[^>]*(?:property|name)\\s*=\\s*([\"'])\(NSRegularExpression.escapedPattern(for: property))\\1[^>]*content\\s*=\\s*([\"'])(.*?)\\2[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsHTML = html as NSString
        guard let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length)),
              match.numberOfRanges >= 4 else {
            return nil
        }

        return normalizedWebsiteTitle(nsHTML.substring(with: match.range(at: 3)))
    }

    private func normalizedWebsiteTitle(_ rawTitle: String) -> String? {
        let decoded = rawTitle
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        let compact = decoded
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? nil : compact
    }

    private func defaultIconCandidates(for host: String, scheme: String) -> [IconCandidate] {
        [
            IconCandidate(url: URL(string: "\(scheme)://\(host)/apple-touch-icon.png")!, declaredSize: 180, priority: 1000),
            IconCandidate(url: URL(string: "\(scheme)://\(host)/apple-touch-icon-precomposed.png")!, declaredSize: 180, priority: 990),
            IconCandidate(url: URL(string: "\(scheme)://\(host)/favicon-196x196.png")!, declaredSize: 196, priority: 950),
            IconCandidate(url: URL(string: "\(scheme)://\(host)/favicon-192x192.png")!, declaredSize: 192, priority: 940),
            IconCandidate(url: URL(string: "\(scheme)://\(host)/favicon-96x96.png")!, declaredSize: 96, priority: 930),
            IconCandidate(url: URL(string: "\(scheme)://\(host)/favicon-64x64.png")!, declaredSize: 64, priority: 920),
            IconCandidate(url: URL(string: "\(scheme)://\(host)/favicon-32x32.png")!, declaredSize: 32, priority: 910),
            IconCandidate(url: URL(string: "\(scheme)://\(host)/favicon.png")!, declaredSize: 32, priority: 900),
            IconCandidate(url: URL(string: "\(scheme)://\(host)/favicon.ico")!, declaredSize: 32, priority: 890)
        ]
    }

    private func mergeIconCandidates(primary: [IconCandidate], fallback: [IconCandidate]) -> [IconCandidate] {
        var merged: [IconCandidate] = []
        var seen = Set<String>()

        for candidate in primary + fallback {
            let key = candidate.url.absoluteString
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(candidate)
        }

        return merged
    }

    private func extractDeclaredIconSize(from tag: String) -> Int {
        guard let sizes = extractAttribute(named: "sizes", from: tag)?.lowercased() else {
            return 0
        }

        if sizes == "any" {
            return 1024
        }

        let values = sizes
            .split(separator: " ")
            .compactMap { token -> Int? in
                let parts = token.split(separator: "x")
                guard let first = parts.first, let value = Int(first) else { return nil }
                return value
            }

        return values.max() ?? 0
    }

    private func iconPriority(for rel: String, url: URL) -> Int {
        let urlString = url.absoluteString.lowercased()

        if rel.contains("apple-touch-icon") {
            return 1200
        }
        if rel.contains("mask-icon") {
            return 1100
        }
        if rel.contains("fluid-icon") {
            return 1050
        }
        if urlString.hasSuffix(".svg") {
            return 1025
        }
        if rel.contains("shortcut icon") {
            return 980
        }
        return 960
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

    var bestPixelArea: Int {
        let maxRepresentation = representations.max { lhs, rhs in
            lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
        }

        if let maxRepresentation {
            return maxRepresentation.pixelsWide * maxRepresentation.pixelsHigh
        }

        return Int(size.width * size.height)
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
