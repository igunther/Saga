import Foundation

struct UpdateReminderHistoryModel: Codable, Sendable {
  var lastPresentedAt: Date?
  var snoozedUntil: Date?
  var isIgnored = false
}

/// Owns persisted reminder history, separate from regional lookup caches and discovery events.
actor SagaUpdateReminderRepository {
  private let store: any UpdateCacheStoring
  private let key: String
  private var histories: [String: UpdateReminderHistoryModel]

  init(
    appStoreID: Int,
    store: any UpdateCacheStoring
  ) {
    self.store = store
    key = "SagaUpdates.Reminders.\(appStoreID)"
    if let data = store.load(forKey: key),
      let decoded = try? JSONDecoder()
        .decode(
          [String: UpdateReminderHistoryModel].self,
          from: data
        )
    {
      histories = decoded
    } else {
      histories = [:]
    }
  }

  func history(for version: String) -> UpdateReminderHistoryModel {
    histories[version] ?? UpdateReminderHistoryModel()
  }

  func recordPresentation(
    for version: String,
    at date: Date
  ) {
    histories[version, default: UpdateReminderHistoryModel()].lastPresentedAt = date
    persist()
  }

  func snooze(
    _ version: String,
    until date: Date
  ) {
    histories[version, default: UpdateReminderHistoryModel()].snoozedUntil = date
    persist()
  }

  func ignore(_ version: String) {
    histories[version, default: UpdateReminderHistoryModel()].isIgnored = true
    persist()
  }

  private func persist() {
    do {
      let data = try JSONEncoder().encode(histories)
      store.save(
        data,
        forKey: key
      )
    } catch {
      assertionFailure("Could not encode update reminder history: \(error)")
    }
  }
}
