import Foundation

protocol UpdateCacheStoring: Sendable {
    func load(forKey key: String) -> Data?
    func save(_ data: Data, forKey key: String)
}

struct UserDefaultsUpdateCacheStore: UpdateCacheStoring {
    let suiteName: String?

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func load(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func save(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: key)
    }
}
