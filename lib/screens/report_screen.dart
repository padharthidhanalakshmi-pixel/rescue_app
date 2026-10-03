import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models.dart';
import '../services.dart';
import '../store.dart';
import '../widgets.dart';
import 'complaint_detail.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _cat;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  bool _urgent = false;
  bool _anon = false;
  final List<String> _photos = [];
  double? _lat;
  double? _lng;
  double? _accuracy;
  String _address = '';
  bool _locating = false;
  bool _adjusted = false;
  final MapController _mc = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final r = await LocationService.get();
    if (!mounted) return;
    final p = r.position;
    if (p == null) {
      setState(() => _locating = false);
      showSnack(context, r.error ?? 'Could not get your location',
          action: SnackBarAction(label: 'Settings', onPressed: () => LocationService.openSettings(r)));
      return;
    }
    setState(() {
      _lat = p.latitude;
      _lng = p.longitude;
      _accuracy = p.accuracy;
      _adjusted = false;
      _locating = false;
      _address = '';
    });
    if (_mapReady) _mc.move(LatLng(p.latitude, p.longitude), 17);
    _lookupAddress();
  }

  Future<void> _lookupAddress() async {
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null) return;
    final a = await LocationService.address(lat, lng);
    if (mounted && lat == _lat && lng == _lng) setState(() => _address = a);
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 4) {
      showSnack(context, 'You can attach up to 4 photos');
      return;
    }
    final p = await pickPhoto(context);
    if (p != null && mounted) setState(() => _photos.add(p));
  }

  Future<void> _submit() async {
    if (_cat == null) {
      showSnack(context, 'Choose what kind of problem it is');
      return;
    }
    if (_title.text.trim().length < 5) {
      showSnack(context, 'Add a short title (at least 5 characters)');
      return;
    }
    if (_lat == null || _lng == null) {
      showSnack(context, 'Location is needed. Tap "Use my GPS" to try again.');
      return;
    }
    final lat = _lat!, lng = _lng!;

    // Duplicate detection: same category, still open, within 150 m.
    final dups = store.findDuplicates(_cat!, lat, lng);
    if (dups.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => _DuplicateDialog(dups: dups, lat: lat, lng: lng),
      );
      if (!mounted || choice == null) return;
      if (choice != 'new') {
        final existing = store.complaintById(choice);
        final me = store.current;
        if (existing != null && me != null) {
          if (existing.reporterId != me.id && !existing.supporters.contains(me.id)) {
            store.toggleSupport(existing);
          }
          showSnack(context, 'You now support ${existing.id}. Its priority went up.');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ComplaintDetailScreen(id: existing.id)),
          );
        }
        return;
      }
    }

    if (_photos.isEmpty) {
      final go = await confirm(context, 'Submit without a photo?',
          'A photo helps the department understand the problem and fix it faster.',
          yes: 'Submit anyway');
      if (!go || !mounted) return;
    }

    final c = store.submitComplaint(
      category: _cat!,
      title: _title.text.trim(),
      description: _desc.text.trim(),
      lat: lat,
      lng: lng,
      address: _address,
      photos: _photos,
      urgent: _urgent,
      anonymous: _anon,
    );
    if (!mounted) return;
    final view = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(complaint: c),
    );
    if (!mounted) return;
    if (view == true) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ComplaintDetailScreen(id: c.id)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _StepTitle(n: 1, title: 'What kind of problem is it?'),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [for (final c in categories) _catTile(c, cs)],
          ),
          if (_cat != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(Icons.alt_route_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Will be sent to ${categoryOf(_cat!).department}',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
            ),
          const _StepTitle(n: 2, title: 'Describe it'),
          TextField(
            controller: _title,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: fieldDeco(context, 'Title', Icons.title_rounded, hint: 'e.g. Big pothole near the bus stop'),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _desc,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: fieldDeco(context, 'Details (optional)', Icons.notes_rounded,
                hint: 'How big is it, since when, is anyone at risk?'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _urgent,
            onChanged: (v) => setState(() => _urgent = v),
            secondary: const Icon(Icons.warning_amber_rounded, color: Color(0xFFC2410C)),
            title: const Text('This is a safety risk'),
            subtitle: const Text('Raises the priority of the complaint'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _anon,
            onChanged: (v) => setState(() => _anon = v),
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Hide my name'),
            subtitle: const Text('Other citizens and officers will not see who reported it'),
          ),
          const _StepTitle(n: 3, title: 'Add photos'),
          SizedBox(
            height: 96,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              InkWell(
                onTap: _addPhoto,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.primary, width: 1.5),
                    color: cs.primary.withAlpha(18),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_outlined, color: cs.primary, size: 28),
                    const SizedBox(height: 4),
                    Text('${_photos.length}/4', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              for (var i = 0; i < _photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(width: 96, height: 96, child: LocalImage(_photos[i])),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
          const _StepTitle(n: 4, title: 'Confirm the location'),
          _locationCard(cs),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _submit,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Submit complaint', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _catTile(IssueCategory c, ColorScheme cs) {
    final sel = _cat == c.key;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _cat = c.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: sel ? c.color.withAlpha(40) : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? c.color : cs.outlineVariant, width: sel ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(c.icon, color: c.color, size: 28),
          const SizedBox(height: 6),
          Text(c.short,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _locationCard(ColorScheme cs) {
    final deco = BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: cs.outlineVariant.withAlpha(160)),
    );
    if (_lat == null || _lng == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: deco,
        child: Column(children: [
          if (_locating) ...[
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: 12),
            const Text('Finding your GPS location...'),
          ] else ...[
            Icon(Icons.location_off_outlined, size: 36, color: cs.error),
            const SizedBox(height: 8),
            const Text('Location not available yet', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(onPressed: _locate, icon: const Icon(Icons.gps_fixed_rounded), label: const Text('Use my GPS')),
          ],
        ]),
      );
    }
    final point = LatLng(_lat!, _lng!);
    return Container(
      decoration: deco,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 220,
          child: FlutterMap(
            mapController: _mc,
            options: MapOptions(
              initialCenter: point,
              initialZoom: 17,
              onMapReady: () => _mapReady = true,
              onTap: (_, p) {
                setState(() {
                  _lat = p.latitude;
                  _lng = p.longitude;
                  _adjusted = true;
                  _address = '';
                });
                _lookupAddress();
              },
            ),
            children: [
              osmTiles(),
              MarkerLayer(markers: [
                Marker(
                  point: point,
                  width: 50,
                  height: 50,
                  child: const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 50),
                ),
              ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(_adjusted ? Icons.touch_app_outlined : Icons.gps_fixed_rounded, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _address.isNotEmpty ? _address : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _adjusted
                      ? 'Pin moved by you. Tap the map again to adjust.'
                      : 'GPS accuracy about ${(_accuracy ?? 0).round()} m. Tap the map to move the pin.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: TextButton.icon(
            onPressed: _locating ? null : _locate,
            icon: _locating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded),
            label: const Text('Use my GPS'),
          ),
        ),
      ]),
    );
  }
}

class _StepTitle extends StatelessWidget {
  final int n;
  final String title;
  const _StepTitle({required this.n, required this.title});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: cs.primary,
          child: Text('$n', style: TextStyle(color: cs.onPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _DuplicateDialog extends StatelessWidget {
  final List<Complaint> dups;
  final double lat;
  final double lng;
  const _DuplicateDialog({required this.dups, required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.content_copy_rounded),
      title: const Text('Already reported nearby'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${dups.length} open complaint(s) of the same type are within 150 m. '
              'Supporting one raises its priority instead of creating a duplicate.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final d in dups.take(3))
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest.withAlpha(150),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => Navigator.pop(context, d.id),
                  leading: CategoryAvatar(category: categoryOf(d.category), size: 38),
                  title: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${d.id}, ${formatDistance(distanceMeters(lat, lng, d.lat, d.lng))} away, '
                    '${d.supporters.length + 1} affected',
                  ),
                  trailing: Icon(Icons.front_hand_outlined, color: cs.primary),
                ),
              ),
            Text('Tap a complaint to support it.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        OutlinedButton(onPressed: () => Navigator.pop(context, 'new'), child: const Text('Mine is different')),
      ],
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final Complaint complaint;
  const _SuccessDialog({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    final cs = Theme.of(context).colorScheme;
    final officer = store.userById(c.officerId);
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 92, child: Text(k, style: TextStyle(color: cs.onSurfaceVariant))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
        );
    return AlertDialog(
      icon: const CircleAvatar(
        radius: 30,
        backgroundColor: Color(0xFF16A34A),
        child: Icon(Icons.check_rounded, color: Colors.white, size: 36),
      ),
      title: const Text('Complaint submitted'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(c.id, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: cs.primary)),
        const SizedBox(height: 12),
        row('Department', c.department),
        row('Officer', officer?.name ?? 'Waiting for assignment'),
        row('Priority', c.priority.label),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: signalAmber.withAlpha(40), borderRadius: BorderRadius.circular(12)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events_rounded, color: signalAmber),
            SizedBox(width: 6),
            Text('+10 civic points', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Done')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Track complaint')),
      ],
    );
  }
}
