import 'package:flutter/material.dart';

import '../models/poi.dart';

/// Bottom sheet showing details for a point of interest. Scrolls and can be
/// dragged taller, so descriptions can be as long as needed (paragraphs are
/// separated by blank lines — "\n\n" — in pois.json).
class PoiDetailSheet extends StatelessWidget {
  const PoiDetailSheet({
    super.key,
    required this.poi,
    required this.scrollController,
  });

  final Poi poi;
  final ScrollController scrollController;

  /// Opens the sheet for [poi].
  static Future<void> show(BuildContext context, Poi poi) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (_, controller) =>
            PoiDetailSheet(poi: poi, scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(poi.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(label: Text(poi.category)),
        ),
        const SizedBox(height: 12),
        Text(
          poi.description,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
      ],
    );
  }
}
