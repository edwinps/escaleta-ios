# Escaleta

A daily planner for people who publish videos on several channels. It decides which channels need a video today, in what order, and what the next task is.

Everything is local: no network, no accounts. Data is stored in one JSON file.

## How it works

Each channel has a priority group (A, B or C) and a cadence (a video every N days). A video goes through five steps: topic, script, thumbnail, first edit and review, and is then published.

- A channel is *due* when its last publication plus its cadence falls on or before the end of today.
- Due channels are ordered by group, then by how overdue they are, then by name.
- Two steps are slow (thumbnail, first edit) and have an "in progress" state with timestamps.
- At most `maxConcurrentRenders` first edits can run at once.
- A video should not go out earlier than `minHoursBetweenVideos` after the previous one on the same channel. The app warns but lets you save it.
- The "Ahora" banner shows the single next task, chosen by the rules in `Planner.suggestion`.

## Layout

```
EscaletaKit/           Swift package with the business logic. Foundation only.
  Sources/EscaletaKit    models, planner, operations, JSON storage, seed data
  Tests/EscaletaKitTests
iOSApp/                Xcode project. The app target depends on the package.
  Escaleta/              entry point, AppModel (view model), SwiftUI views
```

The package knows nothing about the UI. The app target uses a synchronized folder, so any Swift file added under `iOSApp/Escaleta/` is compiled automatically.

On first launch the app creates 10 invented channels with a past publication each.

## Build and test

```bash
cd EscaletaKit
swift build
swift test
```

The tests cover `EscaletaKit` only. The SwiftUI code in the app has no automated tests.

## Run on iOS

Open `iOSApp/Escaleta.xcodeproj` in Xcode, pick an iPhone simulator and press Run. The app target links the `EscaletaKit` package from this repository.

To run on a real device, select your own team under Signing & Capabilities and change the bundle identifier (`com.example.escaleta` is a placeholder).

Data is stored in Application Support as `Escaleta/data.json`.

## License

MIT, see `LICENSE`.
