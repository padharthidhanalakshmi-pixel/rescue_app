import 'package:flutter/material.dart';

import '../models.dart';
import '../services.dart';
import '../store.dart';
import '../widgets.dart';
import 'complaint_detail.dart';

/// App bar buttons for alerts and profile (used on the admin screens).
List<Widget> accountActions(BuildContext context, {Color? color}) => [
      IconButton(
        color: color,
        tooltip: 'Notifications',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsTab())),
        icon: Badge(
          isLabelVisible: store.unreadCount > 0,
          label: Text('${store.unreadCount}'),
          child: const Icon(Icons.notifications_outlined),
        ),
      ),
      IconButton(
        color: color,
        tooltip: 'Profile',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileTab())),
        icon: const Icon(Icons.account_circle_outlined),
      ),
    ];

void logoutFlow(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  store.logout();
}

void showDemoAccounts(BuildContext context) {
  final groups = <UserRole, List<AppUser>>{};
  for (final u in store.users) {
    groups.putIfAbsent(u.role, () => []).add(u);
  }
  String pw(UserRole r) => switch (r) {
        UserRole.citizen => 'citizen123',
        UserRole.officer => 'officer123',
        UserRole.admin => 'admin123',
      };
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text('Demo accounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Each officer only sees complaints for their own department.'),
          for (final role in UserRole.values)
            if (groups[role] != null) ...[
              const SizedBox(height: 16),
              Row(children: [
                Icon(role.icon, color: role.color),
                const SizedBox(width: 8),
                Text(role.label, style: TextStyle(fontWeight: FontWeight.w800, color: role.color)),
                const Spacer(),
                Text('Password: ${pw(role)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              for (final u in groups[role]!)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(u.email, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(u.department == null ? u.name : '${u.name}, ${u.department}'),
                ),
            ],
          const SizedBox(height: 8),
          const Text('New citizen accounts you register use the password you choose.',
              style: TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final list = store.myNotifications;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (store.unreadCount > 0) TextButton(onPressed: store.markAllRead, child: const Text('Mark all read')),
              if (list.isNotEmpty)
                IconButton(
                  tooltip: 'Clear all',
                  onPressed: () async {
                    if (await confirm(context, 'Clear notifications?', 'This removes all your notifications.', yes: 'Clear')) {
                      store.clearMyNotifications();
                    }
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications',
                  message: 'Status changes on your complaints will show up here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) {
                    final n = list[i];
                    final c = n.complaintId == null ? null : store.complaintById(n.complaintId!);
                    final color = c?.status.color ?? cs.primary;
                    return ListTile(
                      tileColor: n.read ? null : cs.primaryContainer.withAlpha(60),
                      leading: CircleAvatar(
                        backgroundColor: color.withAlpha(36),
                        child: Icon(c?.status.icon ?? Icons.campaign_outlined, color: color),
                      ),
                      title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                      subtitle: Text('${n.body}\n${timeAgo(n.at)}'),
                      isThreeLine: true,
                      trailing: n.read
                          ? null
                          : Container(width: 10, height: 10, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
                      onTap: () {
                        store.markRead(n);
                        if (c != null) openComplaint(context, c);
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final me = store.current;
        if (me == null) return const Scaffold();
        final cs = Theme.of(context).colorScheme;
        final mine = store.complaints.where((c) => c.reporterId == me.id).toList();
        final handled = store.complaints.where((c) => c.officerId == me.id).toList();
        final rated = handled.where((c) => c.rating != null).toList();
        final avg = rated.isEmpty ? null : rated.fold<int>(0, (s, c) => s + c.rating!) / rated.length;
        final span = (me.levelEnd - me.levelStart).clamp(1, 1000);
        final progress = me.points >= 150 ? 1.0 : (me.points - me.levelStart) / span;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [me.role.color, me.role.color.withAlpha(190)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Text(me.initials, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: me.role.color)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(me.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(me.email, style: TextStyle(color: Colors.white.withAlpha(220))),
                    const SizedBox(height: 6),
                    Text(me.department == null ? me.role.label : '${me.role.label}, ${me.department}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            if (me.role == UserRole.citizen) ...[
              SectionCard(
                title: 'Civic points',
                trailing: TagChip(label: me.level, color: signalAmber, icon: Icons.emoji_events_rounded),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${me.points} points', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: progress.toDouble(), minHeight: 10, color: signalAmber),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    me.points >= 150 ? 'Top level reached.' : '${me.levelEnd - me.points} points to the next level',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Text('Report a problem: +10    Support a problem: +2    Your problem fixed: +5',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              ),
              SectionCard(
                title: 'Your reports',
                child: Row(children: withGap([
                  Expanded(child: _mini('Reported', '${mine.length}', cs)),
                  Expanded(child: _mini('Open', '${mine.where((c) => c.isOpen).length}', cs)),
                  Expanded(child: _mini('Resolved', '${mine.where((c) => c.status == ComplaintStatus.resolved).length}', cs)),
                ], gap: 8)),
              ),
              SectionCard(
                title: 'Top citizens',
                child: Column(children: [
                  for (var i = 0; i < store.leaderboard.length && i < 5; i++)
                    _leader(i, store.leaderboard[i], me, cs),
                ]),
              ),
            ],
            if (me.role == UserRole.officer)
              SectionCard(
                title: 'Your work',
                child: Row(children: withGap([
                  Expanded(child: _mini('Active', '${handled.where((c) => c.isOpen).length}', cs)),
                  Expanded(child: _mini('Resolved', '${handled.where((c) => c.status == ComplaintStatus.resolved).length}', cs)),
                  Expanded(child: _mini('Avg rating', avg == null ? '-' : avg.toStringAsFixed(1), cs)),
                ], gap: 8)),
              ),
            SectionCard(
              title: 'Settings',
              child: Column(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  value: store.darkMode,
                  onChanged: store.setDarkMode,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Demo accounts'),
                  onTap: () => showDemoAccounts(context),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About CityPulse'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'CityPulse',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.location_city_rounded, size: 40, color: brandTeal),
                    children: const [
                      Text('Real-time urban problem reporting and management. Built with Flutter. '
                          'All data is stored on this device; maps by OpenStreetMap.'),
                    ],
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: const Text('Reset demo data'),
                  subtitle: const Text('Restores the sample complaints and accounts'),
                  onTap: () async {
                    final ok = await confirm(context, 'Reset demo data?',
                        'All complaints, accounts and notifications on this phone will be replaced with the sample data.',
                        yes: 'Reset', danger: true);
                    if (!ok || !context.mounted) return;
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    await store.resetDemo();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded, color: cs.error),
                  title: Text('Sign out', style: TextStyle(color: cs.error, fontWeight: FontWeight.w700)),
                  onTap: () => logoutFlow(context),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _leader(int i, AppUser u, AppUser me, ColorScheme cs) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: i == 0 ? signalAmber : cs.surfaceContainerHighest,
          child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        title: Text(u.id == me.id ? '${u.name} (you)' : u.name,
            style: TextStyle(fontWeight: u.id == me.id ? FontWeight.w800 : FontWeight.w500)),
        subtitle: Text(u.level),
        trailing: Text('${u.points} pts', style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _mini(String label, String value, ColorScheme cs) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest.withAlpha(130), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
      );
}
