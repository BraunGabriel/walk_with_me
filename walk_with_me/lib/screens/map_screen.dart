import 'dart:async';

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/campus_data.dart';
import '../models/highlight.dart';
import '../models/poi.dart';
import '../models/tour.dart';
import '../models/tour_progress.dart';
import '../models/walking_route.dart';
import '../services/directions_service.dart';
import '../services/highlight_tracker.dart';
import '../services/location_service.dart';
import '../services/route_follower.dart';
import '../utils/geo.dart';
import '../widgets/along_the_way_card.dart';
import '../widgets/poi_detail_sheet.dart';
import '../widgets/tour_panel.dart';

/// Center of GVSU's Allendale campus (near the Cook Carillon Tower).
const campusCenter = LatLng(42.9633, -85.8888);
const _campusZoom = 16.0;
const _stopZoom = 17.5;
const _followZoom = 18.0;

/// Within this distance of a stop, the walker has arrived.
const _arrivalRadiusMeters = 25.0;

/// Don't re-request directions more often than this while off route.
const _rerouteCooldown = Duration(seconds: 15);

/// How long an "along the way" card stays up on its own.
const _highlightDisplayTime = Duration(seconds: 20);

LatLng _latLngOf(Poi poi) => LatLng(poi.latitude, poi.longitude);

