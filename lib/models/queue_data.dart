

// Plain data used across the app. These classes hold no state and have no
// setters. Shared state lives in the Providers (lib/providers) and the queue
// rules live in logic/queue_rules.dart.
enum UserRole { customer, provider }

enum MembershipStatus { waiting, called, served, skipped, left }

// Near Turn is a display condition (two customers ahead), not a
// MembershipStatus. Each type is shown to the customer once per ticket.
enum NotificationType { nearTurn, called }

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
  const QueueEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.queueId,
    required this.ticketNumber,
    required this.joinedAt,
    required this.status,
  });
  final String id; 
  final String customerId;
  final String customerName;
  final String queueId;
  final int ticketNumber;
  final DateTime joinedAt;
  final MembershipStatus status;

  
    bool get isActive =>
      status == MembershipStatus.waiting || status == MembershipStatus.called;


  // Creates a copy of the current QueueEntry with optional new values for its properties.
  QueueEntry copyWith({MembershipStatus? status}) => QueueEntry(
    id: id, // ?
    customerId: customerId,
    customerName: customerName,
    queueId: queueId,
    ticketNumber: ticketNumber,
    joinedAt: joinedAt,
    status: status ?? this.status,
  );
}




class QueueNotification {
  const QueueNotification({
    required this.recipientId,
    required this.type,
    required this.message,
    required this.createdAt,
  });
  final String recipientId;
  final NotificationType type;
  final String message;
  final DateTime createdAt;
}



// A queue with the customer counts shown on Customer Home and Queue Details.
class QueueSummary {
  const QueueSummary({
    required this.queue,
    required this.waitingCount,
    required this.calledCount,
  });
  final ServiceQueue queue;
  final int waitingCount;
  final int calledCount;

  int get activeCount => waitingCount + calledCount;
}



