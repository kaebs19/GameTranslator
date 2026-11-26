import Foundation

/// The little of HTTP a TV needs. Anything else is refused.
nonisolated struct HTTPRequest: Equatable, Sendable {
    enum Parsing: Equatable, Sendable {
        case incomplete, invalid
        case complete(HTTPRequest)
    }

    static let maximumSize = 8 * 1024

    let method: String
    let path: String
    let query: [String: String]
    let body: Data

    static func parse(_ data: Data) -> Parsing {
        guard data.count <= maximumSize else { return .invalid }
        guard let end = data.range(of: Data("\r\n\r\n".utf8)) else { return .incomplete }
        guard let head = String(data: data[..<end.lowerBound], encoding: .utf8) else { return .invalid }
        let lines = head.components(separatedBy: "\r\n")
        let start = lines[0].split(separator: " ")
        guard start.count == 3, start[2].hasPrefix("HTTP/1."), start[1].hasPrefix("/"),
              let target = URLComponents(string: String(start[1])) else { return .invalid }
        guard let length = contentLength(lines.dropFirst()) else { return .invalid }
        let body = data[end.upperBound...]
        guard body.count >= length else { return .incomplete }
        let query = (target.queryItems ?? []).reduce(into: [:]) { $0[$1.name] = $1.value }
        return .complete(HTTPRequest(
            method: String(start[0]), path: target.path, query: query, body: Data(body.prefix(length))
        ))
    }

    /// `nil` when the header makes no sense.
    private static func contentLength(_ headers: ArraySlice<String>) -> Int? {
        for header in headers {
            let parts = header.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].lowercased() == "content-length" else { continue }
            guard let value = Int(parts[1].trimmingCharacters(in: .whitespaces)), 0...maximumSize ~= value
            else { return nil }
            return value
        }
        return 0
    }
}

nonisolated struct HTTPResponse: Equatable, Sendable {
    enum Status: String, Sendable {
        case ok = "200 OK"
        case badRequest = "400 Bad Request"
        case unauthorized = "401 Unauthorized"
        case forbidden = "403 Forbidden"
        case notFound = "404 Not Found"
        case tooMany = "429 Too Many Requests"
        case unavailable = "503 Service Unavailable"
    }

    var status = Status.ok
    var type = "text/plain; charset=utf-8"
    var body = Data()

    var data: Data {
        Data("""
        HTTP/1.1 \(status.rawValue)\r
        Content-Type: \(type)\r
        Content-Length: \(body.count)\r
        Access-Control-Allow-Origin: *\r
        Cache-Control: no-store\r
        X-Content-Type-Options: nosniff\r
        Connection: close\r
        \r

        """.utf8) + body
    }

    /// Opens a stream that stays open; events follow.
    /// TV apps load from their own package, so any origin may read. The token decides who gets in.
    static let eventStreamHead = Data("""
    HTTP/1.1 200 OK\r
    Content-Type: text/event-stream; charset=utf-8\r
    Access-Control-Allow-Origin: *\r
    Cache-Control: no-store\r
    Connection: keep-alive\r
    \r
    retry: 2000


    """.utf8)
}
