import Foundation

extension SagaUpdateReminderService {
  /// Uses local preferences, isolated by App Store ID. Supply a suite for isolated host tests.
  public init(
    appStoreID: Int,
    policy: SagaUpdateReminderPolicy = SagaUpdateReminderPolicy(),
    storageSuiteName: String? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    precondition(appStoreID > 0)
    self.init(
      policy: policy,
      repository: SagaUpdateReminderRepository(
        appStoreID: appStoreID,
        store: UserDefaultsUpdateCacheStore(suiteName: storageSuiteName)
      ),
      now: now
    )
  }
}
