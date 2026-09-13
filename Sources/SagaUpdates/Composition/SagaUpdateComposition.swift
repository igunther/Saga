import Foundation

public extension SagaUpdateService {
    init(configuration: SagaUpdateConfiguration) {
        self.init(
            configuration: configuration,
            repository: SagaUpdateRepository(
                appStoreID: configuration.appStoreID,
                countryCode: configuration.countryCode,
                lookup: AppStoreLookup(),
                store: UserDefaultsUpdateCacheStore(suiteName: nil)
            )
        )
    }
}

extension SagaUpdateService {
    init(configuration: SagaUpdateConfiguration, lookup: any AppStoreLooking, storageSuiteName: String) {
        self.init(
            configuration: configuration,
            repository: SagaUpdateRepository(
                appStoreID: configuration.appStoreID,
                countryCode: configuration.countryCode,
                lookup: lookup,
                store: UserDefaultsUpdateCacheStore(suiteName: storageSuiteName)
            )
        )
    }
}
