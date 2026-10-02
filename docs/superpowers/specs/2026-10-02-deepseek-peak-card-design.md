# DeepSeekCard — Design Spec

A native macOS menu bar app that shows whether DeepSeek API pricing is
currently **PEAK** or **OFFPEAK**, with color and a hover card encoding *why*
it is off-peak (weekday, weekend, or Chinese public holiday).

No network access: the whole computation is local UTC time math plus a static
per-year Chinese holiday table.

## 1. Purpose & success criteria

- The menu bar always shows the current DeepSeek pricing phase at a glance.
- Hovering reveals when the phase changes and, if off-peak, why (weekend vs.
  Chinese public holiday).
- Matches the look/feel and engineering patterns of the existing
  `fcan-dev/gpu_stat_card` app (same hover-popover mechanism, same build
  flow, same config location convention).

## 2. The rules (DeepSeek pricing policy)

- **Peak hours:** 01:00–04:00 UTC and 06:00–10:00 UTC, **Monday through
  Friday**, *excluding Chinese public holidays*.
- **Off-peak:** everything else — all other weekday hours, all of Saturday
  and Sunday, and Chinese public holidays in full.
- Consequences:
  - A weekday that is a Chinese public holiday → OFFPEAK (holiday), all day.
  - A weekend day (Sat/Sun) → OFFPEAK (weekend), all day.
  - A weekend day that is *also* a Chinese holiday → holiday wins (the chip
    shows the holiday name).
  - Makeup workdays (weekend days officially declared as workdays) stay
    OFFPEAK — the rule is "Mon–Fri minus holidays", so we ignore
    `isOffDay: false` entries entirely.

## 3. Architecture

Swift Package, macOS 14+, two targets mirroring gpu_stat_card:

```
deepseek_offpeak/
├── Package.swift
├── Sources/
│   ├── DeepSeekCardCore/        # pure logic, no UI
│   │   ├── Phase.swift          # phase + reason enum, colors
│   │   ├── DaySchedule.swift    # day → segments
│   │   ├── HolidayTable.swift   # load/parse holiday JSON, embedded 2026 default
│   │   ├── PeakClock.swift      # @Observable 1s ticker: now, current phase, next switch
│   │   └── EmbeddedHolidays.swift
│   └── DeepSeekCard/            # UI executable
│       ├── DeepSeekCardApp.swift
│       ├── StatusItemController.swift   # hover popover (copied pattern)
│       ├── StatusBarLabel.swift         # PEAK / OFFPEAK text
│       └── CardView.swift               # hover card
├── Tests/
│   └── DeepSeekCardCoreTests/
├── scripts/build.sh
├── packaging/Info.plist
└── README.md
```

- `DeepSeekCardCore` has zero dependencies on AppKit/SwiftUI — fully
  unit-testable with fixed inputs.
- `PeakClock` is the only stateful object: a `@MainActor @Observable` class
  with a repeating 1-second task that updates `now`. Everything else is
  derived.

## 4. Core model

### Phase

```swift
public enum OffPeakReason: Equatable, Sendable {
    case weekday
    case weekend
    case chineseHoliday(String)   // holiday name
}

public enum Phase: Equatable, Sendable {
    case peak
    case offPeak(OffPeakReason)

    public var label: String      // "PEAK" / "OFFPEAK"
}
```

### DaySchedule (the day-segments approach)

For a given UTC day and a `HolidayTable`:

- Weekend day → single segment `00:00–24:00 .offPeak(.weekend)` (or
  `.offPeak(.chineseHoliday(name))` if it is also a holiday).
- Holiday weekday → single segment `00:00–24:00 .offPeak(.chineseHoliday(name))`.
- Normal weekday, in order:
  - `00:00–01:00` offPeak(.weekday)
  - `01:00–04:00` peak
  - `04:00–06:00` offPeak(.weekday)
  - `06:00–10:00` peak
  - `10:00–24:00` offPeak(.weekday)

All segment times are UTC, boundaries inclusive-start / exclusive-end
(01:00:00 is peak; 03:59:59.999 is peak; 04:00:00 is off-peak).

`DaySchedule.segments(forUTCDate:) -> [Segment]` and
`DaySchedule.phase(atUTCDate:) -> Phase` (scan today's segments; the next
phase boundary is always within 24h, so no multi-day scan is needed).

### HolidayTable

- Source: `~/.config/deepseek-card/holidays-<year>.json`, JSON array:
  `[{"date":"2026-10-01","name":"National Day"}, …]` (dates = the official
  `isOffDay: true` days only).
