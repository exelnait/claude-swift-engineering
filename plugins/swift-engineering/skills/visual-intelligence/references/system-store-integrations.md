# System Store Integrations — receiving data from Visual Intelligence

> These capabilities are part of the 2026 releases and newer than this guidance's training data. Confirm availability and exact API (type names, initializers) against current Apple documentation.

Image Search is your app **providing** results to Visual Intelligence. This is the other direction: Visual Intelligence **produces** data — a calendar event from a poster, a contact from a business card, a reading from a medical-device display — and writes it to a **shared system store**. Your app reads that store as it normally would.

The key idea: **you don't integrate with Visual Intelligence here at all.** If your app already reads one of these frameworks' stores, Visual Intelligence becomes a new input source **automatically**. Add a change observer so entries it creates show up without a relaunch.

| Data | Framework | Store | Example capture |
|------|-----------|-------|-----------------|
| Calendar events | EventKit | `EKEventStore` | A social post about an upcoming concert |
| Contacts | Contacts | `CNContactStore` | A business card |
| Medical-device readings | HealthKit | `HKHealthStore` | A blood-pressure monitor, glucose meter, or weight scale display |

## Events via EventKit

Request access, query upcoming events, filter to what your app cares about, and — critically — register a change observer so **Visual Intelligence-created events appear automatically**.

```swift
import EventKit

@MainActor
final class UpcomingConcertManager: ObservableObject {
    private let store = EKEventStore()
    @Published var concerts: [EKEvent] = []

    func start(catalogArtists: Set<String>) async {
        // 1. Request access to the calendar.
        guard (try? await store.requestFullAccessToEvents()) == true else { return }  // confirm exact access API

        // 2. Load now...
        reload(catalogArtists: catalogArtists)

        // 3. ...and reload whenever the store changes — this fires for VI-created events too.
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,   // confirm exact notification name
            object: store, queue: .main
        ) { [weak self] _ in
            self?.reload(catalogArtists: catalogArtists)
        }
    }

    private func reload(catalogArtists: Set<String>) {
        let start = Date()
        let end = Calendar.current.date(byAdding: .month, value: 3, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)

        // Filter to near-future events matching artists in the catalog.
        concerts = store.events(matching: predicate).filter { event in
            guard let title = event.title else { return false }
            return catalogArtists.contains { title.localizedCaseInsensitiveContains($0) }
        }
    }
}
```

Result: capture a post about a concert, use Visual Intelligence to add it to the calendar, and it shows up in the app's Upcoming Concerts on next open — no direct Visual Intelligence code involved.

## Contacts via Contacts

The same pattern. Contacts added through Visual Intelligence (e.g. from a scanned business card) are read through `CNContactStore`.

```swift
import Contacts

let store = CNContactStore()
try await store.requestAccess(for: .contacts)   // confirm exact async access API

let keys = [CNContactGivenNameKey, CNContactFamilyNameKey,
            CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
let request = CNContactFetchRequest(keysToFetch: keys)
try store.enumerateContacts(with: request) { contact, _ in
    // Includes contacts Visual Intelligence added.
}

// Refresh automatically on store changes:
NotificationCenter.default.addObserver(
    forName: .CNContactStoreDidChange,   // confirm exact notification name
    object: nil, queue: .main
) { _ in /* re-fetch */ }
```

## Medical-device readings via HealthKit

Readings Visual Intelligence captures from device displays — blood-pressure monitors, glucose meters, weight scales — are written to HealthKit and queried with `HKHealthStore`. If your health or fitness app already reads HealthKit, Visual Intelligence becomes another way for people to log data without manual entry.

```swift
import HealthKit

let store = HKHealthStore()

// Types VI can log from device displays — confirm exact quantity-type identifiers:
let readTypes: Set<HKObjectType> = [
    HKQuantityType(.bloodPressureSystolic),
    HKQuantityType(.bloodPressureDiastolic),
    HKQuantityType(.bloodGlucose),
    HKQuantityType(.bodyMass),
]
try await store.requestAuthorization(toShare: [], read: readTypes)

// Read with your usual HKQuery / HKAnchoredObjectQuery / HKObserverQuery.
// VI-logged samples appear alongside manual and paired-device entries.
```

An `HKObserverQuery` (with background delivery) is the HealthKit equivalent of the notification observers above — it fires when new samples, including Visual Intelligence-logged ones, arrive.

## Requirements

- Each framework needs its **usage-description** Info.plist keys (e.g. `NSCalendarsFullAccessUsageDescription`, `NSContactsUsageDescription`, `NSHealthShareUsageDescription`) and, for HealthKit, the HealthKit capability. Confirm the exact key names against current Apple documentation.
- Access is user-granted and revocable — handle the not-authorized path.
- These are ordinary framework integrations. Nothing here is Visual Intelligence-specific beyond the fact that Visual Intelligence is now one of the writers.

## Related

- `references/image-search.md` — the *other* integration point (providing results to Visual Intelligence).
- `security` skill — permission prompts, usage strings, and handling revoked access.
