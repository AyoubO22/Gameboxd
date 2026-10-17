//
//  RemoteImage.swift
//  Gameboxd
//
//  Pictures that come from other players' data (covers in the feed and in their
//  collection). Only the game databases the app itself uses are loaded, so nobody can
//  point a cover at their own server and log the address of every phone that shows it.
//

import Foundation

nonisolated enum RemoteImage {
    /// Same rule as `public.is_allowed_image_url` in supabase/schema.sql: what the app
    /// sends must pass the database check, or the whole upload is refused.
    private static let pattern = #"^https://([a-z0-9-]+\.)*(rawg\.io|igdb\.com|steamstatic\.com|steampowered\.com|playstation\.com|playstation\.net)/"#

    static func isAllowed(_ string: String) -> Bool {
        string.utf8.count <= 2048 && string.range(of: pattern, options: .regularExpression) != nil
    }

    /// The string itself when it may be shared, nil otherwise.
    static func shareable(_ string: String?) -> String? {
        guard let string, isAllowed(string) else { return nil }
        return string
    }

    /// A URL to load, or nil when the picture isn't from an allowed host.
    static func url(_ string: String?) -> URL? {
        shareable(string).flatMap(URL.init(string:))
    }
}
