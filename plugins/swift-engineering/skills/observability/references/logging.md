# Logging (OSLog / Logger)

`Logger` (the Swift face of `os_log`) is the structured, low-overhead, privacy-aware logging system. Create channels, log at meaningful levels, and read them back in Console.

## Create loggers

Scope each logger with a **subsystem** (usually your bundle id) and a **category** (the feature/area) so logs are filterable (Common Mistake #4):

```swift
import OSLog

extension Logger {
    static let sync    = Logger(subsystem: "com.example.trips", category: "sync")
    static let ui      = Logger(subsystem: "com.example.trips", category: "ui")
    static let storage = Logger(subsystem: "com.example.trips", category: "storage")
}

// Use:
Logger.sync.notice("Starting sync for \(tripCount, privacy: .public) trips")
```

A small, shared set of loggers keeps Console queries meaningful. Don't create ad-hoc loggers inline everywhere.

## Levels — and what they persist

Pick the level by severity; the level determines storage and surfacing:

| Level | Meaning | Persistence (default) |
|-------|---------|-----------------------|
| `debug` | Dev-only detail | Not persisted; only visible while actively streaming with debug enabled |
| `info` | Useful context | Persisted only while capturing / not to disk by default |
| `notice` (`log`/default) | Standard events worth keeping | Persisted to disk |
| `error` | Recoverable error | Persisted; higher retention |
| `fault` | Bug / broken invariant | Persisted; may trigger extra diagnostics |

```swift
Logger.sync.debug("payload: \(payload, privacy: .private)")   // dev troubleshooting
Logger.sync.notice("Sync completed in \(ms, privacy: .public) ms")
Logger.sync.error("Sync failed: \(error.localizedDescription, privacy: .public)")
Logger.storage.fault("Model context save returned no rows for a non-empty batch")
```

Logging all at one level defeats filtering (Common Mistake #3). Reserve `error`/`fault` for real problems — they carry heavier capture.

## Interpolation & format specifiers

`Logger` string interpolation is typed and supports formatting and privacy:

```swift
logger.notice("user \(id, privacy: .public) opened \(screen, privacy: .public)")
logger.info("progress \(fraction, format: .fixed(precision: 2), privacy: .public)")
logger.debug("bytes \(count, format: .decimal(minDigits: 4))")
logger.notice("flag \(isEnabled, privacy: .public)")   // Bool, Int, Double, String, and more are supported
```

- Dynamic values are **redacted by default** — see `privacy-redaction.md`. Add `privacy: .public` only when safe.
- `format:` gives `printf`-style control (precision, radix, alignment) without building strings yourself.

## Performance

Unified logging is designed to be cheap — arguments are captured and formatting is deferred — but it isn't free in tight loops (Common Mistake #6):

- Verbose per-iteration logging → keep at `debug`, or use signposts (built for high frequency — see `signposts-instruments.md`).
- The message string is a static format with interpolated args; avoid pre-building large strings just to log them.

## Viewing logs

- **Console.app** — live stream from device/simulator; filter by subsystem, category, level, process. Save filters for your subsystems.
- **`log` CLI** (macOS):
  ```bash
  log stream --predicate 'subsystem == "com.example.trips"' --level debug
  log show --predicate 'subsystem == "com.example.trips" && category == "sync"' --last 1h
  ```
- **sysdiagnose** — persisted logs (`notice`+ and `error`/`fault`) are included in device sysdiagnoses, so field issues can be diagnosed after the fact. This is also why leaking PII to persisted logs is dangerous (privacy reference).

## Getting logs programmatically (OSLogStore)

For in-app diagnostics/"export logs" features, read back your own entries:

```swift
let store = try OSLogStore(scope: .currentProcessIdentifier)
let position = store.position(date: Date().addingTimeInterval(-3600))
let entries = try store.getEntries(at: position)
    .compactMap { $0 as? OSLogEntryLog }
    .filter { $0.subsystem == "com.example.trips" }
```

Use this to build a "share diagnostics" flow rather than rolling your own file logger.

## Pitfalls

- **`print()`/`NSLog`** → invisible/unstructured in prod; use `Logger`.
- **Inline one-off loggers** → unfilterable; share a small set.
- **Wrong level** → either invisible (`debug` in prod) or noisy (`error` for routine events).
- **Huge pre-built strings** → wasted work; let interpolation defer formatting.