- File missing → auto-create it from the embedded default for that year
  (same "auto-create + show a note" behavior as gpu_stat_card's config).
- File present but invalid → use embedded default for that year, show a
  note in the card.
- Year has neither a file nor embedded data (e.g. 2027 before we add it) →
  treat as no holidays for that year, show a note:
  `"No holiday data for <year>; add holidays-<year>.json"`.
- Precedence for the displayed reason: holiday > weekend > weekday.

**Embedded 2026 default** (State Council notice 2025-11, verified against
NateScarlet/holiday-cn `2026.json`):

| Dates | Name |
|---|---|
| 2026-01-01 – 01-03 | New Year's Day |
| 2026-02-15 – 02-23 | Spring Festival |
| 2026-04-04 – 04-06 | Qingming Festival |
| 2026-05-01 – 05-05 | Labor Day |
| 2026-06-19 – 06-21 | Dragon Boat Festival |
| 2026-09-25 – 09-27 | Mid-Autumn Festival |
| 2026-10-01 – 10-07 | National Day |

(Makeup workdays — e.g. 2026-01-04, 2026-02-14, 2026-02-28 — are
deliberately *not* in the table; see §2.)

### PeakClock

```swift
@MainActor @Observable
public final class PeakClock {
    public private(set) var now: Date
    public private(set) var holidayNote: String?
    // derived, recomputed on each tick:
    public var phase: Phase { … }
    public var nextSwitch: Date { … }   // UTC boundary of the next segment
}
```

1-second repeating `Task`. All math uses a UTC `Calendar`; display
conversion to local time happens in the UI layer only.

## 5. Menu bar

- Text `PEAK` or `OFFPEAK`, ~11pt bold, colored:
  - peak → **amber**
  - off-peak, weekday → **green**
  - off-peak, weekend → **blue**
  - off-peak, Chinese holiday → **purple**
- Rendered to `NSImage` via `ImageRenderer` inside `StatusItemController`,
  re-rendered only when `phase` (including reason) changes — same
  signature-based trick as gpu_stat_card. No countdown in the menu bar.

## 6. Card (hover popover)

Width 260, same structure as gpu_stat_card (header / hairline / content /
hairline / footer), 14pt padding:

- **Header:** 8pt dot in the current reason color · "DeepSeek" (13pt
  semibold) · subtitle in caption gray: local `EEE dd MMM · HH:mm`.
- **Main:** `PEAK` / `OFFPEAK` at 20pt bold in the reason color,
  centered.
- **Switch line:** `switches to OFFPEAK in 10h 52m · 04:00` — countdown
  (minute precision, live) plus the boundary in the user's local time.
- **Reason chip** (only when reason ≠ weekday): a small rounded chip with
  `WEEKEND` or the holiday name (e.g. `National Day`), tinted with the
  reason color. No chip for plain weekday off-peak or peak.
- **Note line** (only when non-nil): holiday-data note from `PeakClock`.
- **Footer:** `Edit Holidays` (opens the current year's JSON in the
  default app) and `Quit`, same `MenuItemButton` style as the reference app.

Hover behavior (show on enter, hide on exit, `MenuBarInteraction` state,
`makeKey` on the popover window) is copied verbatim from gpu_stat_card.

## 7. Error handling & edge cases

- No failure states from I/O: the only I/O is reading a small local JSON
  file; all failure paths degrade to "embedded data + note".
- DST changes: irrelevant to the computation (UTC); local-time display just
  uses the current local zone.
- Year rollover: holiday files are per-year; segments for a day are always
  available (weekday rules need no data).
- Clock jumping (user changes system time): the clock simply reflects the
  new `now` on the next tick; no special handling.

## 8. Testing (new `DeepSeekCardCoreTests` target, XCTest)

The reference app has no tests; this one earns them because the whole app
is one pure function of (time, holidays). Fixed-date test cases:

1. Weekday band boundaries at 00:59/01:00, 03:59/04:00, 05:59/06:00,
   09:59/10:00 UTC (inclusive-start semantics).
2. Normal weekday off-peak hours → `.offPeak(.weekday)`.
3. Saturday/Sunday all day → `.offPeak(.weekend)`.
4. Holiday on a weekday — 2026-10-05 (Monday, National Day) →
   `.offPeak(.chineseHoliday("National Day"))` all day, including
   02:00 UTC where a normal weekday would be peak.
5. Holiday on a weekend (2026-10-03 Saturday) → holiday reason wins.
6. `nextSwitch` from inside each band, including crossing midnight
   (e.g. Tue 23:00 UTC → Wed 01:00 UTC) and crossing into a holiday day.
7. Holiday file parsing: valid, invalid JSON, missing file → note strings.
8. Year without data → weekday rules still correct + note set.

## 9. Build & packaging

- `scripts/build.sh`: copied from gpu_stat_card, names changed to
  `DeepSeekCard` → `dist/DeepSeekCard.app`, ad-hoc signed.
- `packaging/Info.plist`: same as reference (LSUIElement/accessory app,
  no sandbox), bundle id `com.fcan-dev.deepseekcard`.
- README: same structure as the reference (how it works, rules table,
  config, build, quit, first-launch note for ad-hoc signing).
- No entitlements, no network, no dependencies beyond the system SDK.

## 10. Out of scope

- Pricing display (per-model $/1M tokens), schedule timeline, concurrency
  info — explicitly dropped during design (option A scope).
- 2027+ holiday data — added manually each October when the State Council
  publishes the calendar (one JSON drop + one embedded-default update).
- Intel/universal release builds beyond what `scripts/build.sh` does.
