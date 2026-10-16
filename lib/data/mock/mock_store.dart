import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/dates.dart';
import '../models/models.dart';
import '../services/group_code_generator.dart';

/// PROTOTYPE ONLY. An in-memory "database" shared by the mock repositories so
/// every screen sees the same state during a session. Nothing is persisted:
/// restarting the app restores the sample data.
class MockStore {
  MockStore({
    this.latency = const Duration(milliseconds: 300),
    GroupCodeGenerator? codeGenerator,
    DateTime Function()? clock,
  }) : codeGenerator = codeGenerator ?? RandomGroupCodeGenerator(),
       _clock = clock ?? DateTime.now;

  /// Simulated network delay so loading states are visible.
  final Duration latency;
  final GroupCodeGenerator codeGenerator;
  final DateTime Function() _clock;

  final Map<String, AppUser> users = {};
  final Map<String, Group> groups = {};
  final Map<String, GroupMember> members = {};
  final Map<String, Expense> expenses = {};
  final Map<String, Contribution> contributions = {};
  final Map<String, JoinRequest> joinRequests = {};
  String? sessionUserId;

  static const Uuid _uuid = Uuid();
  final StreamController<void> _changes = StreamController<void>.broadcast();

  DateTime now() => _clock();
  DateTime todayDate() => dateOnly(_clock());

  String newId(String prefix) => '${prefix}_${_uuid.v4()}';

  /// Tells all watchers that data changed.
  void notify() => _changes.add(null);

  Future<void> simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  /// A stream that emits `read()` now and after every change. If `read`
  /// throws (e.g. access was revoked), the error is emitted instead.
  Stream<T> watch<T>(T Function() read) {
    StreamSubscription<void>? subscription;
    late final StreamController<T> controller;
    void emit() {
      if (controller.isClosed) return;
      try {
        controller.add(read());
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        emit();
        subscription = _changes.stream.listen((_) => emit());
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  // ---- Lookups shared by the mock repositories ----

  AppUser? userByEmail(String email) {
    final key = email.trim().toLowerCase();
    for (final user in users.values) {
      if (user.email == key) return user;
    }
    return null;
  }

  Group requireGroup(String groupId) {
    final group = groups[groupId];
    if (group == null) throw const NotFoundException('This group no longer exists.');
    return group;
  }

  GroupMember? activeMembership(String groupId, String userId) {
    for (final m in members.values) {
      if (m.groupId == groupId && m.userId == userId && m.isActive) return m;
    }
    return null;
  }

  /// Throws unless [userId] is an active member of [groupId].
  GroupMember requireActiveMember(String groupId, String userId) {
    requireGroup(groupId);
    final member = activeMembership(groupId, userId);
    if (member == null) {
      throw const PermissionDeniedException('You are not an active member of this group.');
    }
    return member;
  }

  List<GroupMember> membersOf(String groupId) => members.values.where((m) => m.groupId == groupId).toList();

  /// The account (or placeholder) for [email]; without an email, a new
  /// offline member who will never be linked to an account.
  AppUser findOrCreateMemberUser({required String name, String? email, String? phone}) {
    final key = email?.trim().toLowerCase();
    if (key != null && key.isNotEmpty) {
      final existing = userByEmail(key);
      if (existing != null) return existing;
    }
    final user = AppUser(
      id: newId('user'),
      name: name,
      email: key == null || key.isEmpty ? null : key,
      phone: phone,
      isRegistered: false,
      hasCompletedProfile: false,
      createdAt: now(),
    );
    users[user.id] = user;
    return user;
  }

  Group? groupByCode(String code) {
    for (final group in groups.values) {
      if (group.code == code) return group;
    }
    return null;
  }

  String uniqueGroupCode() {
    while (true) {
      final code = codeGenerator.generate();
      if (groupByCode(code) == null) return code;
    }
  }
}
