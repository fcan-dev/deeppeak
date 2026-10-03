# DeepSeekCard

A native macOS menu bar app that shows whether DeepSeek API pricing is currently
**PEAK** or **OFFPEAK**, and — on hover — when it switches and why the off-peak
rate applies.

<!-- screenshot placeholder -->

## How it works

- The menu bar shows `PEAK` or `OFFPEAK`. The **color** says why: amber for peak,
  green for a plain weekday off-peak, blue for a weekend, purple for a Chinese
  public holiday.
- Hover over it to reveal the card: a status dot, the current phase, a live
  countdown to the next switch (`switches to PEAK in 4d 18h · 04:00`), a chip
  naming the reason (`WEEKEND`, `National Day`, …), and the local time of the
  next switch.
- Everything is computed locally from UTC time plus a static holiday calendar.
  There is no network access of any kind.

## The rules

DeepSeek's peak hours are **01:00–04:00** and **06:00–10:00 UTC, Monday through
Friday, excluding Chinese public holidays** — everything else is off-peak.

| Band | UTC hours | Days |
|---|---|---|
| Peak | 01:00–04:00, 06:00–10:00 | Mon–Fri, excluding Chinese public holidays |
| Off-peak | all other hours | weekends and Chinese public holidays, in full |

Notes:

- A weekday that is a Chinese public holiday is off-peak all day.
- A weekend day that is also a holiday shows the holiday (holiday beats weekend).
- Makeup workdays are ignored: the rule is "Mon–Fri minus holidays", so a
  Saturday declared a workday is still off-peak.

## Colors

| Color | Meaning |
|---|---|
| Amber | Peak |
| Green | Off-peak — weekday |
| Blue | Off-peak — weekend |
| Purple | Off-peak — Chinese public holiday |

## Requirements

- macOS 14+ (Apple Silicon or Intel).
- Nothing else. No SSH, no API key, no network.

## Download

There are no prebuilt binaries on this repository yet — build it locally (below).

If you do publish one, note that `scripts/build.sh` produces a **thin arm64** build; for a
universal binary use:

```sh
swift build -c release --arch arm64 --arch x86_64
```

Apps built here are ad-hoc signed (not notarized), so on first launch macOS will show an
"unidentified developer" warning: right-click the app → **Open** → **Open** to get past it
(one time only).

## Build

```sh
scripts/build.sh          # produces dist/DeepSeekCard.app
open dist/DeepSeekCard.app
```

For development, run it straight from the source:

```sh
swift run DeepSeekCard
```

## Config

DeepSeekCard reads `~/.config/deepseek-card/holidays-<year>.json`. It is created
from the built-in calendar on first run:

```json
[
  {
    "date" : "2026-10-01",
    "name" : "National Day"
  }
]
```

Only the official *off days* belong in this file. The file is re-read on the
first tick of each new UTC day, so edits are picked up without a restart. Use the
card's **Edit Holidays** button to open it.

The built-in data currently covers **2026**. Each October, when China's State
Council publishes the next year's calendar, add `holidays-<year>.json` (and the
matching entry in `Sources/DeepSeekCardCore/EmbeddedHolidays.swift`).

## Quit

Open the card and press **Quit**, or kill the process.

## Notes

- Strictly cosmetic about time zones: all rules are evaluated in UTC, and only the
  displayed switch time is converted to your local zone.
- `nextSwitch` is the next *peak ↔ offpeak* change, not the next segment change —
  so at Friday 23:30 it counts down to Monday 01:00 UTC rather than announcing a
  weekend that is already off-peak.
