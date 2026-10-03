import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Default centre used for demo data before the phone's real GPS is known.
const double demoCenterLat = 17.3850;
const double demoCenterLng = 78.4867;

// ───────────────────────── Users ─────────────────────────
enum UserRole { citizen, officer, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.citizen => 'Citizen',
        UserRole.officer => 'Department Officer',
        UserRole.admin => 'Administrator',
      };
  String get short => switch (this) {
        UserRole.citizen => 'Citizen',
        UserRole.officer => 'Officer',
        UserRole.admin => 'Admin',
      };
  IconData get icon => switch (this) {
        UserRole.citizen => Icons.person_outline_rounded,
        UserRole.officer => Icons.engineering_outlined,
        UserRole.admin => Icons.admin_panel_settings_outlined,
      };
  Color get color => switch (this) {
        UserRole.citizen => const Color(0xFF0F766E),
        UserRole.officer => const Color(0xFF1D4ED8),
        UserRole.admin => const Color(0xFF7C3AED),
      };
}

class AppUser {
  final String id;
  String name;
  String email;
  String password;
  String phone;
  UserRole role;
  String? department;
  bool active;
  int points;
  DateTime joined;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
    this.role = UserRole.citizen,
    this.department,
    this.active = true,
    this.points = 0,
    DateTime? joined,
  }) : joined = joined ?? DateTime.now();

  String get initials {
    final p = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first[0].toUpperCase();
    return (p.first[0] + p.last[0]).toUpperCase();
  }

  String get firstName => name.trim().split(' ').first;

  String get level => points >= 150
      ? 'City Hero'
      : points >= 80
          ? 'Civic Champion'
          : points >= 30
              ? 'Active Citizen'
              : 'Newcomer';

  int get levelStart => points >= 150 ? 150 : points >= 80 ? 80 : points >= 30 ? 30 : 0;
  int get levelEnd => points >= 150 ? 150 : points >= 80 ? 150 : points >= 30 ? 80 : 30;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role.name,
        'department': department,
        'active': active,
        'points': points,
        'joined': joined.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        password: j['password'],
        phone: j['phone'] ?? '',
        role: UserRole.values.byName(j['role']),
        department: j['department'],
        active: j['active'] ?? true,
        points: j['points'] ?? 0,
        joined: DateTime.tryParse(j['joined'] ?? ''),
      );
}

// ───────────────────────── Categories ─────────────────────────
class IssueCategory {
  final String key;
  final String label;
  final String short;
  final IconData icon;
  final Color color;
  final String department;
  final int severity; // 1..5

  const IssueCategory(this.key, this.label, this.short, this.icon, this.color, this.department, this.severity);
}

const List<IssueCategory> categories = [
  IssueCategory('pothole', 'Pothole / Road Damage', 'Pothole', Icons.add_road, Color(0xFFEA580C), 'Roads & Infrastructure', 4),
  IssueCategory('streetlight', 'Streetlight Fault', 'Streetlight', Icons.lightbulb_outline_rounded, Color(0xFFCA8A04), 'Electrical', 3),
  IssueCategory('garbage', 'Garbage Overflow', 'Garbage', Icons.delete_outline_rounded, Color(0xFF16A34A), 'Sanitation', 3),
  IssueCategory('water', 'Water Leakage', 'Water Leak', Icons.water_drop_outlined, Color(0xFF2563EB), 'Water Supply', 4),
  IssueCategory('traffic', 'Traffic Issue', 'Traffic', Icons.traffic_outlined, Color(0xFFDC2626), 'Traffic Police', 5),
  IssueCategory('drainage', 'Drainage / Sewage', 'Drainage', Icons.waves_rounded, Color(0xFF92400E), 'Sanitation', 4),
  IssueCategory('tree', 'Fallen Tree', 'Fallen Tree', Icons.park_outlined, Color(0xFF4D7C0F), 'Parks & Horticulture', 3),
  IssueCategory('other', 'Other Civic Issue', 'Other', Icons.report_outlined, Color(0xFF475569), 'General Administration', 2),
];

