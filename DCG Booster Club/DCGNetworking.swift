import Foundation

// Shared request/decode/error-handling used by every DCG API service, so a
// fix (e.g. timeout, status handling, cancellation detection) only needs to
// be made once.
enum DCGNetworking {
    static func fetchJSON<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("DCGTV: \(url.lastPathComponent) returned HTTP \(httpResponse.statusCode)")
            throw NSError(
                domain: "DCGTV",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(httpResponse.statusCode)"]
            )
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return error is CancellationError ||
            (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
    }
}
