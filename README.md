# DeepSeekCard

A native macOS menu bar app that shows whether DeepSeek API pricing is currently
**PEAK** or **OFFPEAK**, and — on hover — when it switches and why the off-peak
rate applies.

<!-- screenshot placeholder -->

## How it works

- The menu bar shows `PEAK` or `OFFPEAK`. The **color** says why: red for peak,
  green for a plain weekday off-peak, dark green for a weekend, blue for a Chinese
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
| Red | Peak |
| Green | Off-peak — weekday |
| Dark green | Off-peak — weekend |
| Blue | Off-peak — Chinese public holiday |

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

## Holiday data

The calendar lives in **`holidays.json` at the repo root** — one flat array
holding every year:

```json
[
  { "date": "2026-10-01", "name": "National Day" },
  { "date": "2027-02-06", "name": "Spring Festival" }
]
```

Only the official *off days* belong there. Makeup workdays stay out, because the
rule is "Mon–Fri minus holidays" — a Saturday declared a workday is still
off-peak.

`scripts/build.sh` copies the file into
`DeepSeekCard.app/Contents/Resources/holidays.json`, and that bundled copy is what
the app reads. Adding a year is a one-file edit plus a rebuild:

```sh
$EDITOR holidays.json && scripts/build.sh
```

The data currently covers **2026**; add each new year the same way once China's
State Council publishes it (every October).

### Your own additions

The card's **Edit Holidays** button opens
`~/.config/deepseek-card/holidays.json`. On the first click — or if that file is
empty — it is filled with a copy of the shipped list, so you open the whole
calendar and can edit names, add days, or fix dates in place.

Entries there are merged over the shipped ones: same shape, and where a date's name
differs from the shipped one, yours wins. **Identical copies are ignored rather
than treated as overrides**, so seeding the file does not freeze it — when
`holidays.json` later gains a day, you still get it. Use the user file for a one-off
date without rebuilding; keep long-lived changes in `holidays.json`, which is the
source of truth.

The card tells you what it is doing: `Using 2 dates from …` when your file is
contributing something, and a reminder while a year is still an estimate. Both
files are re-read as soon as their modification time changes, and at each UTC day
boundary — so saving a file takes effect immediately, no restart.

### The list

**2026** — the official arrangement (State Council notice
[gov.cn/zhengce/zhengceku/202511/content_7047091.htm](https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm)),
33 off-days:

| Holiday | Dates | Days |
|---|---|---|
| New Year's Day | 1–3 Jan | 3 |
| Spring Festival | 15–23 Feb | 9 |
| Qingming Festival | 4–6 Apr | 3 |
| Labor Day | 1–5 May | 5 |
| Dragon Boat Festival | 19–21 Jun | 3 |
| Mid-Autumn Festival | 25–27 Sep | 3 |
| National Day | 1–7 Oct | 7 |

**2027** — **provisional**, 18 off-days, taken from
[timeanddate.com/holidays/china/2027](https://www.timeanddate.com/holidays/china/2027)
(the State Council publishes its arrangement in the autumn, so re-check this table
then):

| Holiday | Dates | Days |
|---|---|---|
| New Year's Day | 1 Jan | 1 |
| Spring Festival | 5–11 Feb | 7 |
| Qingming Festival | 5 Apr | 1 |
| Labor Day | 1 May | 1 |
| Dragon Boat Festival | 9 Jun | 1 |
| Mid-Autumn Festival | 15 Sep | 1 |
| National Day | 1–6 Oct | 6 |

> ⚠️ The 2027 rows are estimates and the **golden weeks are the weak spot**: China
> normally stretches Labour Day and National Day, and in 2026 they were 5 and 7 days
> rather than the 1 and 6 shown here. So 2–5 May and 7 Oct 2027 may well be off-peak
> too — until the official notice lands, treat those particular days as unknown and
> the widget as optimistic about them.
>
> The widget itself says so: while a year is listed in `HolidayTable.provisionalYears`
> (`Sources/DeepSeekCardCore/HolidayTable.swift`), the card shows a reminder — from
> October it starts nudging about the year ahead. When the notice does land:
> replace the 2027 block in `holidays.json`, remove `2027` from `provisionalYears`,
> and re-run `scripts/build.sh`.

Dates are the calendar dates DeepSeek's rule cares about (the file stores them as
ISO `YYYY-MM-DD`).

## Quit

Open the card and press **Quit**, or kill the process.

## Notes

- Strictly cosmetic about time zones: all rules are evaluated in UTC, and only the
  displayed switch time is converted to your local zone.
- `nextSwitch` is the next *peak ↔ offpeak* change, not the next segment change —
  so at Friday 23:30 it counts down to Monday 01:00 UTC rather than announcing a
  weekend that is already off-peak.