IssueCategory categoryOf(String key) =>
    categories.firstWhere((c) => c.key == key, orElse: () => categories.last);

final List<String> departments = categories.map((c) => c.department).toSet().toList();

// ───────────────────────── Status & priority ─────────────────────────
enum ComplaintStatus { submitted, assigned, inProgress, resolved, rejected }

extension ComplaintStatusX on ComplaintStatus {
  String get label => switch (this) {
        ComplaintStatus.submitted => 'Submitted',
        ComplaintStatus.assigned => 'Assigned',
        ComplaintStatus.inProgress => 'In Progress',
        ComplaintStatus.resolved => 'Resolved',
        ComplaintStatus.rejected => 'Rejected',
      };
  Color get color => switch (this) {
        ComplaintStatus.submitted => const Color(0xFF64748B),
        ComplaintStatus.assigned => const Color(0xFF7C3AED),
        ComplaintStatus.inProgress => const Color(0xFFD97706),
        ComplaintStatus.resolved => const Color(0xFF16A34A),
        ComplaintStatus.rejected => const Color(0xFFDC2626),
      };
  IconData get icon => switch (this) {
        ComplaintStatus.submitted => Icons.outbox_rounded,
        ComplaintStatus.assigned => Icons.assignment_ind_outlined,
        ComplaintStatus.inProgress => Icons.construction_rounded,
        ComplaintStatus.resolved => Icons.check_circle_outline_rounded,
        ComplaintStatus.rejected => Icons.cancel_outlined,
      };
  bool get isOpen =>
      this == ComplaintStatus.submitted || this == ComplaintStatus.assigned || this == ComplaintStatus.inProgress;
}

enum Priority { low, medium, high, critical }

extension PriorityX on Priority {
  String get label => switch (this) {
        Priority.low => 'Low',
        Priority.medium => 'Medium',
        Priority.high => 'High',
        Priority.critical => 'Critical',
      };
  Color get color => switch (this) {
        Priority.low => const Color(0xFF0891B2),
        Priority.medium => const Color(0xFFCA8A04),
        Priority.high => const Color(0xFFEA580C),
        Priority.critical => const Color(0xFFDC2626),
      };
}

// ───────────────────────── Sub-records ─────────────────────────
class StatusEvent {
  final ComplaintStatus status;
  final String note;
  final String by;
  final DateTime at;

  StatusEvent({required this.status, required this.note, required this.by, required this.at});

  Map<String, dynamic> toJson() => {'status': status.name, 'note': note, 'by': by, 'at': at.toIso8601String()};

  factory StatusEvent.fromJson(Map<String, dynamic> j) => StatusEvent(
        status: ComplaintStatus.values.byName(j['status']),
        note: j['note'] ?? '',
        by: j['by'] ?? '',
        at: DateTime.parse(j['at']),
      );
}

class ComplaintComment {
  final String by;
  final String role;
  final String text;
  final DateTime at;

  ComplaintComment({required this.by, required this.role, required this.text, required this.at});

  Map<String, dynamic> toJson() => {'by': by, 'role': role, 'text': text, 'at': at.toIso8601String()};

  factory ComplaintComment.fromJson(Map<String, dynamic> j) => ComplaintComment(
        by: j['by'] ?? '',
        role: j['role'] ?? '',
        text: j['text'] ?? '',
        at: DateTime.parse(j['at']),
      );
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? complaintId;
  final DateTime at;
  bool read;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.complaintId,
    required this.at,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'complaintId': complaintId,
        'at': at.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        userId: j['userId'],
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        complaintId: j['complaintId'],
        at: DateTime.parse(j['at']),
        read: j['read'] ?? false,
      );
}

// ───────────────────────── Complaint ─────────────────────────
class Complaint {
  final String id;
  String category;
  String title;
  String description;
  String address;
  double lat;
  double lng;
  List<String> photos;
  List<String> resolutionPhotos;
  List<String> supporters;
  final String reporterId;
  bool anonymous;
  bool urgent;
  bool isDemo;
  ComplaintStatus status;
  String department;
  String? officerId;
  List<StatusEvent> history;
  List<ComplaintComment> comments;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? resolvedAt;
  int? rating;
  String? feedback;

