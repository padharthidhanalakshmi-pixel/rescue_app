import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models.dart';
import '../services.dart';
import '../store.dart';
import '../widgets.dart';

void openComplaint(BuildContext context, Complaint c) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComplaintDetailScreen(id: c.id)));
}

class ComplaintDetailScreen extends StatelessWidget {
  final String id;
  const ComplaintDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.current;
        if (me == null) return const Scaffold();
        final c = store.complaintById(id);
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.search_off_rounded, title: 'This complaint no longer exists'),
          );
        }
        final cs = Theme.of(context).colorScheme;
        final cat = categoryOf(c.category);
        final officer = store.userById(c.officerId);
        final reporter = store.userById(c.reporterId);
        final pos = LocationService.last;
        final actions = _buildActions(context, c, me);

        var reporterLabel = reporter?.name ?? 'Citizen';
        if (c.anonymous) {
          reporterLabel = me.role == UserRole.admin ? '$reporterLabel (anonymous)' : 'Anonymous citizen';
        }
        if (c.reporterId == me.id) reporterLabel = 'You';
        final sla = c.slaHours >= 24 ? '${c.slaHours ~/ 24} day(s)' : '${c.slaHours} h';

        return Scaffold(
          appBar: AppBar(title: Text(c.id)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _PhotoHeader(complaint: c),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CategoryAvatar(category: cat, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(cat.label, style: TextStyle(color: cat.color, fontWeight: FontWeight.w800)),
                    ),
                    Text(timeAgo(c.createdAt), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ]),
                  const SizedBox(height: 12),
                  Text(c.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    StatusChip(status: c.status),
                    PriorityChip(priority: c.priority),
                    if (c.overdue) const TagChip(label: 'Overdue', color: Colors.red, icon: Icons.timer_off_outlined),
                    if (c.urgent) const TagChip(label: 'Safety risk', color: Color(0xFFC2410C), icon: Icons.warning_amber_rounded),
                  ]),
                  if (c.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(c.description, style: TextStyle(fontSize: 15, height: 1.5, color: cs.onSurface)),
                  ],
                  const SizedBox(height: 18),
                  SectionCard(
                    title: 'Details',
                    child: Column(children: [
                      _InfoRow(Icons.apartment_rounded, 'Department', c.department),
                      _InfoRow(Icons.badge_outlined, 'Assigned officer', officer?.name ?? 'Waiting for assignment'),
                      _InfoRow(Icons.person_outline_rounded, 'Reported by', reporterLabel),
                      _InfoRow(Icons.event_outlined, 'Reported on', formatDate(c.createdAt)),
                      _InfoRow(Icons.groups_2_outlined, 'Citizens affected', '${c.supporters.length + 1}'),
                      _InfoRow(Icons.speed_rounded, 'Priority score', '${c.priorityScore}  •  target: $sla'),
                      if (c.resolvedAt != null)
                        _InfoRow(Icons.task_alt_rounded, 'Resolved in', formatDuration(c.resolvedAt!.difference(c.createdAt))),
                    ]),
                  ),
                  SectionCard(
                    title: 'Location',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 180,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(c.lat, c.lng),
                              initialZoom: 16,
                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                            ),
                            children: [
                              osmTiles(),
                              MarkerLayer(markers: [
                                Marker(point: LatLng(c.lat, c.lng), width: 46, height: 46, child: MapPin(complaint: c)),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(Icons.place_outlined, size: 18, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(c.address.isNotEmpty
                              ? c.address
                              : '${c.lat.toStringAsFixed(5)}, ${c.lng.toStringAsFixed(5)}'),
                        ),
                      ]),
                      if (pos != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 24),
                          child: Text(
                            '${formatDistance(distanceMeters(pos.latitude, pos.longitude, c.lat, c.lng))} from you',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                          ),
                        ),
                    ]),
                  ),
                  if (c.status == ComplaintStatus.resolved || c.resolutionPhotos.isNotEmpty)
                    SectionCard(title: 'Before and after', child: _BeforeAfter(complaint: c)),
                  if (c.rating != null)
                    SectionCard(
                      title: 'Citizen rating',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          for (var i = 0; i < 5; i++)
                            Icon(i < c.rating! ? Icons.star_rounded : Icons.star_outline_rounded, color: signalAmber, size: 28),
                        ]),
                        if (c.feedback != null) ...[const SizedBox(height: 6), Text('"${c.feedback}"')],
                      ]),
                    ),
                  SectionCard(title: 'Progress', child: _Timeline(events: c.history)),
                  SectionCard(title: 'Comments (${c.comments.length})', child: _Comments(complaint: c)),
                ]),
              ),
            ],
          ),
          bottomNavigationBar: actions.isEmpty
              ? null
              : SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      border: Border(top: BorderSide(color: cs.outlineVariant.withAlpha(140))),
                    ),
                    child: Row(children: withGap(actions)),
                  ),
                ),
        );
      },
    );
  }

  List<Widget> _buildActions(BuildContext context, Complaint c, AppUser me) {
    final list = <Widget>[];
    const pad = EdgeInsets.symmetric(vertical: 14);
    switch (me.role) {
      case UserRole.citizen:
        if (c.reporterId == me.id) {
          if (c.status == ComplaintStatus.resolved) {
            list.add(Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: pad),
                onPressed: () => _reopen(context, c),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Reopen'),
              ),
            ));
            if (c.rating == null) {
              list.add(Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(padding: pad),
                  onPressed: () => _rate(context, c),
                  icon: const Icon(Icons.star_rate_rounded),
                  label: const Text('Rate the fix'),
                ),
              ));
            }
          }
        } else if (c.isOpen) {
          final supported = c.supporters.contains(me.id);
          list.add(Expanded(
            child: supported
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: pad),
                    onPressed: () => store.toggleSupport(c),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Supported (tap to undo)'),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(padding: pad),
                    onPressed: () {
                      store.toggleSupport(c);
                      showSnack(context, 'Support added. Priority updated to ${c.priority.label}. +2 points');
                    },
                    icon: const Icon(Icons.front_hand_outlined),
                    label: const Text('I face this too'),
                  ),
          ));
        }
      case UserRole.officer:
        final inMyDept = c.department == me.department || c.officerId == me.id;
        if (inMyDept && c.isOpen) {
          if (c.officerId == null) {
            list.add(Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(padding: pad),
                onPressed: () {
                  store.acceptComplaint(c);
                  showSnack(context, '${c.id} assigned to you');
                },
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: const Text('Accept complaint'),
              ),
            ));
          } else if (c.officerId == me.id) {
            list.add(Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(padding: pad),
                onPressed: () => _updateStatus(context, c),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Update status'),
              ),
            ));
          }
        }
      case UserRole.admin:
        list.add(Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: pad),
            onPressed: () => showDialog(context: context, builder: (_) => AssignDialog(complaint: c)),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(c.officerId == null ? 'Assign' : 'Reassign'),
          ),
        ));
        if (c.isOpen) {
          list.add(Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(padding: pad),
              onPressed: () => _updateStatus(context, c),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Update status'),
            ),
          ));
        }
    }
    return list;
  }

  void _updateStatus(BuildContext context, Complaint c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatusUpdateSheet(complaint: c),
    );
  }

  Future<void> _rate(BuildContext context, Complaint c) async {
    var stars = 5;
    final fb = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('How well was it fixed?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(alignment: WrapAlignment.center, children: [
              for (var i = 0; i < 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setS(() => stars = i + 1),
                  icon: Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, color: signalAmber, size: 34),
                ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: fb,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Add a comment (optional)', border: OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit rating')),
          ],
        ),
      ),
    );
    if (ok == true) {
      store.rate(c, stars, fb.text.trim());
      if (context.mounted) showSnack(context, 'Rating submitted');
    }
  }

  Future<void> _reopen(BuildContext context, Complaint c) async {
    final reason = await askText(context,
        title: 'Reopen complaint', hint: 'What is still wrong? e.g. "The pothole opened up again"', action: 'Reopen');
    if (reason == null || reason.isEmpty) return;
    store.reopen(c, reason);
    if (context.mounted) showSnack(context, '${c.id} reopened and sent back to the department');
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: cs.primary),
        const SizedBox(width: 10),
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _PhotoHeader extends StatefulWidget {
  final Complaint complaint;
  const _PhotoHeader({required this.complaint});
  @override
  State<_PhotoHeader> createState() => _PhotoHeaderState();
}

