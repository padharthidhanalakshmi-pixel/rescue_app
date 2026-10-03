import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Single app-wide store. All data is saved on the phone (SharedPreferences);
/// photos are saved as files in the app's private documents folder.
final AppStore store = AppStore();

class AppStore extends ChangeNotifier {
  late SharedPreferences _prefs;
  List<AppUser> users = [];
  List<Complaint> complaints = [];
  List<AppNotification> notifications = [];
  AppUser? current;
  bool darkMode = false;
  int _seq = 1000;
  final Random _rnd = Random();

  // ───────────── lookups ─────────────
  T? _first<T>(Iterable<T> items, bool Function(T) test) {
    for (final e in items) {
      if (test(e)) return e;
    }
    return null;
  }

  AppUser? userById(String? id) => id == null ? null : _first<AppUser>(users, (u) => u.id == id);
  Complaint? complaintById(String id) => _first<Complaint>(complaints, (c) => c.id == id);

  List<AppUser> officersIn(String dept) =>
      users.where((u) => u.role == UserRole.officer && u.department == dept && u.active).toList();
  List<AppUser> get admins => users.where((u) => u.role == UserRole.admin && u.active).toList();
  int openLoad(String officerId) => complaints.where((c) => c.officerId == officerId && c.isOpen).length;

