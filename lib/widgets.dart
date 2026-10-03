import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import 'models.dart';
import 'services.dart';

const brandTeal = Color(0xFF0F766E);
const brandTealLight = Color(0xFF14B8A6);
const signalAmber = Color(0xFFF59E0B);

TileLayer osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.citypulse.citypulse',
    );

InputDecoration fieldDeco(BuildContext context, String label, IconData icon, {Widget? suffix, String? hint}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: cs.surfaceContainerHighest.withAlpha(120),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cs.primary, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

List<Widget> withGap(List<Widget> items, {double gap = 12}) {
  final out = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    if (i > 0) out.add(SizedBox(width: gap));
    out.add(items[i]);
  }
  return out;
}

class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const TagChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  final ComplaintStatus status;
  const StatusChip({super.key, required this.status});
  @override
  Widget build(BuildContext context) => TagChip(label: status.label, color: status.color, icon: status.icon);
}

class PriorityChip extends StatelessWidget {
  final Priority priority;
  const PriorityChip({super.key, required this.priority});
  @override
  Widget build(BuildContext context) =>
      TagChip(label: '${priority.label} priority', color: priority.color, icon: Icons.flag_rounded);
}

class CategoryAvatar extends StatelessWidget {
  final IssueCategory category;
  final double size;
  const CategoryAvatar({super.key, required this.category, this.size = 44});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: category.color.withAlpha(36), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(category.icon, color: category.color, size: size * 0.55),
    );
  }
}

class LocalImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  const LocalImage(this.path, {super.key, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback onTap;
  final String? footer;
  const ComplaintCard({super.key, required this.complaint, required this.onTap, this.footer});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    final cs = Theme.of(context).colorScheme;
    final cat = categoryOf(c.category);
    final pos = LocationService.last;
    final muted = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.overdue ? Colors.red.withAlpha(120) : cs.outlineVariant.withAlpha(140)),
      ),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: c.status.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: c.photos.isNotEmpty
                          ? LocalImage(c.photos.first)
                          : Container(
                              color: cat.color.withAlpha(30),
                              child: Icon(cat.icon, color: cat.color, size: 32),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(c.id, style: muted.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(cat.short,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: cat.color, fontWeight: FontWeight.w700)),
                        ),
                        StatusChip(status: c.status),
                      ]),
                      const SizedBox(height: 6),
                      Text(c.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        PriorityChip(priority: c.priority),
                        if (c.overdue) const TagChip(label: 'Overdue', color: Colors.red, icon: Icons.timer_off_outlined),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.groups_2_outlined, size: 15, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text('${c.supporters.length}', style: muted),
                        const SizedBox(width: 12),
                        Icon(Icons.schedule_rounded, size: 15, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(timeAgo(c.createdAt), style: muted),
                        if (pos != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.near_me_outlined, size: 15, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              formatDistance(distanceMeters(pos.latitude, pos.longitude, c.lat, c.lng)),
                              style: muted,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ]),
                      if (footer != null) ...[
                        const SizedBox(height: 6),
                        Text(footer!, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withAlpha(140)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withAlpha(32), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: color),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}

/// Coloured header used at the top of each role's home screen.
class GradientHeader extends StatelessWidget {
  final List<Color> colors;
  final Widget child;
  const GradientHeader({super.key, required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 22), child: child),
        ),
      ),
    );
  }
}

class HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const HeaderStat({super.key, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 11.5)),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const EmptyState({super.key, required this.icon, required this.title, this.message});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: cs.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const SectionCard({super.key, required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withAlpha(140)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

/// Map marker for a complaint: category icon with a status-coloured dot.
class MapPin extends StatelessWidget {
  final Complaint complaint;
  const MapPin({super.key, required this.complaint});
  @override
  Widget build(BuildContext context) {
    final cat = categoryOf(complaint.category);
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        decoration: BoxDecoration(
          color: cat.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Icon(cat.icon, color: Colors.white, size: 20),
      ),
      Positioned(
        right: -1,
        top: -1,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: complaint.status.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    ]);
  }
}

class MeMarker extends StatelessWidget {
  const MeMarker({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF2563EB).withAlpha(60), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}