class _PhotoHeaderState extends State<_PhotoHeader> {
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final cat = categoryOf(c.category);
    if (c.photos.isEmpty) {
      return Container(
        height: 150,
        color: cat.color.withAlpha(28),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(cat.icon, size: 52, color: cat.color),
          const SizedBox(height: 6),
          Text('No photo attached', style: TextStyle(color: cat.color, fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return SizedBox(
      height: 250,
      child: Stack(children: [
        PageView(
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            for (final p in c.photos)
              GestureDetector(onTap: () => openPhoto(context, p), child: LocalImage(p)),
          ],
        ),
        if (c.photos.length > 1)
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text('${_page + 1} / ${c.photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
      ]),
    );
  }
}

void openPhoto(BuildContext context, String path) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(child: InteractiveViewer(maxScale: 5, child: LocalImage(path, fit: BoxFit.contain))),
    ),
  ));
}

class _BeforeAfter extends StatelessWidget {
  final Complaint complaint;
  const _BeforeAfter({required this.complaint});

  Widget _pane(BuildContext context, String label, String? path, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TagChip(label: label, color: color),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: path == null
                ? Container(
                    color: cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text('No photo', style: TextStyle(color: cs.onSurfaceVariant)),
                  )
                : GestureDetector(onTap: () => openPhoto(context, path), child: LocalImage(path)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return Row(children: [
      _pane(context, 'Before', c.photos.isEmpty ? null : c.photos.first, Colors.red),
      const SizedBox(width: 12),
      _pane(context, 'After', c.resolutionPhotos.isEmpty ? null : c.resolutionPhotos.first, Colors.green),
    ]);
  }
}

class _Timeline extends StatelessWidget {
  final List<StatusEvent> events;
  const _Timeline({required this.events});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      for (var i = 0; i < events.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 28,
              child: Column(children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(color: events[i].status.color, shape: BoxShape.circle),
                  child: Icon(events[i].status.icon, size: 13, color: Colors.white),
                ),
                if (i < events.length - 1)
                  Expanded(child: Container(width: 2, color: cs.outlineVariant)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(events[i].status.label,
                      style: TextStyle(fontWeight: FontWeight.w800, color: events[i].status.color)),
                  const SizedBox(height: 2),
                  Text(events[i].note),
                  const SizedBox(height: 2),
                  Text('${events[i].by}, ${formatDate(events[i].at)}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _Comments extends StatefulWidget {
  final Complaint complaint;
  const _Comments({required this.complaint});
  @override
  State<_Comments> createState() => _CommentsState();
}

class _CommentsState extends State<_Comments> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    store.addComment(widget.complaint, t);
    _ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.complaint;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (c.comments.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('No comments yet. Ask a question or add an update.', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      for (final m in c.comments)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: m.role == 'Citizen' ? cs.surfaceContainerHighest.withAlpha(140) : cs.primaryContainer.withAlpha(140),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(m.by, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              TagChip(label: m.role, color: m.role == 'Citizen' ? brandTeal : const Color(0xFF1D4ED8)),
              const Spacer(),
              Text(timeAgo(m.at), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(height: 4),
            Text(m.text),
          ]),
        ),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: fieldDeco(context, 'Write a comment', Icons.chat_bubble_outline_rounded),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
      ]),
    ]);
  }
}

