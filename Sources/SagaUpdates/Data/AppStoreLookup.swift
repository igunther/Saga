import Foundation

struct AppStoreReleaseDTO: Decodable, Sendable {
    let trackId: Int
    let version: String
    let trackViewUrl: URL
}

private struct AppStoreLookupDTO: Decodable, Sendable {
    let resultCount: Int
    let results: [AppStoreReleaseDTO]
}

enum AppStoreLookupError: Error, Sendable {
    case unavailable
    case invalidResponse
    case transport
}

protocol AppStoreLooking: Sendable {
    func lookup(appStoreID: Int, countryCode: String) async throws -> AppStoreReleaseDTO
}

struct AppStoreLookup: AppStoreLooking {
    func lookup(appStoreID: Int, countryCode: String) async throws -> AppStoreReleaseDTO {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(appStoreID)),
            URLQueryItem(name: "country", value: countryCode),
        ]
        guard let url = components.url else { throw AppStoreLookupError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw AppStoreLookupError.transport
        }
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw AppStoreLookupError.transport
        }
        guard let decoded = try? JSONDecoder().decode(AppStoreLookupDTO.self, from: data),
              decoded.resultCount == decoded.results.count else {
            throw AppStoreLookupError.invalidResponse
        }
        guard let release = decoded.results.first(where: { $0.trackId == appStoreID }) else {
            throw AppStoreLookupError.unavailable
        }
        guard release.trackViewUrl.scheme?.lowercased() == "https" else {
            throw AppStoreLookupError.invalidResponse
        }
        return release
    }
}
