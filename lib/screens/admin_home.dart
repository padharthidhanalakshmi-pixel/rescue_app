import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import '../store.dart';
import '../widgets.dart';
import 'complaint_detail.dart';
import 'map_tab.dart';
import 'shared_tabs.dart';

const _adminPurple = Color(0xFF6D28D9);
const _adminPurpleLight = Color(0xFF8B5CF6);

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    LocationService.get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        const _Dashboard(),
        const _AllComplaints(),
        CityMap(title: 'City map', source: () => store.complaints),
        const _Users(),
      ]),
      floatingActionButton: _tab == 3
          ? FloatingActionButton.extended(
              onPressed: () => showDialog(context: context, builder: (_) => const _AddOfficerDialog()),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add officer'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.list_alt_rounded), label: 'Complaints'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group_rounded), label: 'Users'),
        ],
      ),
    );
  }
}

// ───────────────────────── Dashboard ─────────────────────────
class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.current;
        if (me == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final status = store.statusCounts;
        final cats = store.categoryCounts;
        final avgRes = store.avgResolution;
        final avgRating = store.avgRating;
        final attention = store.complaints.where((c) => c.isOpen && (c.officerId == null || c.overdue)).toList()
          ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              colors: const [_adminPurple, _adminPurpleLight],
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('City control room',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text('Signed in as ${me.name}', style: TextStyle(color: Colors.white.withAlpha(225))),
                    ]),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: accountActions(context, color: Colors.white)),
                ]),
                const SizedBox(height: 16),
                Row(children: withGap([
                  HeaderStat(label: 'Total', value: '${store.complaints.length}'),
                  HeaderStat(label: 'Open', value: '${store.openCount}'),
                  HeaderStat(label: 'Unassigned', value: '${store.unassignedCount}'),
                  HeaderStat(label: 'Overdue', value: '${store.overdueCount}'),
                ], gap: 8)),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    StatCard(
                      label: 'Resolution rate',
                      value: '${(store.resolutionRate * 100).round()}%',
                      icon: Icons.task_alt_rounded,
                      color: const Color(0xFF16A34A),
                    ),
                    StatCard(
                      label: 'Avg time to fix',
                      value: avgRes == null ? '-' : formatDuration(avgRes),
                      icon: Icons.timer_outlined,
                      color: const Color(0xFF0891B2),
                    ),
                    StatCard(
                      label: 'Citizen rating',
                      value: avgRating == null ? '-' : '${avgRating.toStringAsFixed(1)} / 5',
                      icon: Icons.star_rounded,
                      color: signalAmber,
                    ),
                    StatCard(
                      label: 'Active citizens',
                      value: '${store.users.where((u) => u.role == UserRole.citizen && u.active).length}',
                      icon: Icons.groups_rounded,
                      color: brandTeal,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Complaints by status',
                  child: store.complaints.isEmpty
                      ? const Text('No complaints yet')
                      : Row(children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: PieChart(PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 34,
                              sections: [
                                for (final e in status.entries)
                                  if (e.value > 0)
                                    PieChartSectionData(
                                      value: e.value.toDouble(),
                                      color: e.key.color,
                                      title: '${e.value}',
                                      radius: 34,
                                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                              ],
                            )),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              for (final e in status.entries)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(children: [
                                    Container(width: 12, height: 12, decoration: BoxDecoration(color: e.key.color, borderRadius: BorderRadius.circular(3))),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(e.key.label)),
                                    Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  ]),
                                ),
                            ]),
                          ),
                        ]),
                ),
                SectionCard(
                  title: 'Complaints by category',
                  child: SizedBox(
                    height: 200,
                    child: BarChart(BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (cats.values.fold<int>(0, (m, v) => v > m ? v : m) + 1).toDouble(),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: 1,
                            getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= categories.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Icon(categories[i].icon, size: 18, color: categories[i].color),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < categories.length; i++)
                          BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: (cats[categories[i].key] ?? 0).toDouble(),
                              color: categories[i].color,
                              width: 16,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ]),
                      ],
                    )),
                  ),
                ),
                SectionCard(
                  title: 'Department performance',
                  child: Column(children: [
                    for (final d in departments) _deptRow(context, d, cs),
                  ]),
                ),
                SectionCard(
                  title: 'Needs attention',
                  trailing: TagChip(label: '${attention.length}', color: Colors.red),
                  child: attention.isEmpty
                      ? Text('Nothing unassigned or overdue.', style: TextStyle(color: cs.onSurfaceVariant))
                      : Column(children: [
                          for (final c in attention.take(4))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CategoryAvatar(category: categoryOf(c.category), size: 40),
                              title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${c.id}, ${c.officerId == null ? 'unassigned' : 'overdue'}, ${c.priority.label} priority'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => openComplaint(context, c),
                            ),
                        ]),
                ),
              ]),
            ),
          ),
        ]);
      },
    );
  }

  Widget _deptRow(BuildContext context, String dept, ColorScheme cs) {
    final list = store.complaints.where((c) => c.department == dept).toList();
    final resolved = list.where((c) => c.status == ComplaintStatus.resolved).length;
    final open = list.where((c) => c.isOpen).length;
    final rate = list.isEmpty ? 0.0 : resolved / list.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(dept, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$open open, $resolved fixed', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: rate, minHeight: 8, color: const Color(0xFF16A34A)),
        ),
      ]),
    );
  }
}