/// Officer/admin status update with optional resolution photos.
class StatusUpdateSheet extends StatefulWidget {
  final Complaint complaint;
  const StatusUpdateSheet({super.key, required this.complaint});
  @override
  State<StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends State<StatusUpdateSheet> {
  ComplaintStatus? _sel;
  final _note = TextEditingController();
  final List<String> _photos = [];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = _sel;
    if (s == null) {
      showSnack(context, 'Choose the new status');
      return;
    }
    if (s == ComplaintStatus.rejected && _note.text.trim().isEmpty) {
      showSnack(context, 'Add a reason for rejecting this complaint');
      return;
    }
    if (s == ComplaintStatus.resolved && _photos.isEmpty) {
      final go = await confirm(context, 'No after photo',
          'A photo of the fixed site lets the citizen verify the work. Save without one?',
          yes: 'Save anyway');
      if (!go) return;
    }
    store.updateStatus(widget.complaint, s, _note.text.trim(), photos: _photos);
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, 'Status changed to ${s.label}. Citizen notified.');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = [ComplaintStatus.inProgress, ComplaintStatus.resolved, ComplaintStatus.rejected];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Update ${widget.complaint.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Current status: ${widget.complaint.status.label}', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in options)
              ChoiceChip(
                avatar: Icon(s.icon, size: 18, color: _sel == s ? Colors.white : s.color),
                label: Text(s.label),
                selected: _sel == s,
                selectedColor: s.color,
                labelStyle: TextStyle(color: _sel == s ? Colors.white : null, fontWeight: FontWeight.w600),
                showCheckmark: false,
                onSelected: (_) => setState(() => _sel = s),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: fieldDeco(
              context,
              _sel == ComplaintStatus.rejected ? 'Reason (required)' : 'Note for the citizen',
              Icons.notes_rounded,
            ),
          ),
          if (_sel == ComplaintStatus.resolved) ...[
            const SizedBox(height: 16),
            const Text('After photos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 86,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _AddPhotoTile(onTap: () async {
                  final p = await pickPhoto(context);
                  if (p != null) setState(() => _photos.add(p));
                }),
                for (final p in _photos)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(width: 86, height: 86, child: LocalImage(p)),
                    ),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save update'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoTile({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary, width: 1.5),
          color: cs.primary.withAlpha(18),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_a_photo_outlined, color: cs.primary),
          const SizedBox(height: 4),
          Text('Add', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Admin dialog to choose department and officer.
class AssignDialog extends StatefulWidget {
  final Complaint complaint;
  const AssignDialog({super.key, required this.complaint});
  @override
  State<AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<AssignDialog> {
  late String _dept = widget.complaint.department;
  late String? _officer = widget.complaint.officerId;

  @override
  Widget build(BuildContext context) {
    final offs = store.officersIn(_dept);
    final officerValue = offs.any((o) => o.id == _officer) ? _officer : null;
    return AlertDialog(
      title: Text('Assign ${widget.complaint.id}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: _dept,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
          items: [
            for (final d in departments) DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() {
            _dept = v ?? _dept;
            _officer = null;
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String?>(
          key: ValueKey(_dept),
          value: officerValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Officer', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Least busy officer (auto)')),
            for (final o in offs)
              DropdownMenuItem<String?>(
                value: o.id,
                child: Text('${o.name} (${store.openLoad(o.id)} open)', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() => _officer = v),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            store.assign(widget.complaint, _dept, officerValue);
            Navigator.pop(context);
            showSnack(context, '${widget.complaint.id} assigned to $_dept');
          },
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
