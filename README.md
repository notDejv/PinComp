# PinComp

Personal iOS app for Teamfight Tactics players. Paste a TFT **Team Planner code**
(from TFT Academy, MetaTFT, the in-game planner, …), see the board, and pin the comp
to the Dynamic Island as a Live Activity so you can glance at it while playing TFT mobile.

## Data

`scripts/build_data.py` builds per-set champion data from [Community Dragon](https://www.communitydragon.org/):

- `data/index.json` — `{ "sets": [...], "latest": "TFTSet18" }`
- `data/<set>/champions.json` — champions with `id`, `name`, `cost`, `plannerCode`, `icon`

The `Data` workflow refreshes it daily and the `Pages` workflow publishes `data/` to
`https://notdejv.github.io/PinComp/`.

```sh
python3 scripts/build_data.py
```

## Building

Requires Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
The `.xcodeproj` is generated and not committed.

```sh
xcodegen generate
open PinComp.xcodeproj
```

Targets: `PinComp` (app, `com.dejvi.pincomp`) and `PinCompWidget` (Live Activity,
`com.dejvi.pincomp.widget`), sharing the App Group `group.com.dejvi.pincomp`.
Shared code lives in `Packages/PinCompKit`; its tests run with the `PinComp` scheme (⌘U).

### App icon

```sh
python3 scripts/icon/make_icon_svgs.py
swift scripts/icon/render_icon.swift
```

### TestFlight

1. Select the paid team for both targets (Signing & Capabilities) and bump `CURRENT_PROJECT_VERSION` in `project.yml`.
2. `xcodegen generate`, then Product → Archive with "Any iOS Device".
3. Organizer → Distribute App → TestFlight & App Store → Upload.
4. In App Store Connect, add testers to the build.

## Legal

PinComp isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games
or anyone officially involved in producing or managing Riot Games properties. Riot Games and
all associated properties are trademarks or registered trademarks of Riot Games, Inc.

Champion data from Community Dragon.