  // ───────────── persistence ─────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs.getString('users');
      if (raw == null) {
        _seed();
        await _persist();
      } else {
        users = (jsonDecode(raw) as List)
            .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        complaints = (jsonDecode(_prefs.getString('complaints') ?? '[]') as List)
            .map((e) => Complaint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifications = (jsonDecode(_prefs.getString('notifications') ?? '[]') as List)
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _seq = _prefs.getInt('seq') ?? 1000;
      }
    } catch (_) {
      _seed();
      await _persist();
    }
    darkMode = _prefs.getBool('dark') ?? false;
    final sessionUser = userById(_prefs.getString('session'));
    if (sessionUser != null && sessionUser.active) current = sessionUser;
  }

  Future<void> _persist() async {
    if (notifications.length > 300) {
      notifications.sort((a, b) => b.at.compareTo(a.at));
      notifications = notifications.take(300).toList();
    }
    await _prefs.setString('users', jsonEncode(users.map((e) => e.toJson()).toList()));
    await _prefs.setString('complaints', jsonEncode(complaints.map((e) => e.toJson()).toList()));
    await _prefs.setString('notifications', jsonEncode(notifications.map((e) => e.toJson()).toList()));
    await _prefs.setInt('seq', _seq);
  }

  void _commit() {
    notifyListeners();
    _persist();
  }

  // ───────────── auth ─────────────
  String? login(String email, String password) {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || password.isEmpty) return 'Enter your email and password.';
    final u = _first<AppUser>(users, (x) => x.email.toLowerCase() == e);
    if (u == null || u.password != password) return 'Email or password is incorrect.';
    if (!u.active) return 'This account was deactivated by the administrator.';
    current = u;
    _prefs.setString('session', u.id);
    notifyListeners();
    return null;
  }

  String? register({required String name, required String email, required String phone, required String password}) {
    final e = email.trim().toLowerCase();
    if (name.trim().length < 2) return 'Enter your full name.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'Enter a valid email address.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (users.any((u) => u.email.toLowerCase() == e)) return 'An account with this email already exists.';
    final u = AppUser(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: e,
      password: password,
      phone: phone.trim(),
    );
    users.add(u);
    current = u;
    _prefs.setString('session', u.id);
    _notify(u.id, 'Welcome to CityPulse!', 'Report problems around you and earn civic points for every report.', null);
    _commit();
    return null;
  }

  void logout() {
    current = null;
    _prefs.remove('session');
    notifyListeners();
  }

  void setDarkMode(bool v) {
    darkMode = v;
    _prefs.setBool('dark', v);
    notifyListeners();
  }

  // ───────────── notifications ─────────────
  String _newId() => '${DateTime.now().microsecondsSinceEpoch}${_rnd.nextInt(999)}';

  void _notify(String userId, String title, String body, String? complaintId) {
    notifications.add(AppNotification(
      id: _newId(),
      userId: userId,
      title: title,
      body: body,
      complaintId: complaintId,
      at: DateTime.now(),
    ));
  }

  List<AppNotification> get myNotifications {
    final me = current;
    if (me == null) return [];
    return notifications.where((n) => n.userId == me.id).toList()..sort((a, b) => b.at.compareTo(a.at));
  }

  int get unreadCount => myNotifications.where((n) => !n.read).length;

  void markRead(AppNotification n) {
    if (n.read) return;
    n.read = true;
    _commit();
  }

  void markAllRead() {
    for (final n in myNotifications) {
      n.read = true;
    }
    _commit();
  }

  void clearMyNotifications() {
    final me = current;
    if (me == null) return;
    notifications.removeWhere((n) => n.userId == me.id);
    _commit();
  }

  // ───────────── complaints ─────────────
  /// Open complaints of the same category within [radius] metres.
  List<Complaint> findDuplicates(String category, double lat, double lng, {double radius = 150}) {
    final list = complaints
        .where((c) => c.category == category && c.isOpen && distanceMeters(lat, lng, c.lat, c.lng) <= radius)
        .toList();
    list.sort((a, b) =>
        distanceMeters(lat, lng, a.lat, a.lng).compareTo(distanceMeters(lat, lng, b.lat, b.lng)));
    return list;
  }

  Complaint submitComplaint({
    required String category,
    required String title,
    required String description,
    required double lat,
    required double lng,
    String address = '',
    List<String> photos = const [],
    bool urgent = false,
    bool anonymous = false,
  }) {
    final me = current!;
    final cat = categoryOf(category);
    final now = DateTime.now();
    final c = Complaint(
      id: 'CP-${++_seq}',
      category: category,
      title: title,
      description: description,
      lat: lat,
      lng: lng,
      address: address,
      photos: List<String>.from(photos),
      reporterId: me.id,
      anonymous: anonymous,
      urgent: urgent,
      status: ComplaintStatus.submitted,
      department: cat.department,
      createdAt: now,
      updatedAt: now,
      history: [
        StatusEvent(
          status: ComplaintStatus.submitted,
          note: 'Complaint registered through the CityPulse app.',
          by: anonymous ? 'Anonymous citizen' : me.name,
          at: now,
        ),
      ],
    );
    complaints.insert(0, c);
    _autoAssign(c, by: 'CityPulse auto-router');
    me.points += 10;
    for (final a in admins) {
      _notify(a.id, 'New complaint ${c.id}', '${cat.label} • ${c.priority.label} priority • ${c.department}', c.id);
    }
    _notify(me.id, 'Complaint ${c.id} submitted', 'Sent to ${c.department}. You earned 10 civic points.', c.id);
    _commit();
    return c;
  }

  void _autoAssign(Complaint c, {required String by}) {
    final offs = officersIn(c.department)..sort((a, b) => openLoad(a.id).compareTo(openLoad(b.id)));
    if (offs.isEmpty) return;
    final o = offs.first;
    final now = DateTime.now();
    c.officerId = o.id;
    c.status = ComplaintStatus.assigned;
    c.updatedAt = now;
    c.history.add(StatusEvent(
      status: ComplaintStatus.assigned,
      note: 'Assigned to ${o.name} (${c.department}).',
      by: by,
      at: now,
    ));
    _notify(o.id, 'New assignment ${c.id}', '${categoryOf(c.category).label}: ${c.title}', c.id);
  }

  /// Returns true if now supported, false if support was withdrawn.
  bool toggleSupport(Complaint c) {
    final me = current!;
    if (c.supporters.contains(me.id)) {
      c.supporters.remove(me.id);
      me.points = max(0, me.points - 2);
      _commit();
      return false;
    }
    c.supporters.add(me.id);
    me.points += 2;
    c.updatedAt = DateTime.now();
    if (c.reporterId != me.id) {
      _notify(c.reporterId, 'Your complaint got support',
          '${me.name} is also affected by "${c.title}". ${c.supporters.length} supporter(s) now.', c.id);
    }
    if (c.officerId != null) {
      _notify(c.officerId!, '${c.id} support increased',
          '${c.supporters.length} citizen(s) now support this complaint. Priority: ${c.priority.label}.', c.id);
    }
    _commit();
    return true;
  }

  void assign(Complaint c, String dept, String? officerId) {
    final byName = current?.name ?? 'Administrator';
    c.department = dept;
    c.officerId = null;
    if (officerId == null) {
      _autoAssign(c, by: byName);
      if (c.officerId == null) c.status = ComplaintStatus.submitted;
    } else {
      final o = userById(officerId);
      c.officerId = officerId;
      c.status = ComplaintStatus.assigned;
      c.history.add(StatusEvent(
        status: ComplaintStatus.assigned,
        note: 'Assigned to ${o?.name ?? 'officer'} ($dept).',
        by: byName,
        at: DateTime.now(),
      ));
      _notify(officerId, 'New assignment ${c.id}', '${categoryOf(c.category).label}: ${c.title}', c.id);
    }
    c.resolvedAt = null;
    c.updatedAt = DateTime.now();
    _notify(c.reporterId, 'Complaint ${c.id} assigned', 'Your complaint is now handled by $dept.', c.id);
    _commit();
  }

  void acceptComplaint(Complaint c) {
    final me = current!;
    c.officerId = me.id;
    c.status = ComplaintStatus.assigned;
    c.updatedAt = DateTime.now();
    c.history.add(StatusEvent(
      status: ComplaintStatus.assigned,
      note: '${me.name} accepted this complaint.',
      by: me.name,
      at: DateTime.now(),
    ));
    _notify(c.reporterId, 'Complaint ${c.id} accepted', '${me.name} (${c.department}) is now handling your complaint.', c.id);
    _commit();
  }

  void updateStatus(Complaint c, ComplaintStatus s, String note, {List<String> photos = const []}) {
    final me = current!;
    final now = DateTime.now();
    c.status = s;
    c.updatedAt = now;
    if (s == ComplaintStatus.resolved) {
      c.resolvedAt = now;
      c.resolutionPhotos.addAll(photos);
      final reporter = userById(c.reporterId);
      if (reporter != null) reporter.points += 5;
    }
    final defaultNote = switch (s) {
      ComplaintStatus.inProgress => 'Work has started at the site.',
      ComplaintStatus.resolved => 'The issue has been fixed.',
      ComplaintStatus.rejected => 'Complaint closed by the department.',
      _ => 'Status changed to ${s.label}.',
    };
    c.history.add(StatusEvent(status: s, note: note.isEmpty ? defaultNote : note, by: me.name, at: now));
    final msg = switch (s) {
      ComplaintStatus.inProgress => 'Work has started on "${c.title}".',
      ComplaintStatus.resolved => '"${c.title}" is resolved. Open it to rate the work.',
      ComplaintStatus.rejected => '"${c.title}" was closed: ${note.isEmpty ? 'open for details' : note}',
      _ => 'Status changed to ${s.label}.',
    };
    final recipients = {c.reporterId, ...c.supporters}..remove(me.id);
    for (final r in recipients) {
      _notify(r, 'Complaint ${c.id}: ${s.label}', msg, c.id);
    }
    _commit();
  }

  void addComment(Complaint c, String text) {
    final me = current!;
    c.comments.add(ComplaintComment(by: me.name, role: me.role.short, text: text, at: DateTime.now()));
    final recipients = {c.reporterId, if (c.officerId != null) c.officerId!}..remove(me.id);
    for (final r in recipients) {
      _notify(r, 'New comment on ${c.id}', '${me.name}: $text', c.id);
    }
    _commit();
  }

  void rate(Complaint c, int rating, String feedback) {
    c.rating = rating;
    c.feedback = feedback.isEmpty ? null : feedback;
    if (c.officerId != null) {
      _notify(c.officerId!, 'Citizen rated ${c.id}', '$rating/5 stars${feedback.isEmpty ? '' : ': $feedback'}', c.id);
    }
    _commit();
  }

  void reopen(Complaint c, String reason) {
    final me = current!;
    c.status = c.officerId != null ? ComplaintStatus.assigned : ComplaintStatus.submitted;
    c.resolvedAt = null;
    c.rating = null;
    c.feedback = null;
    c.updatedAt = DateTime.now();
    c.history.add(StatusEvent(status: c.status, note: 'Reopened by citizen: $reason', by: me.name, at: DateTime.now()));
    if (c.officerId != null) _notify(c.officerId!, 'Complaint ${c.id} reopened', reason, c.id);
    for (final a in admins) {
      _notify(a.id, 'Complaint ${c.id} reopened', reason, c.id);
    }
    _commit();
  }

  // ───────────── admin: users ─────────────
  void setUserActive(AppUser u, bool active) {
    u.active = active;
    _commit();
  }

  void updateUser(AppUser u, {required UserRole role, String? department}) {
    u.role = role;
    u.department = role == UserRole.officer ? (department ?? departments.first) : null;
    _commit();
  }

  String? addOfficer({required String name, required String email, required String password, required String department}) {
    final e = email.trim().toLowerCase();
    if (name.trim().length < 2) return 'Enter the officer\'s name.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return 'Enter a valid email address.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (users.any((u) => u.email.toLowerCase() == e)) return 'This email is already in use.';
    users.add(AppUser(
      id: 'o_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: e,
      password: password,
      role: UserRole.officer,
      department: department,
    ));
    _commit();
    return null;
  }

  // ───────────── statistics ─────────────
  Map<ComplaintStatus, int> get statusCounts {
    final m = {for (final s in ComplaintStatus.values) s: 0};
    for (final c in complaints) {
      m[c.status] = (m[c.status] ?? 0) + 1;
    }
    return m;
  }

  Map<String, int> get categoryCounts {
    final m = {for (final c in categories) c.key: 0};
    for (final c in complaints) {
      m[c.category] = (m[c.category] ?? 0) + 1;
    }
    return m;
  }

  int get openCount => complaints.where((c) => c.isOpen).length;
  int get overdueCount => complaints.where((c) => c.overdue).length;
  int get resolvedCount => complaints.where((c) => c.status == ComplaintStatus.resolved).length;
  int get unassignedCount => complaints.where((c) => c.isOpen && c.officerId == null).length;
  double get resolutionRate => complaints.isEmpty ? 0 : resolvedCount / complaints.length;

  Duration? get avgResolution {
    final r = complaints.where((c) => c.resolvedAt != null).toList();
    if (r.isEmpty) return null;
    final total = r.fold<int>(0, (s, c) => s + c.resolvedAt!.difference(c.createdAt).inMinutes);
    return Duration(minutes: total ~/ r.length);
  }

  double? get avgRating {
    final r = complaints.where((c) => c.rating != null).toList();
    if (r.isEmpty) return null;
    return r.fold<int>(0, (s, c) => s + c.rating!) / r.length;
  }

  List<AppUser> get leaderboard =>
      users.where((u) => u.role == UserRole.citizen && u.active).toList()..sort((a, b) => b.points.compareTo(a.points));

  // ───────────── demo data ─────────────
  /// Moves the sample complaints next to the phone's real GPS position
  /// the first time a location fix is obtained, so the demo map looks real.
  void anchorDemo(double lat, double lng) {
    if (_prefs.getBool('anchored') ?? false) return;
    final dLat = lat - demoCenterLat;
    final dLng = lng - demoCenterLng;
    for (final c in complaints.where((c) => c.isDemo)) {
      c.lat += dLat;
      c.lng += dLng;
    }
    _prefs.setBool('anchored', true);
    _commit();
  }

  Future<void> resetDemo() async {
    await _prefs.clear();
    current = null;
    darkMode = false;
    _seed();
    await _persist();
    notifyListeners();
  }

  void _seed() {
    final now = DateTime.now();
    users = [
      AppUser(id: 'u_admin', name: 'Anitha Rao', email: 'admin@citypulse.com', password: 'admin123', phone: '9000000001', role: UserRole.admin),
      AppUser(id: 'u_citizen', name: 'Ravi Kumar', email: 'citizen@citypulse.com', password: 'citizen123', phone: '9000000002', points: 45),
      AppUser(id: 'u_priya', name: 'Priya Sharma', email: 'priya@citypulse.com', password: 'citizen123', phone: '9000000003', points: 92),
      AppUser(id: 'u_arjun', name: 'Arjun Mehta', email: 'arjun@citypulse.com', password: 'citizen123', phone: '9000000004', points: 28),
      AppUser(id: 'o_roads', name: 'Suresh Reddy', email: 'officer@citypulse.com', password: 'officer123', role: UserRole.officer, department: 'Roads & Infrastructure'),
      AppUser(id: 'o_elec', name: 'Kiran Patel', email: 'electrical@citypulse.com', password: 'officer123', role: UserRole.officer, department: 'Electrical'),
      AppUser(id: 'o_sani', name: 'Meena Iyer', email: 'sanitation@citypulse.com', password: 'officer123', role: UserRole.officer, department: 'Sanitation'),
      AppUser(id: 'o_water', name: 'Rahul Verma', email: 'water@citypulse.com', password: 'officer123', role: UserRole.officer, department: 'Water Supply'),
      AppUser(id: 'o_traffic', name: 'Imran Khan', email: 'traffic@citypulse.com', password: 'officer123', role: UserRole.officer, department: 'Traffic Police'),
      AppUser(id: 'o_parks', name: 'Lakshmi Devi', email: 'parks@citypulse.com', password: 'officer123', role: UserRole.officer, department: 'Parks & Horticulture'),
      AppUser(id: 'o_gen', name: 'Vikram Singh', email: 'general@citypulse.com', password: 'officer123', role: UserRole.officer, department: 'General Administration'),
    ];
    complaints = [];
    notifications = [];
    _seq = 1000;

    Complaint mk(
      String cat,
      String title,
      String desc,
      double dLat,
      double dLng,
      int hoursAgo,
      ComplaintStatus st, {
      String reporter = 'u_citizen',
      List<String> sup = const [],
      bool urgent = false,
      int? rating,
      String? feedback,
      String? closeNote,
    }) {
      final category = categoryOf(cat);
      final created = now.subtract(Duration(hours: hoursAgo));
      final reporterName = userById(reporter)?.name ?? 'Citizen';
      final offs = officersIn(category.department);
      final officer = offs.isEmpty ? null : offs.first;
      final c = Complaint(
        id: 'CP-${++_seq}',
        category: cat,
        title: title,
        description: desc,
        lat: demoCenterLat + dLat,
        lng: demoCenterLng + dLng,
        reporterId: reporter,
        urgent: urgent,
        isDemo: true,
        status: ComplaintStatus.submitted,
        department: category.department,
        supporters: List<String>.from(sup),
        createdAt: created,
        updatedAt: created,
        history: [
          StatusEvent(status: ComplaintStatus.submitted, note: 'Complaint registered through the CityPulse app.', by: reporterName, at: created),
        ],
      );
      if (st != ComplaintStatus.submitted && officer != null) {
        c.officerId = officer.id;
        c.status = ComplaintStatus.assigned;
        c.history.add(StatusEvent(
          status: ComplaintStatus.assigned,
          note: 'Assigned to ${officer.name} (${category.department}).',
          by: 'CityPulse auto-router',
          at: created.add(const Duration(minutes: 2)),
        ));
      }
      if (st == ComplaintStatus.inProgress || st == ComplaintStatus.resolved) {
        final t = created.add(Duration(hours: max(1, hoursAgo ~/ 3)));
        c.status = ComplaintStatus.inProgress;
        c.updatedAt = t;
        c.history.add(StatusEvent(
          status: ComplaintStatus.inProgress,
          note: 'Field team dispatched to inspect the site.',
          by: officer?.name ?? 'Officer',
          at: t,
        ));
      }
      if (st == ComplaintStatus.resolved || st == ComplaintStatus.rejected) {
        final t = created.add(Duration(hours: max(2, (hoursAgo * 2) ~/ 3)));
        c.status = st;
        c.updatedAt = t;
        if (st == ComplaintStatus.resolved) c.resolvedAt = t;
        c.history.add(StatusEvent(
          status: st,
          note: closeNote ?? (st == ComplaintStatus.resolved ? 'Repair completed and site verified.' : 'Closed by department.'),
          by: officer?.name ?? 'Officer',
          at: t,
        ));
      }
      c.rating = rating;
      c.feedback = feedback;
      complaints.add(c);
      return c;
    }

    final c1 = mk('pothole', 'Deep pothole near the bus stop',
        'A large pothole has formed right in front of the bus stop. Two-wheelers are swerving dangerously and there was a minor accident yesterday.',
        0.0042, 0.0031, 72, ComplaintStatus.inProgress,
        sup: ['u_priya', 'u_arjun'], urgent: true);
    mk('streetlight', 'Streetlights out on the main road',
        'Five streetlights in a row are not working for a week. The stretch is completely dark at night and unsafe for pedestrians.',
        -0.0035, 0.0022, 120, ComplaintStatus.assigned,
        reporter: 'u_priya', sup: ['u_citizen']);
    mk('garbage', 'Garbage bin overflowing near the market',
        'The community bin has not been cleared for 3 days. Waste is spilling onto the road and attracting stray animals.',
        0.0021, -0.0040, 20, ComplaintStatus.submitted,
        reporter: 'u_arjun');
    mk('water', 'Pipeline leakage wasting drinking water',
        'Clean water is gushing from a broken pipe joint on the footpath since morning.',
        -0.0018, -0.0027, 144, ComplaintStatus.resolved,
        rating: 5, feedback: 'Fixed within a day. Great work by the water team!', closeNote: 'Pipe joint replaced and pressure tested.');
    mk('traffic', 'Traffic signal stuck on red',
        'The signal at the junction has been stuck on red for hours, causing heavy congestion and accident risk.',
        0.0055, -0.0012, 3, ComplaintStatus.assigned,
        reporter: 'u_priya');
    final c6 = mk('drainage', 'Open drain overflowing onto the street',
        'Sewage water is overflowing from an open drain and flooding the lane. Bad smell and health hazard near the school.',
        -0.0050, 0.0045, 216, ComplaintStatus.inProgress,
        sup: ['u_priya']);
    mk('tree', 'Fallen tree blocking the footpath',
        'A tree fell during last night\'s rain and is blocking the entire footpath.',
        0.0012, 0.0058, 48, ComplaintStatus.resolved,
        reporter: 'u_arjun', closeNote: 'Tree cut and removed. Footpath cleared.');
    mk('pothole', 'Broken road surface near the school gate',
        'Road surface is broken near the school gate.',
        -0.0062, -0.0050, 288, ComplaintStatus.rejected,
        reporter: 'u_arjun', closeNote: 'Duplicate of CP-1001. Both locations are being repaired under one work order.');
    mk('streetlight', 'Flickering streetlight in the colony',
        'Streetlight pole number 14 keeps flickering the whole night.',
        0.0030, -0.0065, 96, ComplaintStatus.resolved,
        rating: 4, feedback: 'Fixed, thank you.', closeNote: 'Faulty choke replaced.');

    c1.comments.add(ComplaintComment(by: 'Priya Sharma', role: 'Citizen', text: 'Two bikes skidded here yesterday evening. Please fix it soon!', at: now.subtract(const Duration(hours: 60))));
    c1.comments.add(ComplaintComment(by: 'Suresh Reddy', role: 'Officer', text: 'Material has been ordered. Patching is scheduled for tomorrow morning.', at: now.subtract(const Duration(hours: 20))));
    c6.comments.add(ComplaintComment(by: 'Meena Iyer', role: 'Officer', text: 'A suction truck has been requested. Clearing will start shortly.', at: now.subtract(const Duration(hours: 30))));

    complaints.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _notify('u_citizen', 'Welcome to CityPulse!', 'Report problems around you and track them until they are fixed.', null);
    _notify('u_citizen', 'Complaint CP-1004: Resolved', '"Pipeline leakage wasting drinking water" is resolved.', 'CP-1004');
    _notify('u_citizen', 'Complaint CP-1001: In Progress', 'Work has started on "Deep pothole near the bus stop".', 'CP-1001');
    _notify('o_roads', 'New assignment CP-1001', 'Pothole / Road Damage: Deep pothole near the bus stop', 'CP-1001');
    _notify('u_admin', 'New complaint CP-1003', 'Garbage Overflow • waiting for assignment', 'CP-1003');
  }
}
