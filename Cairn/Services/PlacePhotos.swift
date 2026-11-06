import Foundation
import UIKit

/// A photo of a mountain or place, with the credit its license requires.
struct PlacePhoto: Equatable, Sendable {
    enum Source: Sendable { case wikimedia, unsplash }

    let source: Source
    let imageURL: URL
    /// Who took it, e.g. "shrimpo1967".
    let author: String
    /// e.g. "CC BY-SA 2.0" (Wikimedia only; Unsplash photos use the Unsplash License).
    let license: String?
    /// Where tapping the credit goes: the Commons file page or the photographer's Unsplash profile.
    let creditURL: URL
    /// Unsplash asks apps to call this once when a photo is actually shown.
    let downloadPingURL: URL?

    /// Short credit for tight spots, e.g. "shrimpo1967 · CC BY-SA 2.0" or
    /// "Jane Doe / Unsplash". Tapping it opens `creditURL`, the full source.
    var shortCredit: String {
        switch source {
        case .wikimedia: [author, license].compactMap { $0 }.joined(separator: " · ")
        case .unsplash: "\(author) / Unsplash"
        }
    }

    /// One-line credit, e.g. "Photo: shrimpo1967 · CC BY-SA 2.0 · Wikimedia Commons".
    var creditLine: String {
        switch source {
        case .wikimedia:
            ["Photo: \(author)", license, "Wikimedia Commons"].compactMap { $0 }.joined(separator: " · ")
        case .unsplash:
            "Photo by \(author) on Unsplash"
        }
    }
}

