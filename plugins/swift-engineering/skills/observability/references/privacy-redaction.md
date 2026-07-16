# Privacy & Redaction

Unified logs persist to disk and travel in sysdiagnoses. The logging system therefore **redacts dynamic values by default** — and your job is to opt specific, safe values into visibility, never to blanket-`.public` everything (Common Mistake #2).

## The default: dynamic values are private

```swift
logger.notice("Loaded user \(email)")        // → "Loaded user <private>"
logger.notice("Count is \(items.count)")      // dynamic number → also redacted by default
```

Any interpolated **dynamic** value is shown as `<private>` in release unless you mark it. Static string literals in the format are always visible (they're the message template). So the message text shows; the data doesn't — unless you say so.

## Privacy specifiers

```swift
logger.notice("user \(userID, privacy: .public)")               // visible — safe identifier
logger.notice("email \(email, privacy: .private)")              // <private> (explicit)
logger.notice("email \(email, privacy: .private(mask: .hash))") // stable hash — correlate w/o exposing
logger.notice("token \(token, privacy: .sensitive)")            // treated as private + extra care
```

- **`.public`** — visible in logs. Use **only** for non-sensitive values (counts, states, enum names, your own opaque ids that aren't PII).
- **`.private`** (default for dynamic values) — redacted to `<private>`.
- **`.private(mask: .hash)`** — logs a consistent hash instead of the value: you can tell "same user across two log lines" without ever seeing the user. The best choice for correlating PII.
- **`.sensitive`** — for especially sensitive data; redacted and flagged.

## What must never be `.public`

Treat as private/hashed by default:
- Personal data: names, emails, phone numbers, addresses, DOB.
- Credentials/secrets: tokens, passwords, API keys, session ids.
- User content: message bodies, notes, search queries, file names/paths (often reveal identity/content).
- Precise location, health, financial data.

Only make a value `.public` after asking "would I be comfortable with this in a stranger's sysdiagnose?"

## Errors and objects

`error.localizedDescription` is usually safe-ish to log `.public`, but **error payloads may embed user data** (a failing URL with a token query item, a decoding error quoting a value). Log the *type*/*code* publicly and details privately:

```swift
logger.error("request failed code=\(code, privacy: .public) detail=\(detail, privacy: .private)")
```

Never `.public` a whole request/response body or a raw `Error` whose associated values you haven't vetted.

## Auditing

- Grep for `privacy: .public` in review — each one is a deliberate decision that should be justifiable.
- Be suspicious of `.public` near anything named `email`, `name`, `token`, `path`, `query`, `body`, `user`.
- When in doubt, use `.private(mask: .hash)` — you keep correlation, lose exposure.
- Remember: `debug`-level logs aren't persisted by default, but don't rely on level for privacy — a developer streaming logs still sees `.public` values. Privacy is a data decision, not a level decision.

## Pitfalls

- **Blanket `.public`** to "make logs readable" → PII in sysdiagnose. Mark only safe values.
- **`.public` on file paths/URLs** → often contain usernames or tokens; redact or strip first.
- **Logging whole objects** (`\(user)`) → dumps every field; log specific safe fields.
- **Assuming redaction hides everything** → static format text is always visible; keep secrets out of the literal too.
