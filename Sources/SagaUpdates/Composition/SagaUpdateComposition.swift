import Foundation

public extension SagaUpdateService {
    init(configuration: SagaUpdateConfiguration) {
        self.init(configuration: configuration, lookup: AppStoreLookup(),
                  regionSource: StoreKitRegionSource(), store: UserDefaultsUpdateCacheStore(suiteName: nil))
    }
}

extension SagaUpdateService {
    init(configuration: SagaUpdateConfiguration, lookup: any AppStoreLooking, storageSuiteName: String) {
        self.init(configuration: configuration, lookup: lookup, regionSource: StoreKitRegionSource(),
                  store: UserDefaultsUpdateCacheStore(suiteName: storageSuiteName))
    }

    init(configuration: SagaUpdateConfiguration, lookup: any AppStoreLooking,
         regionSource: any StorefrontRegionSourcing, store: any UpdateCacheStoring) {
        self.init(configuration: configuration,
                  regionRepository: StorefrontRegionRepository(source: regionSource),
                  repositoryFactory: { country in
            SagaUpdateRepository(appStoreID: configuration.appStoreID, countryCode: country,
                                 lookup: lookup, store: store)
        })
    }
}
