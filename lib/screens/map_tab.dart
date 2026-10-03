import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models.dart';
import '../services.dart';
import '../store.dart';
import '../widgets.dart';
import 'complaint_detail.dart';

/// Interactive OpenStreetMap view with complaint markers and live GPS position.
class CityMap extends StatefulWidget {
  final String title;
  final Iterable<Complaint> Function() source;
  const CityMap({super.key, required this.title, required this.source});

  @override
  State<CityMap> createState() => _CityMapState();
}

class _CityMapState extends State<CityMap> {
  final MapController _mc = MapController();
  bool _ready = false;
  LatLng? _me;
  int _filter = 0; // 0 open, 1 resolved, 2 all
  String _cat = 'all';

  @override
  void initState() {
    super.initState();
    final l = LocationService.last;
    if (l != null) _me = LatLng(l.latitude, l.longitude);
    _locate(silent: true);
  }

  Future<void> _locate({bool silent = false}) async {
    final r = await LocationService.get();
    if (!mounted) return;
    final p = r.position;
    if (p == null) {
      if (!silent) {
        showSnack(context, r.error ?? 'Location unavailable',
            action: SnackBarAction(label: 'Settings', onPressed: () => LocationService.openSettings(r)));
      }
      return;
    }
    setState(() => _me = LatLng(p.latitude, p.longitude));
    if (_ready) _mc.move(_me!, 15.5);
  }

  LatLng _initialCenter(List<Complaint> all) {
    if (_me != null) return _me!;
    if (all.isNotEmpty) return LatLng(all.first.lat, all.first.lng);
    return LatLng(demoCenterLat, demoCenterLng);
  }

  void _preview(Complaint c) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ComplaintCard(
              complaint: c,
              onTap: () {
                Navigator.pop(ctx);
                openComplaint(context, c);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openComplaint(context, c);
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open complaint'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = widget.source().toList();
        final list = all.where((c) {
          if (_cat != 'all' && c.category != _cat) return false;
          if (_filter == 0) return c.isOpen;
          if (_filter == 1) return c.status == ComplaintStatus.resolved;
          return true;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Filter by category',
                icon: Icon(_cat == 'all' ? Icons.filter_alt_outlined : Icons.filter_alt_rounded),
                initialValue: _cat,
                onSelected: (v) => setState(() => _cat = v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'all', child: Text('All categories')),
                  for (final c in categories)
                    PopupMenuItem(
                      value: c.key,
                      child: Row(children: [Icon(c.icon, color: c.color, size: 20), const SizedBox(width: 10), Text(c.short)]),
                    ),
                ],
              ),
            ],
          ),
          body: Stack(children: [
            FlutterMap(
              mapController: _mc,
              options: MapOptions(
                initialCenter: _initialCenter(all),
                initialZoom: 14.5,
                onMapReady: () {
                  _ready = true;
                  if (_me != null) _mc.move(_me!, 15.5);
                },
              ),
              children: [
                osmTiles(),
                MarkerLayer(markers: [
                  for (final c in list)
                    Marker(
                      point: LatLng(c.lat, c.lng),
                      width: 46,
                      height: 46,
                      child: GestureDetector(onTap: () => _preview(c), child: MapPin(complaint: c)),
                    ),
                  if (_me != null) Marker(point: _me!, width: 34, height: 34, child: const MeMarker()),
                ]),
              ],
            ),
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 0, label: Text('Open (${all.where((c) => c.isOpen).length})')),
                      const ButtonSegment(value: 1, label: Text('Resolved')),
                      const ButtonSegment(value: 2, label: Text('All')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (s) => setState(() => _filter = s.first),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 66,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'My location',
                onPressed: () => _locate(),
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
            Positioned(left: 12, bottom: 16, child: _Legend(count: list.length)),
            Positioned(
              right: 4,
              bottom: 2,
              child: Text('© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 9, color: Colors.black.withAlpha(150))),
            ),
          ]),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final int count;
  const _Legend({required this.count});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withAlpha(235),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('$count on map', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 6),
        for (final s in ComplaintStatus.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(s.label, style: const TextStyle(fontSize: 11)),
            ]),
          ),
      ]),
    );
  }
}
