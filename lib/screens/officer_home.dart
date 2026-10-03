import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import '../store.dart';
import '../widgets.dart';
import 'complaint_detail.dart';
import 'map_tab.dart';
import 'shared_tabs.dart';

const _officerBlue = Color(0xFF1D4ED8);
const _officerBlueLight = Color(0xFF3B82F6);

class OfficerHome extends StatefulWidget {
  const OfficerHome({super.key});
  @override
  State<OfficerHome> createState() => _OfficerHomeState();
}

class _OfficerHomeState extends State<OfficerHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    LocationService.get();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.current;
        if (me == null) return const SizedBox.shrink();
        final unread = store.unreadCount;
        return Scaffold(
          body: IndexedStack(index: _tab, children: [
            const _OfficerQueue(),
            CityMap(
              title: 'Department map',
              source: () => store.complaints.where((c) => c.department == store.current?.department),
            ),
            const NotificationsTab(),
            const ProfileTab(),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded), label: 'Queue'),
              const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Map'),
              NavigationDestination(
                icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
                label: 'Alerts',
              ),
              const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}

class _OfficerQueue extends StatefulWidget {
  const _OfficerQueue();
  @override
  State<_OfficerQueue> createState() => _OfficerQueueState();
}

class _OfficerQueueState extends State<_OfficerQueue> {
  int _seg = 0; // 0 active (dept), 1 mine, 2 closed

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.current;
        if (me == null) return const SizedBox.shrink();
        final dept = store.complaints.where((c) => c.department == me.department).toList();
        final mineOpen = dept.where((c) => c.officerId == me.id && c.isOpen).length;
        final unassigned = dept.where((c) => c.officerId == null && c.isOpen).length;
        final inProgress = dept.where((c) => c.status == ComplaintStatus.inProgress).length;
        final overdue = dept.where((c) => c.overdue).length;

        final list = dept.where((c) {
          if (_seg == 0) return c.isOpen;
          if (_seg == 1) return c.officerId == me.id && c.isOpen;
          return !c.isOpen;
        }).toList();
        if (_seg == 2) {
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        } else {
          list.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
        }

        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              colors: const [_officerBlue, _officerBlueLight],
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.engineering_rounded, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(me.department ?? 'No department',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                      Text('Officer ${me.name}', style: TextStyle(color: Colors.white.withAlpha(225))),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: withGap([
                  HeaderStat(label: 'Mine', value: '$mineOpen'),
                  HeaderStat(label: 'Unassigned', value: '$unassigned'),
                  HeaderStat(label: 'In progress', value: '$inProgress'),
                  HeaderStat(label: 'Overdue', value: '$overdue'),
                ], gap: 8)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('All open'), icon: Icon(Icons.inbox_outlined)),
                  ButtonSegment(value: 1, label: Text('Mine'), icon: Icon(Icons.assignment_ind_outlined)),
                  ButtonSegment(value: 2, label: Text('Closed'), icon: Icon(Icons.task_alt_rounded)),
                ],
                selected: {_seg},
                onSelectionChanged: (s) => setState(() => _seg = s.first),
              ),
            ),
          ),
          if (_seg != 2)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 2),
                child: Text('Sorted by priority score. Most urgent on top.', style: TextStyle(fontSize: 12)),
              ),
            ),
          if (list.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Icons.inbox_rounded, title: 'Queue is clear', message: 'New complaints for your department appear here.'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final c = list[i];
                    final footer = c.officerId == null
                        ? 'Unassigned. Open to accept.'
                        : c.officerId == me.id
                            ? 'Assigned to you'
                            : 'Assigned to ${store.userById(c.officerId)?.name ?? 'another officer'}';
                    return ComplaintCard(complaint: c, onTap: () => openComplaint(context, c), footer: footer);
                  },
                  childCount: list.length,
                ),
              ),
            ),
        ]);
      },
    );
  }
}
