import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/queue_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/membership_provider.dart';
import '../../providers/provider_support.dart';
import '../../providers/queue_provider.dart';
import '../../widgets/customer/customer_widgets.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final queues = context.watch<QueueProvider>();
    final membership = context.watch<MembershipProvider>();

    final firstName = user?.name.trim().split(' ').first;
    final isLoading =
        queues.status == LoadStatus.loading ||
        membership.status == LoadStatus.loading;
    final hasError =
        queues.status == LoadStatus.error ||
        membership.status == LoadStatus.error;

    return CustomerPage(
      title: 'QueueLess',
      selected: 0,
      profileName: user?.name ?? 'Customer',
      children: [
        Text(
          'Hello, ${firstName ?? 'Customer'} 👋',
          style: const TextStyle(
            fontSize: 28,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: Color(0xFF134E4A),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Find your service. Skip the wait.',
          style: TextStyle(fontSize: 14, color: customerMuted),
        ),
        const SizedBox(height: 32),
        const SectionTitle('Available Queues'),
        const SizedBox(height: 20),
        if (isLoading)
          const Surface(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading queues...'),
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
                      'Could not load queues. Please retry.',
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
        else if (queues.summaries.isEmpty)
          const Surface(
            child: Text(
              'No queues available right now.\nPlease check again later.',
            ),
          )
        else
          for (final summary in queues.summaries) ...[
            _queueCard(context, summary, queues, membership),
            const SizedBox(height: 20),
          ],
      ],
    );
  }

  Widget _queueCard(
    BuildContext context,
    QueueSummary summary,
    QueueProvider queues,
    MembershipProvider membership,
  ) {
    final queue = summary.queue;
    final ticket = membership.currentEntry;
    final hasTicketHere =
        membership.hasActiveMembership && ticket?.queueId == queue.id;
    final called = hasTicketHere && membership.isCalled;
    final near = hasTicketHere && membership.isNearTurn;
    final wait = membership.estimatedWaitMinutes;

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServiceHeader(queue: queue, showOpen: true),
          const SizedBox(height: 28),
          if (!called) ...[
            Stats(
              value1: hasTicketHere
                  ? membership.customersAhead?.toString() ?? '...'
                  : '${summary.waitingCount}',
              label1: hasTicketHere ? 'Customers ahead' : 'Customers waiting',
              value2: hasTicketHere
                  ? (wait == null ? '...' : '$wait min')
                  : '${queue.averageServiceMinutes} min',
              label2: hasTicketHere ? 'Estimated wait' : 'Avg. service time',
            ),
            const SizedBox(height: 28),
          ],
          if (called)
            Notice(
              title: 'It’s your turn!',
              message: 'Please proceed to ${queue.name}.',
              titleSize: 20,
            )
          else
            Text(
              !hasTicketHere
                  ? 'Join the queue and track your turn.'
                  : near
                  ? 'Your turn is near. Ticket #${ticket!.ticketNumber}'
                  : 'You’re in this queue. Ticket #${ticket!.ticketNumber}',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: near ? customerAmber : const Color(0xFF475569),
                fontWeight: near ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: hasTicketHere ? 'View My Ticket' : 'View Queue',
            onPressed: () {
              if (!hasTicketHere) {
                queues.select(queue.id);
              }
              Navigator.pushNamed(
                context,
                hasTicketHere ? '/my-queue' : '/queue-details',
              );
            },
          ),
        ],
      ),
    );
  }
}
