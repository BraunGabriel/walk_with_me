// Looks up accurate coordinates for every point of interest in
// assets/data/pois.json using Apple Maps search (MapKit) — the same map data
// the app displays. Free, no API key.
//
// Usage (from the project folder; from inside tool/ use locate_pois.swift):
//   swift tool/locate_pois.swift            # report only, changes nothing
//   swift tool/locate_pois.swift --write    # also updates pois.json
//
// How each place is searched:
//   By default: "<name>, Grand Valley State University, Allendale, MI".
//   If Apple picks the wrong place, add a "search" field to that POI in
//   pois.json, e.g. "search": "Lubbers Stadium Allendale". The app ignores it.
//
// Always eyeball the results: Apple returns one point per place, usually the
// building's center, not necessarily the entrance you want people to walk to.

import CoreLocation
import Foundation
import MapKit

/// pois.json, found relative to this script (tool/ → project root), so it
/// works from any folder.
let poiPath: String = {
  let script = URL(
    fileURLWithPath: #filePath,
    relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
  return script.standardizedFileURL
    .deletingLastPathComponent()  // tool/
    .deletingLastPathComponent()  // project root
    .appendingPathComponent("assets/data/pois.json").path
}()
let campusCenter = CLLocation(latitude: 42.9633, longitude: -85.8888)
/// Results farther than this from campus are rejected as the wrong place.
let maxDistanceFromCampus = 2_500.0
/// Moves bigger than this get flagged for a closer look.
let suspiciousMove = 400.0

let write = CommandLine.arguments.contains("--write")

guard let data = FileManager.default.contents(atPath: poiPath),
  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
  let pois = root["pois"] as? [[String: Any]]
else {
  fputs("Couldn't read \(poiPath).\n", stderr)
  exit(1)
}

struct Found {
  let id: String
  let latitude: Double
  let longitude: Double
}

func search(_ query: String) async -> [MKMapItem] {
  let request = MKLocalSearch.Request()
  request.naturalLanguageQuery = query
  request.region = MKCoordinateRegion(
    center: campusCenter.coordinate,
    latitudinalMeters: 4_000,
    longitudinalMeters: 4_000)
  return (try? await MKLocalSearch(request: request).start().mapItems) ?? []
}

/// Words that identify a place, minus generic ones ("Hall", "Center", ...).
func distinctiveWords(_ name: String) -> [String] {
  let generic: Set<String> = [
    "the", "of", "and", "hall", "center", "centre", "building", "tower",
    "house", "pond", "stadium", "library", "arts", "science", "field",
  ]
  let words = name.lowercased()
    .components(separatedBy: CharacterSet.alphanumerics.inverted)
    .filter { $0.count >= 3 && !generic.contains($0) }
  // Names made only of generic words ("Performing Arts Center") fall back
  // to requiring all of their words.
  return words.isEmpty ? name.lowercased().split(separator: " ").map(String.init) : words
}

/// True if the result's name contains at least one distinctive word.
func nameMatches(_ resultName: String?, _ keywords: [String]) -> Bool {
  guard let resultName = resultName?.lowercased() else { return false }
  return keywords.contains { resultName.contains($0) }
}

func fmt(_ meters: Double) -> String {
  meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
}

var updates: [Found] = []
var notFound: [String] = []

print("Looking up \(pois.count) places with Apple Maps...\n")

for poi in pois {
  guard let id = poi["id"] as? String, let name = poi["name"] as? String,
    let oldLat = (poi["latitude"] as? NSNumber)?.doubleValue,
    let oldLng = (poi["longitude"] as? NSNumber)?.doubleValue
  else { continue }

  // A custom "search" wins; otherwise try progressively looser queries.
  let queries =
    (poi["search"] as? String).map { [$0] }
    ?? [
      "\(name), Grand Valley State University, Allendale, MI",
      "\(name) GVSU",
      "\(name) Allendale MI",
    ]
  let old = CLLocation(latitude: oldLat, longitude: oldLng)
  let keywords = distinctiveWords(name)

  // First result that's on/near campus AND actually named like the place
  // (so "Kindschi Hall" can't match a nearby parking lot).
  var match: MKMapItem?
  for query in queries {
    match = await search(query).first { item in
      item.location.distance(from: campusCenter) <= maxDistanceFromCampus
        && nameMatches(item.name, keywords)
    }
    if match != nil { break }
  }

  guard let match else {
    print("✗ \(name)\n    no match on campus — kept \(oldLat), \(oldLng)")
    print("    Try adding \"search\": \"<other name for it>\" to this POI, or set it by hand.\n")
    notFound.append(name)
    continue
  }

  let coord = match.location.coordinate
  let lat = (coord.latitude * 1_000_000).rounded() / 1_000_000
  let lng = (coord.longitude * 1_000_000).rounded() / 1_000_000
  let moved = match.location.distance(from: old)
  let flag = moved > suspiciousMove ? "⚠︎" : "✓"

  print("\(flag) \(name)")
  print("    Apple Maps: \(match.name ?? "?")")
  print("    \(lat), \(lng)   (moved \(fmt(moved)) from \(oldLat), \(oldLng))")
  if moved > suspiciousMove {
    print("    Big move — check this is the right place before trusting it.")
  }
  print("    check: https://maps.apple.com/?ll=\(lat),\(lng)&q=\(id)\n")
  updates.append(Found(id: id, latitude: lat, longitude: lng))
}

print("Found \(updates.count) of \(pois.count).", notFound.isEmpty ? "" : "Not found: \(notFound.joined(separator: ", ")).")

guard write else {
  print("\nNothing changed. Run with --write to update \(poiPath).")
  exit(0)
}

// Edit the file text in place (rather than re-serializing) so key order,
// formatting and everything else in pois.json stay exactly as written.
var text = String(decoding: data, as: UTF8.self)
for u in updates {
  let id = NSRegularExpression.escapedPattern(for: u.id)
  for (key, value) in [("latitude", u.latitude), ("longitude", u.longitude)] {
    let pattern = "(\"id\"\\s*:\\s*\"\(id)\"[^}]*?\"\(key)\"\\s*:\\s*)-?[0-9.]+"
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(text.startIndex..., in: text)
    text = regex.stringByReplacingMatches(
      in: text, range: range, withTemplate: "$1\(value)")
  }
}
try! text.write(toFile: poiPath, atomically: true, encoding: .utf8)
print("\nUpdated \(updates.count) places in \(poiPath). Review the changes, then stop and rerun the app.")
