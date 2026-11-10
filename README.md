# Walk With Me

A virtual tour guide for **Grand Valley State University's Allendale campus**. Pick a tour, and the app walks you from stop to stop on a live map. It reads each stop aloud when you arrive and points out things you pass on the way.

Built with Flutter for iOS, using Apple Maps. There are no API keys, accounts, or paid services.

## Features

- **Guided tours.** Choose from curated tours (Campus Highlights, Academic Buildings, Laker Life). Each tour card shows its stops, length, and walking time.
- **Tour preview.** Before you start, see the tour's buildings highlighted and numbered on the map.
- **Turn-by-turn walking.** A live route follows real campus walkways to the next stop. The map follows you and shows the remaining distance and time, and it reroutes if you wander off.
- **Arrival narration.** When you reach a stop, the phone buzzes and reads the stop's description aloud. You can replay it with **Listen** or turn auto-reading off.
- **Along the way.** Pop-up cards point out landmarks, traditions, photo spots, and buildings you walk past.
- **Free exploring.** Browse every point of interest on the campus map without starting a tour.

## Getting started

### Requirements

- macOS with **Xcode** (includes the iOS Simulator)
- **Flutter** SDK (stable channel), see [install Flutter](https://docs.flutter.dev/get-started/install)
- **CocoaPods** (`brew install cocoapods`)
- iOS 15 or later

### Run it

```bash
git clone https://github.com/BraunGabriel/walk_with_me.git
cd walk_with_me
flutter pub get
cd ios && pod install && cd ..
flutter run
```

**In VS Code:** open the `walk_with_me` folder and press **F5**. The included launch configuration boots the iPhone simulator and runs the app on it. If you use a different simulator, put its ID (from `flutter devices`) in `.vscode/launch.json` and `.vscode/tasks.json`.

> **Blank white screen?** Debug builds only work when launched with `flutter run` or F5. Opening the app icon directly on the simulator shows a white screen. After adding a package, fully stop and rerun the app, because hot reload can't add native code.

### Try a tour without walking campus

The simulator can fake a walk. Start a tour in the app, then run:

```bash
tool/simulate_walk.sh highlights      # tour id from assets/data/tours.json
```

To stop it, run `xcrun simctl location booted clear`. The script walks in straight lines between stops, so expect to see the app reroute now and then.

## Editing tour content

All tour content lives in JSON files in [`assets/data/`](assets/data/). You don't need to change any code. After editing, **stop and rerun** the app; hot reload doesn't reload these files.

### Places: `pois.json`

Each building or landmark:

```json
{
  "id": "kirkhof",
  "name": "Kirkhof Center",
  "category": "student-life",
  "latitude": 42.962791,
  "longitude": -85.888571,
  "description": "The student union on GVSU's Allendale campus...\n\nSecond paragraph..."
}
```

- `id` is a unique name used by tours and highlights. Use lowercase with dashes.
- `description` is shown in the details sheet **and read aloud** on arrival. Write it the way it should sound, and separate paragraphs with `\n\n`. It can be as long as you like.
- `latitude` / `longitude` set where the pin goes. Arrival triggers within 25 m of this point, so place it at the entrance you want people to reach.

### Tours: `tours.json`

```json
{
  "id": "highlights",
  "name": "Campus Highlights",
  "description": "The must-see spots at the heart of the Allendale campus.",
  "stops": ["kirkhof", "library", "carillon"]
}
```

`stops` lists place `id`s from `pois.json` in walking order.

### Along-the-way highlights: `highlights.json`

Things to point out *between* stops:

```json
{
  "id": "little-mac-bridge",
  "title": "Little Mac Bridge",
  "text": "Students paint messages on this bridge...",
  "category": "tradition",
  "latitude": 42.9650,
  "longitude": -85.8925,
  "radius": 40,
  "poi": "kirkhof"
}
```

- `category` is optional and sets the card icon: `fact` (default), `tradition`, `photo-spot`.
- `radius` is optional: how close, in meters, the walker must get before the card shows. Defaults to 35.
- `poi` is optional: a place `id`, which adds a **More** button that opens that place's details.

Campus buildings that aren't on the current tour are pointed out automatically ("You're passing…"), so you don't need to add them here.

### Getting accurate coordinates

`tool/locate_pois.swift` looks up every place in `pois.json` by name in Apple Maps:

```bash
swift tool/locate_pois.swift           # report only: shows what it found
swift tool/locate_pois.swift --write   # updates pois.json
```

If it picks the wrong place, add a `"search"` field to that entry (for example `"search": "Haas Center Performing Arts"`) and run it again. Always check the results; the report includes an Apple Maps link for each one.

To find coordinates by hand, right-click a spot in Google Maps (the first menu item is the coordinates), or drop a pin in Apple Maps.

## Project structure

```
lib/
  main.dart                  App entry and GVSU theme
  screens/
    home_screen.dart         Welcome page and tour list
    tour_preview_screen.dart A tour's stops highlighted on a map
    map_screen.dart          Live map: following, routing, arrival, highlights
  widgets/                   Tour panel, details sheet, along-the-way card
  services/
    directions_service.dart  Walking routes (Apple MapKit, via native code)
    route_follower.dart      Progress along a route, off-route detection
    highlight_tracker.dart   When to point things out
    narration_service.dart   Text-to-speech
    location_service.dart    Location permission
  models/                    Places, tours, highlights, routes
  data/poi_repository.dart   Loads the JSON in assets/data/
ios/Runner/AppDelegate.swift Native bridge to Apple Maps walking directions
tool/                        Developer scripts (simulate a walk, locate places)
test/                        Unit and widget tests
```

## Tests

```bash
flutter test
```

The tests cover the route-following math and highlight triggers. They also check the bundled data: every tour stop must exist, IDs must be unique, coordinates must be on campus, and long descriptions must fit in the details sheet.

## Notes

- **iOS only.** The walking directions bridge and the map plugin are iOS-specific.
- **Location** is used only while the app is open ("When In Use"). It's sent only to Apple, to calculate walking routes. The app has no server of its own and stores nothing.
- **Before an App Store release,** change the bundle identifier from the default `com.example.walkWithMe`.
- The `apple_maps_flutter` plugin doesn't support Swift Package Manager yet, so Flutter prints a warning during builds. It's harmless for now.
