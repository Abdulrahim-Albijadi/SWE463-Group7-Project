import 'package:flutter/foundation.dart';

enum UserRole { customer, provider }

enum MembershipStatus { waiting, called, served, skipped, left }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
  final String id;
  final String name;
  final String email;
  final UserRole role;
}

class ServiceQueue {
  const ServiceQueue({
    required this.id,
    required this.providerId,
    required this.name,
    required this.description,
    required this.averageServiceMinutes,
    required this.isOpen,
  });
  final String id;
  final String providerId;
  final String name;
  final String description;
  final int averageServiceMinutes;
  final bool isOpen;
}

class QueueEntry {
  QueueEntry({
    required this.customerId,
    required this.customerName,
    required this.queueId,
    required this.ticketNumber,
    required this.joinedAt,
    required this.status,
  });
  final String customerId;
  final String customerName;
  final String queueId;
  final int ticketNumber;
  final DateTime joinedAt;
  MembershipStatus status;
}

class QueueNotification {
  const QueueNotification({
    required this.recipientId,
    required this.type,
    required this.message,
    required this.createdAt,
  });
  final String recipientId;
  final String type;
  final String message;
  final DateTime createdAt;
}

class QueueDemoState extends ChangeNotifier {
  AppUser? currentUser;
  ServiceQueue? queue = const ServiceQueue(
    id: 'campus-barber',
    providerId: 'provider-1',
    name: 'Campus Barber',
    description: 'Barber service',
    averageServiceMinutes: 5,
    isOpen: true,
  );

  final List<QueueEntry> entries = [
    QueueEntry(
      customerId: 'c09',
      customerName: 'Ahmed Ali',
      queueId: 'campus-barber',
      ticketNumber: 9,
      joinedAt: DateTime(2026, 10, 13, 10, 0),
      status: MembershipStatus.called,
    ),
    QueueEntry(
      customerId: 'c10',
      customerName: 'Sara Hassan',
      queueId: 'campus-barber',
      ticketNumber: 10,
      joinedAt: DateTime(2026, 10, 13, 10, 2),
      status: MembershipStatus.waiting,
    ),
    QueueEntry(
      customerId: 'c11',
      customerName: 'Omar Khalid',
      queueId: 'campus-barber',
      ticketNumber: 11,
      joinedAt: DateTime(2026, 10, 13, 10, 4),
      status: MembershipStatus.waiting,
    ),
    QueueEntry(
      customerId: 'customer-1',
      customerName: 'Noor Abdullah',
      queueId: 'campus-barber',
      ticketNumber: 12,
      joinedAt: DateTime(2026, 10, 13, 10, 6),
      status: MembershipStatus.waiting,
    ),
  ];

  final List<QueueNotification> notifications = [];

  void signInAs(UserRole role, {String? email, String? name}) {
    currentUser = AppUser(
      id: role == UserRole.customer ? 'customer-1' : 'provider-1',
      name:
          name ??
          (role == UserRole.customer ? 'Noor Abdullah' : 'Campus Barber Owner'),
      email:
          email ??
          (role == UserRole.customer
              ? 'customer@example.com'
              : 'provider@example.com'),
      role: role,
    );
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  List<QueueEntry> get activeEntries {
    final active = entries
        .where(
          (e) =>
              e.status == MembershipStatus.called ||
              e.status == MembershipStatus.waiting,
        )
        .toList();
    active.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return active;
  }

  List<QueueEntry> get waitingEntries => activeEntries
      .where((entry) => entry.status == MembershipStatus.waiting)
      .toList();

  QueueEntry? get calledEntry {
    for (final entry in entries) {
      if (entry.status == MembershipStatus.called) return entry;
    }
    return null;
  }

  QueueEntry? get myActiveEntry {
    final id = currentUser?.id;
    for (final entry in activeEntries) {
      if (entry.customerId == id) return entry;
    }
    return null;
  }

  int? get myPosition {
    final membership = myActiveEntry;
    if (membership == null) return null;
    return activeEntries.indexOf(membership) + 1;
  }

  int? get customersAhead => myPosition == null ? null : myPosition! - 1;

  int? get estimatedWaitMinutes => queue == null || customersAhead == null
      ? null
      : customersAhead! * queue!.averageServiceMinutes;

  bool joinQueue() {
    if (currentUser?.role != UserRole.customer ||
        queue == null ||
        !queue!.isOpen ||
        myActiveEntry != null) {
      return false;
    }
    final nextTicket =
        entries.fold<int>(
          0,
          (value, entry) =>
              entry.ticketNumber > value ? entry.ticketNumber : value,
        ) +
        1;
    entries.add(
      QueueEntry(
        customerId: currentUser!.id,
        customerName: currentUser!.name,
        queueId: queue!.id,
        ticketNumber: nextTicket,
        joinedAt: DateTime.now(),
        status: MembershipStatus.waiting,
      ),
    );
    notifyListeners();
    return true;
  }

  bool leaveQueue() {
    final entry = myActiveEntry;
    if (entry == null || entry.status != MembershipStatus.waiting) return false;
    entry.status = MembershipStatus.left;
    notifyListeners();
    return true;
  }

  bool callNext() {
    if (calledEntry != null || waitingEntries.isEmpty) return false;
    waitingEntries.first.status = MembershipStatus.called;
    notifications.add(
      QueueNotification(
        recipientId: calledEntry!.customerId,
        type: 'called',
        message: 'It is your turn at ${queue?.name ?? 'the queue'}.',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  bool markServed() => _finishCalled(MembershipStatus.served);
  bool skipCalled() => _finishCalled(MembershipStatus.skipped);

  bool _finishCalled(MembershipStatus nextStatus) {
    final called = calledEntry;
    if (called == null) return false;
    called.status = nextStatus;
    // Demo notification, not a push notification.
    final approaching = activeEntries
        .where((e) => e.status == MembershipStatus.waiting)
        .toList();
    if (approaching.length > 2) {
      final customer = approaching[2];
      notifications.add(
        QueueNotification(
          recipientId: customer.customerId,
          type: 'approaching',
          message: 'Two customers are ahead of you.',
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
    return true;
  }

  bool createQueue({
    required String name,
    required String description,
    required int minutes,
  }) {
    // One queue per provider; sample queue exists initially.
    if (currentUser?.role != UserRole.provider ||
        queue != null ||
        name.trim().isEmpty ||
        description.trim().isEmpty ||
        minutes <= 0) {
      return false;
    }
    queue = ServiceQueue(
      id: 'new-queue',
      providerId: currentUser!.id,
      name: name.trim(),
      description: description.trim(),
      averageServiceMinutes: minutes,
      isOpen: true,
    );
    notifyListeners();
    return true;
  }
}
