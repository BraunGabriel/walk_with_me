import Flutter
import MapKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WalkingDirections") {
      WalkingDirections.register(messenger: registrar.messenger())
    }
  }
}

/// Exposes MapKit walking directions to Dart over the
/// `walk_with_me/directions` method channel.
///
/// `walkingRoute` takes `{fromLat, fromLng, toLat, toLng}` and returns
/// `{points: [lat, lng, lat, lng, ...], distance: meters, duration: seconds}`.
enum WalkingDirections {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "walk_with_me/directions", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "walkingRoute" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Double],
        let fromLat = args["fromLat"], let fromLng = args["fromLng"],
        let toLat = args["toLat"], let toLng = args["toLng"]
      else {
        result(FlutterError(code: "bad_args", message: "Expected from/to coordinates", details: nil))
        return
      }
      calculate(
        from: CLLocationCoordinate2D(latitude: fromLat, longitude: fromLng),
        to: CLLocationCoordinate2D(latitude: toLat, longitude: toLng),
        result: result)
    }
  }

  private static func calculate(
    from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, result: @escaping FlutterResult
  ) {
    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
    request.transportType = .walking

    MKDirections(request: request).calculate { response, error in
      DispatchQueue.main.async {
        guard let route = response?.routes.first else {
          result(
            FlutterError(
              code: "no_route",
              message: error?.localizedDescription ?? "No walking route found",
              details: nil))
          return
        }
        let polyline = route.polyline
        var coords = [CLLocationCoordinate2D](
          repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        result([
          "points": coords.flatMap { [$0.latitude, $0.longitude] },
          "distance": route.distance,
          "duration": route.expectedTravelTime,
        ])
      }
    }
  }
}
