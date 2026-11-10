import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';

import '../models/campus_data.dart';
import '../models/poi.dart';
import '../models/tour.dart';
import '../widgets/poi_detail_sheet.dart';
import '../widgets/tour_panel.dart' show formatMiles;
import 'map_screen.dart';

/// Shows a tour before starting it: its buildings highlighted on the map
/// (numbered, with everything else faded) and the list of stops.
class TourPreviewScreen extends StatefulWidget {
  const TourPreviewScreen({super.key, required this.data, required this.tour});

  final CampusData data;
  final Tour tour;

  @override
  State<TourPreviewScreen> createState() => _TourPreviewScreenState();
}

class _TourPreviewScreenState extends State<TourPreviewScreen> {
  AppleMapController? _controller;
  late final List<Poi> _stops = widget.data.stopsFor(widget.tour);
  String? _selectedId;

  LatLng _at(Poi p) => LatLng(p.latitude, p.longitude);

  LatLngBounds get _stopBounds {
    var south = _stops.first.latitude, north = south;
    var west = _stops.first.longitude, east = west;
    for (final s in _stops) {
      if (s.latitude < south) south = s.latitude;
      if (s.latitude > north) north = s.latitude;
      if (s.longitude < west) west = s.longitude;
      if (s.longitude > east) east = s.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  Future<void> _onMapCreated(AppleMapController controller) async {
    _controller = controller;
    // Give the map a moment to lay out before fitting to the tour.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || _stops.isEmpty) return;
    controller.animateCamera(CameraUpdate.newLatLngBounds(_stopBounds, 60));
  }

  void _select(Poi poi) {
    setState(() => _selectedId = poi.id);
    _controller
      ?..animateCamera(CameraUpdate.newLatLngZoom(_at(poi), 17.5))
      ..showMarkerInfoWindow(AnnotationId(poi.id));
  }

  void _showDetails(Poi poi) {
    PoiDetailSheet.show(context, poi);
  }

  void _start() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(data: widget.data, startTour: widget.tour),
      ),
    );
  }

  Set<Annotation> get _annotations {
    final stopNumber = {
      for (var i = 0; i < _stops.length; i++) _stops[i].id: i + 1,
    };
    return {
      for (final poi in widget.data.pois)
        if (stopNumber[poi.id] case final n?)
          Annotation(
            annotationId: AnnotationId(poi.id),
            position: _at(poi),
            icon: BitmapDescriptor.markerAnnotationWithHue(
              poi.id == _selectedId
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(title: '$n. ${poi.name}'),
            onTap: () => setState(() => _selectedId = poi.id),
          )
        else
          Annotation(
            annotationId: AnnotationId(poi.id),
            position: _at(poi),
            alpha: 0.25,
            infoWindow: InfoWindow(
              title: poi.name,
              snippet: 'Not on this tour',
            ),
          ),
    };
  }

  Set<Polyline> get _polylines => {
    if (_stops.length >= 2)
      Polyline(
        polylineId: PolylineId('tour-${widget.tour.id}'),
        points: [for (final s in _stops) _at(s)],
        color: Theme.of(context).colorScheme.primary,
        width: 4,
        patterns: [PatternItem.dash(8), PatternItem.gap(6)],
      ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tour = widget.tour;
    final minutes = widget.data.approxWalkTime(tour).inMinutes.clamp(1, 999);

    return Scaffold(
      appBar: AppBar(title: Text(tour.name)),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: AppleMap(
              initialCameraPosition: CameraPosition(
                target: _stops.isEmpty ? campusCenter : _at(_stops.first),
                zoom: 16,
              ),
              onMapCreated: _onMapCreated,
              annotations: _annotations,
              polylines: _polylines,
            ),
          ),
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    tour.description,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '${_stops.length} stops · '
                    '~${formatMiles(widget.data.approxLengthMeters(tour))} · '
                    '~$minutes min walk',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
                for (var i = 0; i < _stops.length; i++)
                  ListTile(
                    selected: _stops[i].id == _selectedId,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      child: Text('${i + 1}'),
                    ),
                    title: Text(_stops[i].name),
                    subtitle: Text(_stops[i].category),
                    trailing: IconButton(
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'About ${_stops[i].name}',
                      onPressed: () => _showDetails(_stops[i]),
                    ),
                    onTap: () => _select(_stops[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _stops.isEmpty ? null : _start,
            icon: const Icon(Icons.directions_walk),
            label: const Text('Start tour'),
          ),
        ),
      ),
    );
  }
}
