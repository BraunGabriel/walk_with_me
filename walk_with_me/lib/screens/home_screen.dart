import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/poi_repository.dart';
import '../models/campus_data.dart';
import '../models/tour.dart';
import '../widgets/tour_panel.dart' show formatMiles;
import 'map_screen.dart';
import 'tour_preview_screen.dart';

/// Landing page: a welcome, the list of tours, and a way into the free-roam
/// campus map.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<CampusData> _data = PoiRepository().loadAll();

  void _openMap(CampusData data) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => MapScreen(data: data)));
  }

  void _openTour(CampusData data, Tour tour) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TourPreviewScreen(data: data, tour: tour),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // White status bar text over the blue header.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      body: FutureBuilder<CampusData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _WelcomeHeader(
                  onExploreMap: data == null ? null : () => _openMap(data),
                ),
              ),
              if (snapshot.hasError)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text("Couldn't load campus tours.")),
                )
              else if (data == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Choose a tour',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: data.tours.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _SlideIn(
                      delay: Duration(milliseconds: 80 * i),
                      child: _TourCard(
                        data: data,
                        tour: data.tours[i],
                        onTap: () => _openTour(data, data.tours[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.onExploreMap});

  final VoidCallback? onExploreMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color.lerp(primary, Colors.black, 0.35)!],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.directions_walk, color: Colors.white, size: 40),
              const SizedBox(height: 16),
              Text(
                'Welcome, Laker!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Walk With Me is your guide to the Allendale campus. '
                'Pick a tour below and we\'ll walk you from stop to stop, '
                'pointing things out along the way.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onExploreMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Explore the campus map'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.data,
    required this.tour,
    required this.onTap,
  });

  final CampusData data;
  final Tour tour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stops = data.stopsFor(tour);
    final minutes = data.approxWalkTime(tour).inMinutes.clamp(1, 999);

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(tour.name, style: theme.textTheme.titleMedium),
                  ),
                  Icon(Icons.chevron_right, color: scheme.outline),
                ],
              ),
              const SizedBox(height: 4),
              Text(tour.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Stat(
                    icon: Icons.place_outlined,
                    text: '${stops.length} stops',
                  ),
                  _Stat(
                    icon: Icons.straighten,
                    text: '~${formatMiles(data.approxLengthMeters(tour))}',
                  ),
                  _Stat(icon: Icons.schedule, text: '~$minutes min walk'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                stops.map((s) => s.name).join('  →  '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Fades and slides a child up into place, after [delay].
class _SlideIn extends StatefulWidget {
  const _SlideIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