  Complaint({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    this.address = '',
    required this.lat,
    required this.lng,
    List<String>? photos,
    List<String>? resolutionPhotos,
    List<String>? supporters,
    required this.reporterId,
    this.anonymous = false,
    this.urgent = false,
    this.isDemo = false,
    required this.status,
    required this.department,
    this.officerId,
    List<StatusEvent>? history,
    List<ComplaintComment>? comments,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.rating,
    this.feedback,
  })  : photos = photos ?? [],
        resolutionPhotos = resolutionPhotos ?? [],
        supporters = supporters ?? [],
        history = history ?? [],
        comments = comments ?? [];

  bool get isOpen => status.isOpen;

  static const _urgentWords = [
    'accident', 'danger', 'injur', 'fire', 'school', 'hospital', 'child',
    'shock', 'live wire', 'flood', 'blocked', 'collapse', 'emergency',
  ];

  /// Smart priority score: category severity + community support +
  /// urgency keywords + waiting time.
  int get priorityScore {
    var s = categoryOf(category).severity * 10;
    s += supporters.length * 6;
    if (urgent) s += 15;
    final text = '$title $description'.toLowerCase();
    if (_urgentWords.any(text.contains)) s += 15;
    if (isOpen) s += math.min(DateTime.now().difference(createdAt).inDays * 2, 20);
    return s;
  }

  Priority get priority {
    final s = priorityScore;
    if (s >= 75) return Priority.critical;
    if (s >= 55) return Priority.high;
    if (s >= 40) return Priority.medium;
    return Priority.low;
  }

  /// Service-level target in hours, by priority.
  int get slaHours => switch (priority) {
        Priority.critical => 24,
        Priority.high => 72,
        Priority.medium => 120,
        Priority.low => 168,
      };

  bool get overdue => isOpen && DateTime.now().difference(createdAt).inHours > slaHours;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'description': description,
        'address': address,
        'lat': lat,
        'lng': lng,
        'photos': photos,
        'resolutionPhotos': resolutionPhotos,
        'supporters': supporters,
        'reporterId': reporterId,
        'anonymous': anonymous,
        'urgent': urgent,
        'isDemo': isDemo,
        'status': status.name,
        'department': department,
        'officerId': officerId,
        'history': history.map((e) => e.toJson()).toList(),
        'comments': comments.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'rating': rating,
        'feedback': feedback,
      };

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: j['id'],
        category: j['category'],
        title: j['title'],
        description: j['description'] ?? '',
        address: j['address'] ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        photos: List<String>.from(j['photos'] ?? const []),
        resolutionPhotos: List<String>.from(j['resolutionPhotos'] ?? const []),
        supporters: List<String>.from(j['supporters'] ?? const []),
        reporterId: j['reporterId'],
        anonymous: j['anonymous'] ?? false,
        urgent: j['urgent'] ?? false,
        isDemo: j['isDemo'] ?? false,
        status: ComplaintStatus.values.byName(j['status']),
        department: j['department'],
        officerId: j['officerId'],
        history: ((j['history'] ?? const []) as List)
            .map((e) => StatusEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        comments: ((j['comments'] ?? const []) as List)
            .map((e) => ComplaintComment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: DateTime.parse(j['updatedAt']),
        resolvedAt: j['resolvedAt'] == null ? null : DateTime.parse(j['resolvedAt']),
        rating: j['rating'],
        feedback: j['feedback'],
      );
}

// ───────────────────────── Helpers ─────────────────────────
double _rad(double d) => d * math.pi / 180;

/// Great-circle distance in metres (haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

String formatDistance(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return DateFormat('d MMM yyyy').format(t);
}

String formatDate(DateTime t) => DateFormat('d MMM yyyy, h:mm a').format(t);

String formatDuration(Duration d) {
  if (d.inHours < 1) return '${d.inMinutes} min';
  if (d.inHours < 48) return '${d.inHours} h';
  return '${(d.inHours / 24).toStringAsFixed(1)} days';
}
