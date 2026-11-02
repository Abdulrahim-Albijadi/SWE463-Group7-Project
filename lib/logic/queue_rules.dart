import '../models/queue_data.dart';

enum OperationError {
  notSignedIn,
  wrongRole,
  queueNotFound,
  queueClosed,
  alreadyMember,
  notWaiting,
  alreadyCalled,
  nobodyWaiting,
  nothingCalled,
  hasQueue,
  invalidInput,
  notOwner,
  busy,
  invalidCredentials,
  emailInUse,
  failed,
}

const Map<OperationError, String> _defaultMessages = {
  OperationError.notSignedIn: 'Please sign in first.',
  OperationError.wrongRole: 'This action is not available for your account.',
  OperationError.queueNotFound: 'This queue is unavailable.',
  OperationError.queueClosed: 'This queue is closed.',
  OperationError.alreadyMember: 'You already have an active ticket.',
  OperationError.notWaiting: 'Only waiting tickets can leave.',
  OperationError.alreadyCalled: 'Finish or skip the called customer first.',
  OperationError.nobodyWaiting: 'No customers are waiting.',
  OperationError.nothingCalled: 'No customer is currently called.',
  OperationError.hasQueue: 'Each provider can create only one queue.',
  OperationError.invalidInput:
      'Enter a queue name and an average time above 0 minutes.',
  OperationError.notOwner: 'You cannot change this queue or ticket.',
  OperationError.busy: 'Please wait for the current action to finish.',
  OperationError.invalidCredentials: 'Incorrect email or password.',
  OperationError.emailInUse: 'An account with this email already exists.',
  OperationError.failed: 'Something went wrong. Please try again.',
};

class OperationResult {
  const OperationResult._(this.error, this.message);

  static const OperationResult ok = OperationResult._(null, null);

  factory OperationResult.failure(OperationError error, [String? detail]) =>
      OperationResult._(error, detail ?? _defaultMessages[error]);

  final OperationError? error;
  final String? message;

  bool get isOk => error == null;
}

// Result of signing in or registering. The user is set only on success.
class AuthOutcome {
  const AuthOutcome(this.result, [this.user]);
  final OperationResult result;
  final AppUser? user;

  bool get isOk => result.isOk;
}

// Queue rules used by Providers and by every repository, so the rules exist
// in one place and are not repeated inside screens.
class QueueRules {
  const QueueRules._();

  // Near Turn is a display condition, not a membership status.
  static const int nearTurnAhead = 2;

  // Waiting and called entries in joining order. Ticket numbers break ties.
  static List<QueueEntry> activeEntries(Iterable<QueueEntry> entries) {
    final active = entries.where((entry) => entry.isActive).toList();
    active.sort((a, b) {
      final byTime = a.joinedAt.compareTo(b.joinedAt);
      return byTime != 0 ? byTime : a.ticketNumber.compareTo(b.ticketNumber);
    });
    return active;
  }

  static List<QueueEntry> waitingEntries(Iterable<QueueEntry> entries) =>
      activeEntries(
        entries,
      ).where((entry) => entry.status == MembershipStatus.waiting).toList();

  static QueueEntry? calledEntry(Iterable<QueueEntry> entries) {
    for (final entry in activeEntries(entries)) {
      if (entry.status == MembershipStatus.called) return entry;
    }
    return null;
  }

  // Position starts at 1. Null when the entry is not active in this queue.
  static int? positionOf(Iterable<QueueEntry> entries, String entryId) {
    final index = activeEntries(
      entries,
    ).indexWhere((entry) => entry.id == entryId);
    return index < 0 ? null : index + 1;
  }

  // The called customer counts as ahead of every waiting customer.
  static int? customersAhead(Iterable<QueueEntry> entries, String entryId) {
    final position = positionOf(entries, entryId);
    return position == null ? null : position - 1;
  }

  static int estimatedWaitMinutes({
    required int customersAhead,
    required int averageServiceMinutes,
  }) => customersAhead * averageServiceMinutes;

  static bool isNearTurn({
    required QueueEntry entry,
    required int customersAhead,
  }) =>
      entry.status == MembershipStatus.waiting &&
      customersAhead == nearTurnAhead;

  // Tickets are fixed: finished and left entries still count.
  static int nextTicketNumber(Iterable<QueueEntry> queueEntries) =>
      queueEntries.fold<int>(
        0,
        (value, entry) =>
            entry.ticketNumber > value ? entry.ticketNumber : value,
      ) +
      1;

  static OperationResult checkJoin({
    required AppUser? user,
    required ServiceQueue? queue,
    required bool hasActiveMembership,
  }) {
    if (user == null) {
      return OperationResult.failure(OperationError.notSignedIn);
    }
    if (user.role != UserRole.customer) {
      return OperationResult.failure(OperationError.wrongRole);
    }
    if (queue == null) {
      return OperationResult.failure(OperationError.queueNotFound);
    }
    if (!queue.isOpen) {
      return OperationResult.failure(OperationError.queueClosed);
    }
    if (hasActiveMembership) {
      return OperationResult.failure(OperationError.alreadyMember);
    }
    return OperationResult.ok;
  }

  // Only a waiting ticket can leave. A called customer cannot.
  static OperationResult checkLeave(QueueEntry? entry) =>
      entry == null || entry.status != MembershipStatus.waiting
      ? OperationResult.failure(OperationError.notWaiting)
      : OperationResult.ok;

  static OperationResult checkCallNext(Iterable<QueueEntry> queueEntries) {
    if (calledEntry(queueEntries) != null) {
      return OperationResult.failure(OperationError.alreadyCalled);
    }
    if (waitingEntries(queueEntries).isEmpty) {
      return OperationResult.failure(OperationError.nobodyWaiting);
    }
    return OperationResult.ok;
  }

  // Serving and skipping apply only to the called entry.
  static OperationResult checkFinishCalled(Iterable<QueueEntry> queueEntries) =>
      calledEntry(queueEntries) == null
      ? OperationResult.failure(OperationError.nothingCalled)
      : OperationResult.ok;

  static OperationResult checkCreateQueue({
    required AppUser? user,
    required bool hasQueue,
    required String name,
    required int averageServiceMinutes,
  }) {
    if (user == null) {
      return OperationResult.failure(OperationError.notSignedIn);
    }
    if (user.role != UserRole.provider) {
      return OperationResult.failure(OperationError.wrongRole);
    }
    if (hasQueue) {
      return OperationResult.failure(OperationError.hasQueue);
    }
    if (name.trim().isEmpty || averageServiceMinutes <= 0) {
      return OperationResult.failure(OperationError.invalidInput);
    }
    return OperationResult.ok;
  }
}