/// Finds a photo for a spot on the globe.
///
/// 1. Peaks: the peak's own photo from Wikimedia Commons. tools/add_peak_photos.py
///    matched about 22,000 bundled peaks to their Wikidata image, so this is a
///    picture of that exact mountain. Free, no key.
/// 2. Otherwise (no Commons photo, or a place rather than a peak): an Unsplash
///    search by name. Needs a free Unsplash access key in Config/Secrets.xcconfig
///    (UNSPLASH_ACCESS_KEY); without one this step is skipped.
///
/// Results (including "no photo") are kept in memory for the session.
actor PlacePhotos {
    static let shared = PlacePhotos()

    private var cache: [String: PlacePhoto?] = [:]
    private var images: [URL: UIImage] = [:]
    private let session = URLSession(configuration: .default)
    private let userAgent = "Cairn/1.0 (iOS app)"

    func photo(for destination: GlobeDestination) async -> PlacePhoto? {
        if let cached = cache[destination.id] { return cached }
        var found: PlacePhoto?
        if let peakID = destination.peakID, let file = await PeakSearch.shared.photoFile(for: peakID) {
            found = await wikimediaPhoto(file: file)
        }
        if found == nil {
            let query = destination.peakID == nil ? destination.name : "\(destination.name) mountain"
            found = await unsplashPhoto(query: query)
        }
        cache[destination.id] = found
        return found
    }

    /// Downloads the picture itself, so it can appear all at once rather than
    /// loading in. Kept in memory for the session.
    func image(for photo: PlacePhoto) async -> UIImage? {
        if let cached = images[photo.imageURL] { return cached }
        var request = URLRequest(url: photo.imageURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await session.data(for: request),
              let image = UIImage(data: data)
        else { return nil }
        images[photo.imageURL] = image
        return image
    }

    /// Tells Unsplash the photo was shown (their API guidelines ask for this).
    func reportShown(_ photo: PlacePhoto) async {
        guard let ping = photo.downloadPingURL, let key = AppConfig.unsplashAccessKey else { return }
        var request = URLRequest(url: ping)
        request.setValue("Client-ID \(key)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }

    // MARK: - Wikimedia Commons

    private func wikimediaPhoto(file: String) async -> PlacePhoto? {
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "format", value: "json"),
            .init(name: "formatversion", value: "2"),
            .init(name: "prop", value: "imageinfo"),
            .init(name: "iiprop", value: "url|extmetadata"),
            // Sized by height: photos fill a tall portrait screen, so a
            // landscape shot is cropped hard and needs the extra pixels.
            .init(name: "iiurlheight", value: "2000"),
            .init(name: "iiextmetadatafilter", value: "Artist|LicenseShortName"),
            .init(name: "titles", value: "File:\(file)"),
        ]
        var request = URLRequest(url: components.url!)
        // Wikimedia asks every API client to identify itself.
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await session.data(for: request),
              let response = try? JSONDecoder().decode(CommonsResponse.self, from: data),
              let info = response.query.pages.first?.imageinfo?.first,
              let image = URL(string: info.thumburl ?? info.url),
              let page = URL(string: info.descriptionurl)
        else { return nil }

        let author = info.extmetadata?.Artist.map { Self.plainText($0.value) } ?? ""
        return PlacePhoto(
            source: .wikimedia,
            imageURL: image,
            author: author.isEmpty ? "Unknown" : author,
            license: info.extmetadata?.LicenseShortName?.value,
            creditURL: page,
            downloadPingURL: nil
        )
    }

    /// Commons gives the author as HTML (links, lists); keep just the name.
    /// When it's a list of links (e.g. "Original.jpg: shrimpo1967 · derivative
    /// work: …"), the first link that isn't a file or talk page is the photographer.
    private static func plainText(_ html: String) -> String {
        let linkTexts = html.matches(of: /<a [^>]*>([^<]+)<\/a>/).map { String($0.output.1) }
        let fileEndings = [".jpg", ".jpeg", ".png", ".tif", ".tiff", ".gif", ".webp"]
        if let name = linkTexts.first(where: { text in
            let lower = text.lowercased()
            return lower != "talk" && !fileEndings.contains(where: lower.hasSuffix)
        }) {
            return name.trimmingCharacters(in: .whitespaces)
        }
        let noTags = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let decoded = noTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        let words = decoded.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return words.count > 60 ? String(words.prefix(57)) + "…" : words
    }

    private struct CommonsResponse: Decodable {
        struct Query: Decodable { let pages: [Page] }
        struct Page: Decodable { let imageinfo: [ImageInfo]? }
        struct ImageInfo: Decodable {
            let thumburl: String?
            let url: String
            let descriptionurl: String
            let extmetadata: Metadata?
        }
        struct Metadata: Decodable {
            let Artist: Value?
            let LicenseShortName: Value?
        }
        struct Value: Decodable { let value: String }
        let query: Query
    }

    // MARK: - Unsplash

    private func unsplashPhoto(query: String) async -> PlacePhoto? {
        guard let key = AppConfig.unsplashAccessKey else { return nil }
        var components = URLComponents(string: "https://api.unsplash.com/search/photos")!
        components.queryItems = [
            .init(name: "query", value: query),
            .init(name: "per_page", value: "1"),
            .init(name: "orientation", value: "landscape"),
            .init(name: "content_filter", value: "high"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Client-ID \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")
        guard let (data, _) = try? await session.data(for: request),
              let response = try? JSONDecoder().decode(UnsplashSearch.self, from: data),
              let hit = response.results.first,
              let image = URL(string: hit.urls.regular),
              // Unsplash asks for links back with these referral parameters.
              let profile = URL(string: hit.user.links.html + "?utm_source=cairn&utm_medium=referral")
        else { return nil }
        return PlacePhoto(
            source: .unsplash,
            imageURL: image,
            author: hit.user.name,
            license: nil,
            creditURL: profile,
            downloadPingURL: URL(string: hit.links.download_location)
        )
    }

    private struct UnsplashSearch: Decodable {
        struct Result: Decodable {
            struct URLs: Decodable { let regular: String }
            struct User: Decodable {
                struct Links: Decodable { let html: String }
                let name: String
                let links: Links
            }
            struct Links: Decodable { let download_location: String }
            let urls: URLs
            let user: User
            let links: Links
        }
        let results: [Result]
    }
}
