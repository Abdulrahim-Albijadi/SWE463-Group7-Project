import 'package:flutter/material.dart';

import '../../models/queue_data.dart';
import '../../widgets/customer/customer_widgets.dart';

class MyQueueScreen extends StatelessWidget {
  const MyQueueScreen({
    super.key,
    required this.state,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.isLeaving = false,
    this.leaveErrorMessage,
  });
  final QueueDemoState state;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isLeaving;
  final String? leaveErrorMessage;

  Future<void> _leave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Leave queue?'),
        content: const Text(
          'You’ll lose your place. Rejoining will put you at the end of the queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: customerTeal)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Leave Queue',
              style: TextStyle(color: customerRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!state.leaveQueue()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only waiting tickets can leave.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      if (isLoading) {
        return CustomerPage(
          title: 'My Queue',
          selected: 1,
          back: true,
          children: const [
            SectionTitle('Your Ticket'),
            SizedBox(height: 24),
            Surface(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your ticket...'),
                ],
              ),
            ),
          ],
        );
      }
      if (errorMessage != null) {
        return CustomerPage(
          title: 'My Queue',
          selected: 1,
          back: true,
          children: [
            const SectionTitle('Your Ticket'),
            const SizedBox(height: 24),
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.error_outline, color: customerRed, size: 32),
                  const SizedBox(height: 12),
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  PrimaryButton(label: 'Retry', onPressed: onRetry),
                ],
              ),
            ),
          ],
        );
      }
      QueueEntry? latest;
      for (final entry in state.entries.reversed) {
        if (entry.customerId == state.currentUser?.id) {
          latest = entry;
          break;
        }
      }
      final ticket = state.myActiveEntry ?? latest;
      final status = ticket?.status;
      final waiting = status == MembershipStatus.waiting;
      final near = waiting && state.customersAhead == 2;
      final skipped = status == MembershipStatus.skipped;
      final left = status == MembershipStatus.left;
      final terminal = status == MembershipStatus.served || skipped || left;
      final accent = skipped
          ? customerRed
          : left
          ? const Color(0xFF5F6368)
          : customerTeal;
      final border = skipped
          ? const Color(0xFFF2C6C2)
          : left
          ? const Color(0xFFCBD5E1)
          : const Color(0xFFB2DFDB);
      final fill = skipped
          ? const Color(0xFFFFF5F5)
          : left
          ? const Color(0xFFF8FAFC)
          : const Color(0xFFF0FDFA);
      final name = state.queue?.name ?? 'Service queue';
      final title = switch (status) {
        MembershipStatus.called => 'It’s your turn!',
        MembershipStatus.served => 'Your service is complete.',
        MembershipStatus.skipped => 'You missed your turn.',
        MembershipStatus.left => 'You left the queue.',
        _ => '',
      };
      final message = switch (status) {
        MembershipStatus.called => 'Please proceed to $name now.',
        MembershipStatus.served => 'Thank you for using QueueLess.',
        MembershipStatus.skipped => 'Rejoin the queue to get a new ticket.',
        MembershipStatus.left => 'Your ticket is no longer active.',
        _ =>
          near
              ? 'Your turn is near. Please be ready.'
              : 'We’ll notify you when your turn is near.',
      };
      final statusLabel = switch (status) {
        MembershipStatus.waiting => 'Waiting',
        MembershipStatus.called => 'Called',
        MembershipStatus.served => 'Served',
        MembershipStatus.skipped => 'Skipped',
        MembershipStatus.left => 'Left',
        null => '',
      };
      return CustomerPage(
        title: 'My Queue',
        selected: 1,
        back: true,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionTitle(
                  ticket == null ? 'No Active Queue' : 'Your Ticket',
                ),
              ),
              if (ticket != null) ...[
                Icon(
                  status == MembershipStatus.served
                      ? Icons.check
                      : skipped
                      ? Icons.priority_high
                      : Icons.circle,
                  size: status == MembershipStatus.served || skipped ? 16 : 7,
                  color: waiting ? customerAmber : accent,
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: waiting ? customerAmber : accent,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          if (ticket == null)
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'You haven’t joined a queue yet.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text('Browse available queues to get started.'),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Browse Queues',
                    onPressed: () => customerHome(context),
                  ),
                ],
              ),
            )
          else
            Surface(
              color: fill,
              border: border,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: state.queue == null
                        ? Text(name)
                        : ServiceHeader(queue: state.queue!),
                  ),
                  const SizedBox(height: 16),
                  DashedDivider(color: border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'YOUR TICKET NUMBER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: customerMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '#${ticket.ticketNumber}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 64,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (waiting) ...[
                          Stats(
                            value1: '${state.customersAhead ?? 0}',
                            label1: 'Customers ahead',
                            value2: '${state.estimatedWaitMinutes ?? 0} min',
                            label2: 'Estimated wait',
                            color: Colors.white,
                          ),
                          const SizedBox(height: 28),
                        ],
                        Notice(
                          title: title.isEmpty ? null : title,
                          message: message,
                          titleSize: 20,
                          color: near
                              ? customerAmber
                              : left
                              ? const Color(0xFF475569)
                              : accent,
                          background: near
                              ? const Color(0xFFFFF3E0)
                              : skipped
                              ? const Color(0xFFFDE8E7)
                              : left
                              ? const Color(0xFFEEF2F6)
                              : const Color(0xFFE0F2F1),
                        ),
                        if (waiting &&
                            !isLeaving &&
                            leaveErrorMessage != null) ...[
                          const SizedBox(height: 16),
                          Notice(
                            title: 'Could not leave the queue',
                            message: leaveErrorMessage!,
                            color: customerRed,
                            background: const Color(0xFFFFEBEE),
                            icon: Icons.error_outline,
                          ),
                        ],
                        if (waiting && isLeaving) ...[
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator()),
                        ],
                        if (waiting || terminal) const SizedBox(height: 28),
                        if (waiting)
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: customerRed,
                                side: const BorderSide(color: customerRed),
                                minimumSize: const Size(110, 48),
                              ),
                              onPressed: isLeaving
                                  ? null
                                  : () => _leave(context),
                              child: Text(
                                isLeaving ? 'Leaving...' : 'Leave Queue',
                              ),
                            ),
                          ),
                        if (terminal)
                          PrimaryButton(
                            label: 'Browse Queues',
                            onPressed: () => customerHome(context),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
