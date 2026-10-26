import 'package:flutter/material.dart';

import '../../models/queue_data.dart';
import '../../widgets/customer/customer_widgets.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({
    super.key,
    required this.state,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });
  final QueueDemoState state;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final queue = state.queue;
      final ticket = state.myActiveEntry;
      final called = ticket?.status == MembershipStatus.called;
      final near =
          ticket?.status == MembershipStatus.waiting &&
          state.customersAhead == 2;
      final firstName = state.currentUser?.name.trim().split(' ').first;
      return CustomerPage(
        title: 'QueueLess',
        selected: 0,
        profileName: state.currentUser?.name ?? 'Customer',
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
          else if (errorMessage != null)
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 32),
                  const SizedBox(height: 12),
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  PrimaryButton(label: 'Retry', onPressed: onRetry),
                ],
              ),
            )
          else if (queue == null)
            const Surface(
              child: Text(
                'No queues available right now.\nPlease check again later.',
              ),
            )
          else
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ServiceHeader(queue: queue, showOpen: true),
                  const SizedBox(height: 28),
                  if (!called) ...[
                    Stats(
                      value1: ticket == null
                          ? '${state.waitingEntries.length}'
                          : '${state.customersAhead ?? 0}',
                      label1: ticket == null
                          ? 'Customers waiting'
                          : 'Customers ahead',
                      value2:
                          '${ticket == null ? queue.averageServiceMinutes : state.estimatedWaitMinutes ?? 0} min',
                      label2: ticket == null
                          ? 'Avg. service time'
                          : 'Estimated wait',
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
                      ticket == null
                          ? 'Join the queue and track your turn.'
                          : near
                          ? 'Your turn is near. Ticket #${ticket.ticketNumber}'
                          : 'You’re in this queue. Ticket #${ticket.ticketNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: near ? customerAmber : const Color(0xFF475569),
                        fontWeight: near ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: ticket == null ? 'View Queue' : 'View My Ticket',
                    onPressed: () => Navigator.pushNamed(
                      context,
                      ticket == null ? '/queue-details' : '/my-queue',
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
