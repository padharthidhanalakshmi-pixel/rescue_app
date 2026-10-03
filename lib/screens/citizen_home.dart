import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import '../store.dart';
import '../widgets.dart';
import 'complaint_detail.dart';
import 'map_tab.dart';
import 'report_screen.dart';
import 'shared_tabs.dart';

class CitizenHome extends StatefulWidget {
  const CitizenHome({super.key});
  @override
  State<CitizenHome> createState() => _CitizenHomeState();
}

class _CitizenHomeState extends State<CitizenHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final unread = store.unreadCount;
        return Scaffold(
          body: IndexedStack(index: _tab, children: [
            const _CitizenFeed(),
            CityMap(title: 'Problems near you', source: () => store.complaints),
            const NotificationsTab(),
            const ProfileTab(),
          ]),
          floatingActionButton: _tab < 2
              ? FloatingActionButton.extended(
                  backgroundColor: signalAmber,
                  foregroundColor: Colors.black,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())),
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: const Text('Report a problem', style: TextStyle(fontWeight: FontWeight.w800)),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
              const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Map'),
              NavigationDestination(
                icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined)),
                selectedIcon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_rounded)),
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

class _CitizenFeed extends StatefulWidget {
  const _CitizenFeed();
  @override
  State<_CitizenFeed> createState() => _CitizenFeedState();
}

class _CitizenFeedState extends State<_CitizenFeed> {
  int _seg = 0; // 0 all, 1 mine, 2 supported
  String? _cat;
  String _q = '';
  int _sort = 0; // 0 newest, 1 priority, 2 nearest

  @override
  void initState() {
    super.initState();
    // Get a GPS fix early so distances and the demo map are ready.
    LocationService.get().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.current;
        if (me == null) return const SizedBox.shrink();
        final pos = LocationService.last;
        final mine = store.complaints.where((c) => c.reporterId == me.id).toList();

        final list = store.complaints.where((c) {
          if (_seg == 1 && c.reporterId != me.id) return false;
          if (_seg == 2 && !c.supporters.contains(me.id)) return false;
          if (_cat != null && c.category != _cat) return false;
          if (_q.isNotEmpty) {
            final hay = '${c.id} ${c.title} ${c.description} ${c.address}'.toLowerCase();
            if (!hay.contains(_q.toLowerCase())) return false;
          }
          return true;
        }).toList();
        if (_sort == 1) {
          list.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
        } else if (_sort == 2 && pos != null) {
          double d(Complaint c) => distanceMeters(pos.latitude, pos.longitude, c.lat, c.lng);
          list.sort((a, b) => d(a).compareTo(d(b)));
        } else {
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        final nearbyOpen = pos == null
            ? null
            : store.complaints
                .where((c) => c.isOpen && distanceMeters(pos.latitude, pos.longitude, c.lat, c.lng) <= 1000)
                .length;

        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              colors: const [brandTeal, brandTealLight],
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Hello, ${me.firstName}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        nearbyOpen == null
                            ? 'Turn on GPS to see problems around you'
                            : '$nearbyOpen open problem(s) within 1 km of you',
                        style: TextStyle(color: Colors.white.withAlpha(225)),
                      ),
                    ]),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Text(me.initials, style: const TextStyle(color: brandTeal, fontWeight: FontWeight.w900)),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: withGap([
                  HeaderStat(label: 'My reports', value: '${mine.length}'),
                  HeaderStat(label: 'Fixed', value: '${mine.where((c) => c.status == ComplaintStatus.resolved).length}'),
                  HeaderStat(label: 'Points', value: '${me.points}'),
                ], gap: 10)),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: fieldDeco(context, 'Search by title, ID or place', Icons.search_rounded),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(children: [
                Expanded(
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('All')),
                      ButtonSegment(value: 1, label: Text('Mine')),
                      ButtonSegment(value: 2, label: Text('Supported')),
                    ],
                    selected: {_seg},
                    onSelectionChanged: (s) => setState(() => _seg = s.first),
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort_rounded),
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0, child: Text('Newest first')),
                    PopupMenuItem(value: 1, child: Text('Highest priority')),
                    PopupMenuItem(value: 2, child: Text('Nearest to me')),
                  ],
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All types'),
                      selected: _cat == null,
                      onSelected: (_) => setState(() => _cat = null),
                    ),
                  ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(c.icon, size: 16, color: c.color),
                        label: Text(c.short),
                        selected: _cat == c.key,
                        onSelected: (_) => setState(() => _cat = _cat == c.key ? null : c.key),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: _seg == 1 ? Icons.add_location_alt_outlined : Icons.search_off_rounded,
                title: _seg == 1 ? 'You have not reported anything yet' : 'Nothing matches these filters',
                message: _seg == 1 ? 'Tap "Report a problem" to send your first complaint.' : 'Try another category or clear the search.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 4, bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => ComplaintCard(
                    complaint: list[i],
                    onTap: () => openComplaint(context, list[i]),
                    footer: list[i].reporterId == me.id ? 'Reported by you' : null,
                  ),
                  childCount: list.length,
                ),
              ),
            ),
        ]);
      },
    );
  }
}