// ───────────────────────── Complaints list ─────────────────────────
class _AllComplaints extends StatefulWidget {
  const _AllComplaints();
  @override
  State<_AllComplaints> createState() => _AllComplaintsState();
}

class _AllComplaintsState extends State<_AllComplaints> {
  String _filter = 'all';
  String _q = '';

  bool _match(Complaint c) {
    switch (_filter) {
      case 'unassigned':
        if (!(c.isOpen && c.officerId == null)) return false;
      case 'overdue':
        if (!c.overdue) return false;
      case 'all':
        break;
      default:
        if (c.status.name != _filter) return false;
    }
    if (_q.isNotEmpty) {
      final hay = '${c.id} ${c.title} ${c.department} ${c.address}'.toLowerCase();
      if (!hay.contains(_q.toLowerCase())) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.complaints.where(_match).toList()
          ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
        final filters = <String, String>{
          'all': 'All',
          'unassigned': 'Unassigned',
          'overdue': 'Overdue',
          for (final s in ComplaintStatus.values) s.name: s.label,
        };
        return Scaffold(
          appBar: AppBar(title: const Text('All complaints'), actions: accountActions(context)),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: fieldDeco(context, 'Search ID, title, department', Icons.search_rounded),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                children: [
                  for (final e in filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _filter == e.key,
                        onSelected: (_) => setState(() => _filter = e.key),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(icon: Icons.filter_alt_off_outlined, title: 'No complaints match')
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final c = list[i];
                        final officer = store.userById(c.officerId);
                        return ComplaintCard(
                          complaint: c,
                          onTap: () => openComplaint(context, c),
                          footer: '${c.department}, ${officer?.name ?? 'unassigned'}',
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }
}

// ───────────────────────── Users ─────────────────────────
class _Users extends StatefulWidget {
  const _Users();
  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  int _seg = 0; // 0 all, 1 citizens, 2 officers, 3 admins

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.current;
        if (me == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final list = store.users.where((u) {
          return switch (_seg) {
            1 => u.role == UserRole.citizen,
            2 => u.role == UserRole.officer,
            3 => u.role == UserRole.admin,
            _ => true,
          };
        }).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Users'), actions: accountActions(context)),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('All')),
                  ButtonSegment(value: 1, label: Text('Citizens')),
                  ButtonSegment(value: 2, label: Text('Officers')),
                  ButtonSegment(value: 3, label: Text('Admins')),
                ],
                selected: {_seg},
                onSelectionChanged: (s) => setState(() => _seg = s.first),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final u = list[i];
                  final load = u.role == UserRole.officer ? store.openLoad(u.id) : null;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.active ? u.role.color : cs.outline,
                      child: Text(u.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    title: Text(u.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: u.active ? null : TextDecoration.lineThrough,
                        )),
                    subtitle: Text([
                      u.email,
                      u.department == null ? u.role.label : '${u.role.short}, ${u.department}',
                      if (load != null) '$load open complaint(s)',
                      if (u.role == UserRole.citizen) '${u.points} points',
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: u.id == me.id
                        ? const TagChip(label: 'You', color: _adminPurple)
                        : Switch(
                            value: u.active,
                            onChanged: (v) {
                              store.setUserActive(u, v);
                              showSnack(context, v ? '${u.name} activated' : '${u.name} deactivated');
                            },
                          ),
                    onTap: u.id == me.id ? null : () => showDialog(context: context, builder: (_) => _EditUserDialog(user: u)),
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final AppUser user;
  const _EditUserDialog({required this.user});
  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late UserRole _role = widget.user.role;
  late String _dept = widget.user.department ?? departments.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.user.name}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<UserRole>(
          value: _role,
          decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
          items: [for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
          onChanged: (v) => setState(() => _role = v ?? _role),
        ),
        if (_role == UserRole.officer) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _dept,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
            items: [for (final d in departments) DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _dept = v ?? _dept),
          ),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            store.updateUser(widget.user, role: _role, department: _dept);
            Navigator.pop(context);
            showSnack(context, '${widget.user.name} updated');
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddOfficerDialog extends StatefulWidget {
  const _AddOfficerDialog();
  @override
  State<_AddOfficerDialog> createState() => _AddOfficerDialogState();
}

class _AddOfficerDialogState extends State<_AddOfficerDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController(text: 'officer123');
  String _dept = departments.first;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add officer'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(controller: _pw, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _dept,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
            items: [for (final d in departments) DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _dept = v ?? _dept),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final err = store.addOfficer(name: _name.text, email: _email.text, password: _pw.text, department: _dept);
            if (err != null) {
              setState(() => _error = err);
              return;
            }
            Navigator.pop(context);
            showSnack(context, 'Officer added to $_dept');
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