/// The campus map. With [startTour], it begins guiding that tour right away;
/// without, it's a free-roam map of every point of interest.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.data, this.startTour});

  final CampusData data;
  final Tour? startTour;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _locationService = LocationService();
  final _directions = DirectionsService();
  final _highlightTracker = HighlightTracker();

  AppleMapController? _controller;
  StreamSubscription<Position>? _positionSub;
  List<Poi> get _pois => widget.data.pois;
  List<Highlight> get _highlights => widget.data.highlights;
  bool _locationEnabled = false;
  Position? _position;
  double _heading = 0;
  TourProgress? _progress;

  // Navigation to the current stop.
  RouteFollower? _follower;
  RouteState? _routeState;
  bool _routing = false;
  DateTime? _lastRouteRequest;
  bool _arrived = false;

  /// Camera tracks the walker. Turned off when they pan the map.
  bool _following = false;

  Highlight? _activeHighlight;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final locationOk = await _locationService.ensurePermission();
    if (!mounted) return;
    setState(() => _locationEnabled = locationOk);
    if (widget.startTour case final tour?) _startTour(tour);
    if (locationOk) {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).listen(_onPosition);
    }
  }

  // ---- Live position ------------------------------------------------------

  void _onPosition(Position p) {
    // Course is only meaningful while moving.
    if (p.speed > 0.5 && p.heading >= 0) _heading = p.heading;
    setState(() => _position = p);

    final progress = _progress;
    if (progress == null) return;
    final here = LatLng(p.latitude, p.longitude);

    // Route progress.
    final follower = _follower;
    if (follower == null) {
      if (!_routing) _fetchRoute();
    } else {
      final state = follower.update(here);
      setState(() => _routeState = state);
      if (state.isOffRoute && !_arrived) _reroute();
    }

    // Arrival.
    if (!_arrived &&
        distanceMeters(here, _latLngOf(progress.current)) <=
            _arrivalRadiusMeters) {
      HapticFeedback.heavyImpact();
      setState(() => _arrived = true);
    }

    // Things to point out along the way.
    final hits = _highlightTracker.check(
      here,
      _alongTheWayCandidates(progress),
    );
    if (hits.isNotEmpty) _showHighlight(hits.first);

    if (_following) _followCamera();
  }

  /// Highlights from highlights.json plus campus buildings that aren't stops
  /// on this tour (stops get their own arrival moment).
  Iterable<Highlight> _alongTheWayCandidates(TourProgress progress) sync* {
    yield* _highlights;
    for (final poi in _pois) {
      if (progress.indexOf(poi) < 0) yield Highlight.fromPoi(poi);
    }
  }

  // ---- Routing ------------------------------------------------------------

  /// Fetches a walking route to the current stop, from the walker's position
  /// or (without location) from the previous stop.
  Future<void> _fetchRoute() async {
    final progress = _progress;
    if (progress == null) return;
    final p = _position;
    final origin = p != null
        ? LatLng(p.latitude, p.longitude)
        : progress.isFirst
        ? null
        : _latLngOf(progress.stops[progress.index - 1]);
    if (origin == null) return;

    final target = progress.current;
    _routing = true;
    _lastRouteRequest = DateTime.now();
    if (mounted) setState(() {});
    final WalkingRoute route;
    try {
      route = await _directions.walkingRoute(origin, _latLngOf(target));
    } finally {
      _routing = false;
    }
    // Ignore if the tour moved on while we were waiting.
    if (!mounted || _progress?.current.id != target.id) return;

    final follower = RouteFollower(route);
    final now = _position;
    setState(() {
      _follower = follower;
      _routeState = now == null
          ? null
          : follower.update(LatLng(now.latitude, now.longitude));
    });
  }

  void _reroute() {
    final last = _lastRouteRequest;
    if (_routing ||
        (last != null && DateTime.now().difference(last) < _rerouteCooldown)) {
      return;
    }
    _fetchRoute();
  }

  void _clearRoute() {
    _follower = null;
    _routeState = null;
    _lastRouteRequest = null;
    _arrived = false;
  }

  // ---- Tour flow ----------------------------------------------------------

  void _startTour(Tour tour) {
    final stops = widget.data.stopsFor(tour);
    if (stops.isEmpty) return;
    _highlightTracker.reset();
    // Follow the walker; if there's no fix yet, the first one starts it.
    _following = _locationEnabled;
    _setProgress(TourProgress(tour: tour, stops: stops));
  }

  void _setProgress(TourProgress? progress) {
    setState(() {
      _progress = progress;
      _clearRoute();
      if (progress == null) {
        _following = false;
        _dismissHighlight();
      }
    });
    if (progress == null) return;
    _fetchRoute();
    if (_following && _position != null) {
      _followCamera();
    } else {
      _focus(progress.current);
    }
  }

  void _next() {
    final progress = _progress!;
    if (progress.isLast) {
      _finishTour();
    } else {
      _setProgress(progress.next());
    }
  }

  /// Ends the tour and returns to the home screen.
  void _endTour() {
    _setProgress(null);
    Navigator.of(context).maybePop();
  }

  Future<void> _finishTour() async {
    final tourName = _progress!.tour.name;
    _setProgress(null);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tour complete!'),
        content: Text('You finished the $tourName tour. Go Lakers!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _openDirections(Poi poi) async {
    final uri = Uri.https('maps.apple.com', '/', {
      'daddr': '${poi.latitude},${poi.longitude}',
      'dirflg': 'w', // walking
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Walking distance left: along the route when we have one, otherwise
  /// straight-line.
  double? _remainingMeters(Poi poi) {
    final state = _routeState;
    if (state != null && !state.isOffRoute) return state.remainingMeters;
    final p = _position;
    if (p == null) return null;
    return distanceMeters(LatLng(p.latitude, p.longitude), _latLngOf(poi));
  }

  // ---- Along the way ------------------------------------------------------

  void _showHighlight(Highlight h) {
    HapticFeedback.mediumImpact();
    _highlightTimer?.cancel();
    _highlightTimer = Timer(_highlightDisplayTime, () {
      if (mounted) setState(_dismissHighlight);
    });
    setState(() => _activeHighlight = h);
  }

  void _dismissHighlight() {
    _highlightTimer?.cancel();
    _activeHighlight = null;
  }

  // ---- Camera -------------------------------------------------------------

  void _followCamera() {
    final p = _position;
    if (p == null) return;
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(p.latitude, p.longitude),
          zoom: _followZoom,
          heading: _heading,
        ),
      ),
    );
  }

  void _startFollowing() {
    setState(() => _following = true);
    _followCamera();
  }

  /// Zooms out to show the walker and the current stop together.
  void _showOverview(TourProgress progress) {
    setState(() => _following = false);
    final p = _position;
    final stop = _latLngOf(progress.current);
    if (p == null) {
      _focus(progress.current);
      return;
    }
    final here = LatLng(p.latitude, p.longitude);
    _controller?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            here.latitude < stop.latitude ? here.latitude : stop.latitude,
            here.longitude < stop.longitude ? here.longitude : stop.longitude,
          ),
          northeast: LatLng(
            here.latitude > stop.latitude ? here.latitude : stop.latitude,
            here.longitude > stop.longitude ? here.longitude : stop.longitude,
          ),
        ),
        80,
      ),
    );
  }

  void _focus(Poi poi) {
    _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(_latLngOf(poi), _stopZoom),
    );
  }

  void _recenter() {
    _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(campusCenter, _campusZoom),
    );
  }

  // ---- Map overlays -------------------------------------------------------

  Set<Annotation> get _annotations {
    final progress = _progress;
    return {
      for (final poi in _pois) _annotationFor(poi, progress),
      if (progress != null)
        for (final h in _highlights)
          Annotation(
            annotationId: AnnotationId('highlight:${h.id}'),
            position: LatLng(h.latitude, h.longitude),
            icon: BitmapDescriptor.defaultAnnotationWithHue(
              BitmapDescriptor.hueViolet,
            ),
            alpha: 0.8,
            infoWindow: InfoWindow(title: h.title, snippet: h.text),
          ),
    };
  }

  Annotation _annotationFor(Poi poi, TourProgress? progress) {
    var icon = BitmapDescriptor.defaultAnnotation;
    var alpha = 1.0;
    var title = poi.name;

    if (progress != null) {
      final stopIndex = progress.indexOf(poi);
      if (stopIndex < 0) {
        alpha = 0.35; // not part of this tour
      } else {
        title = '${stopIndex + 1}. ${poi.name}';
        if (poi.id == progress.current.id) {
          icon = BitmapDescriptor.markerAnnotationWithHue(
            BitmapDescriptor.hueAzure,
          );
        } else if (progress.isVisited(poi)) {
          icon = BitmapDescriptor.defaultAnnotationWithHue(
            BitmapDescriptor.hueGreen,
          );
        }
      }
    }

    return Annotation(
      annotationId: AnnotationId(poi.id),
      position: _latLngOf(poi),
      icon: icon,
      alpha: alpha,
      infoWindow: InfoWindow(title: title),
      onTap: () => _showPoi(poi),
    );
  }

  Set<Polyline> get _polylines {
    final progress = _progress;
    if (progress == null) return const {};
    final primary = Theme.of(context).colorScheme.primary;
    final route = _follower?.route;
    final routePoints = _routeState?.remaining ?? route?.points;
    return {
      // Faint outline of the whole tour, for context.
      if (progress.stops.length >= 2)
        Polyline(
          polylineId: PolylineId('tour-${progress.tour.id}'),
          points: [for (final s in progress.stops) _latLngOf(s)],
          color: primary.withValues(alpha: 0.3),
          width: 3,
          patterns: [PatternItem.dash(8), PatternItem.gap(6)],
        ),
      // The walking path to the next stop.
      if (route != null && routePoints != null && routePoints.length >= 2)
        Polyline(
          polylineId: PolylineId('route'),
          points: routePoints,
          color: primary,
          width: 6,
          patterns: route.isApproximate
              ? [PatternItem.dash(12), PatternItem.gap(8)]
              : const [],
        ),
    };
  }

  void _showPoi(Poi poi) {
    PoiDetailSheet.show(context, poi);
  }

  Poi? _poiById(String? id) {
    if (id == null) return null;
    for (final p in _pois) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---- Build --------------------------------------------------------------

  Widget? _buildFab(TourProgress? progress) {
    if (progress == null) {
      return FloatingActionButton.small(
        onPressed: _recenter,
        tooltip: 'Back to campus',
        child: const Icon(Icons.school),
      );
    }
    if (_position == null) {
      return FloatingActionButton.small(
        onPressed: () => _focus(progress.current),
        tooltip: 'Show current stop',
        child: const Icon(Icons.place),
      );
    }
    return _following
        ? FloatingActionButton.small(
            onPressed: () => _showOverview(progress),
            tooltip: 'Show route overview',
            child: const Icon(Icons.zoom_out_map),
          )
        : FloatingActionButton.extended(
            onPressed: _startFollowing,
            tooltip: 'Follow me',
            icon: const Icon(Icons.navigation),
            label: const Text('Follow me'),
          );
  }

  /// Opens on the tour's first stop when starting a tour, else campus.
  CameraPosition get _initialCamera {
    final tour = widget.startTour;
    final first = tour == null ? null : widget.data.stopsFor(tour).firstOrNull;
    return first == null
        ? const CameraPosition(target: campusCenter, zoom: _campusZoom)
        : CameraPosition(target: _latLngOf(first), zoom: _stopZoom);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final highlight = _activeHighlight;
    final highlightPoi = _poiById(highlight?.poiId);
    return Scaffold(
      appBar: AppBar(title: Text(progress?.tour.name ?? 'Campus Map')),
      body: Stack(
        children: [
          // Dragging the map hands camera control back to the user.
          Listener(
            onPointerMove: (_) {
              if (_following) setState(() => _following = false);
            },
            child: AppleMap(
              initialCameraPosition: _initialCamera,
              onMapCreated: (controller) => _controller = controller,
              annotations: _annotations,
              polylines: _polylines,
              myLocationEnabled: _locationEnabled,
              myLocationButtonEnabled: _locationEnabled && progress == null,
              compassEnabled: true,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -1.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: highlight == null
                    ? const SizedBox.shrink()
                    : AlongTheWayCard(
                        key: ValueKey(highlight.id),
                        highlight: highlight,
                        onDismiss: () => setState(_dismissHighlight),
                        onMore: highlightPoi == null
                            ? null
                            : () => _showPoi(highlightPoi),
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(progress),
      bottomNavigationBar: progress == null
          ? null
          : TourPanel(
              progress: progress,
              distanceMeters: _remainingMeters(progress.current),
              arrived: _arrived,
              rerouting: _routing && _follower != null,
              onPrevious: () => _setProgress(progress.previous()),
              onNext: _next,
              onDetails: () => _showPoi(progress.current),
              onDirections: () => _openDirections(progress.current),
              onEnd: _endTour,
            ),
    );
  }
}
