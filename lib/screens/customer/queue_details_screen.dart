import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/membership_provider.dart';
import '../../providers/provider_support.dart';
import '../../providers/queue_provider.dart';
import '../../widgets/customer/customer_widgets.dart';

class QueueDetailsScreen extends StatelessWidget {
  const QueueDetailsScreen({super.key});

  Future<void> _join(BuildContext context, String queueId) async {
    final membership = context.read<MembershipProvider>();
    final result = await membership.join(queueId);

    if (!context.mounted) return;

    if (result.isOk) {
      Navigator.pushReplacementNamed(context, '/my-queue');
    } else if (membership.joinError == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? 'Could not join the queue. Please retry.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queues = context.watch<QueueProvider>();
    final membership = context.watch<MembershipProvider>();

    final summary = queues.selected;
    final queue = summary?.queue;
    final hasTicket = membership.hasActiveMembership;
    final hasTicketHere =
        hasTicket && membership.currentEntry?.queueId == queue?.id;
    final isLoading =
        queues.status == LoadStatus.loading ||
        membership.status == LoadStatus.loading;
    final hasError =
        queues.status == LoadStatus.error ||
        membership.status == LoadStatus.error;
    final isBusy = membership.isJoining || membership.isLeaving;

    final ahead = hasTicketHere
        ? membership.customersAhead
        : summary == null
        ? null
        : queues.customersAheadIfJoined(summary);

    final wait = hasTicketHere
        ? membership.estimatedWaitMinutes
        : summary == null
        ? null
        : queues.estimatedWaitIfJoined(summary);

    return CustomerPage(
      title: 'Queue Details',
      selected: 0,
      back: true,
      children: [
        const SectionTitle('Queue Information'),
        const SizedBox(height: 24),
        if (isLoading)
          const Surface(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading queue details...'),
              ],
            ),
          )
        else if (hasError)
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline, color: customerRed, size: 32),
                const SizedBox(height: 12),
                Text(
                  queues.error ??
                      membership.loadError ??
                      'Could not load queue details.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Retry',
                  onPressed: () {
                    queues.retry();
                    membership.retry();
                  },
                ),
              ],
            ),
          )
        else if (queue == null)
          const Surface(
            child: Text(
              'This queue is unavailable. Return Home and select a queue.',
            ),
          )
        else ...[
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ServiceHeader(queue: queue, showOpen: true),
                const SizedBox(height: 28),
                Stats(
                  value1: ahead?.toString() ?? '...',
                  label1: 'Customers ahead',
                  value2: wait == null ? '...' : '$wait min',
                  label2: 'Estimated wait',
                ),
                const SizedBox(height: 28),
                Text(
                  'Average service time: '
                  '${queue.averageServiceMinutes} min per customer',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 28),
                if (!membership.isJoining && membership.joinError != null) ...[
                  Notice(
                    title: 'Could not join the queue',
                    message: membership.joinError!,
                    color: customerRed,
                    background: const Color(0xFFFFEBEE),
                    icon: Icons.error_outline,
                  ),
                  const SizedBox(height: 16),
                ],
                if (membership.isJoining) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                ],
                PrimaryButton(
                  label: membership.isJoining
                      ? 'Joining...'
                      : hasTicket
                      ? 'Cannot Join'
                      : 'Join Queue',
                  onPressed: isBusy || hasTicket || !queue.isOpen
                      ? null
                      : () => _join(context, queue.id),
                ),
              ],
            ),
          ),
          if (hasTicket) ...[
            const SizedBox(height: 16),
            const Notice(
              title: 'You already have an active ticket',
              message: 'Open My Queue to view your current ticket.',
              color: customerAmber,
              background: Color(0xFFFFF3E0),
              icon: Icons.info,
            ),
          ],
        ],
      ],
    );
  }
}
