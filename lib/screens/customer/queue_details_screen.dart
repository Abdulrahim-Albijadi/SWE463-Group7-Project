import 'package:flutter/material.dart';

import '../../models/queue_data.dart';
import '../../widgets/customer/customer_widgets.dart';

class QueueDetailsScreen extends StatelessWidget {
  const QueueDetailsScreen({super.key, required this.state});
  final QueueDemoState state;

  void _join(BuildContext context) {
    if (state.joinQueue()) {
      Navigator.pushReplacementNamed(context, '/my-queue');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not join the queue. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final queue = state.queue;
      final hasTicket = state.myActiveEntry != null;
      final ahead = hasTicket
          ? state.customersAhead ?? 0
          : state.activeEntries.length;
      return CustomerPage(
        title: 'Queue Details',
        selected: 0,
        back: true,
        children: [
          const SectionTitle('Queue Information'),
          const SizedBox(height: 24),
          if (queue == null)
            const Surface(child: Text('This queue is unavailable.'))
          else ...[
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ServiceHeader(queue: queue, showOpen: true),
                  const SizedBox(height: 28),
                  Stats(
                    value1: '$ahead',
                    label1: 'Customers ahead',
                    value2: '${ahead * queue.averageServiceMinutes} min',
                    label2: 'Estimated wait',
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Average service time: ${queue.averageServiceMinutes} min per customer',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: hasTicket ? 'Cannot Join' : 'Join Queue',
                    onPressed: hasTicket || !queue.isOpen
                        ? null
                        : () => _join(context),
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
    },
  );
}
