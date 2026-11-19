import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/provider_queue_provider.dart';
import '../../providers/provider_support.dart';
import '../../widgets/provider/provider_widgets.dart';

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProviderQueueProvider>();
    final pending = ProviderPendingWrite.current(
      state,
      context.watch<AuthProvider>().currentUser?.id,
    );
    final queue = state.queue;
    final called = state.calledEntry;
    return ProviderPage(
      title: 'Provider Dashboard',
      selected: 0,
      canManage: state.status == LoadStatus.ready && queue != null,
      children: [
        if (state.status == LoadStatus.loading)
          const ProviderLoading()
        else if (state.status == LoadStatus.error)
          ProviderLoadError(onRetry: state.retry)
        else if (queue == null)
          ProviderNoQueue(canCreate: !state.isBusy && pending == null)
        else
          ProviderSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProviderServiceHeader(queue: queue),
                const SizedBox(height: 24),
                Text(
                  '${state.waitingEntries.length} customers waiting',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  providerQueueCount(
                    state.activeEntries.length,
                    called != null,
                  ),
                  style: providerCaption,
                ),
                const SizedBox(height: 4),
                Text(
                  'Average service duration: ${queue.averageServiceMinutes} min',
                  style: providerCaption,
                ),
                const SizedBox(height: 24),
                const ProviderStatus(
                  icon: Icons.campaign_outlined,
                  text: 'Currently called',
                ),
                const SizedBox(height: 4),
                Text(
                  called == null
                      ? 'No customer called'
                      : '${providerTicket(called)} · ${called.customerName}',
                  style: providerCaption,
                ),
                const SizedBox(height: 24),
                ProviderButton(
                  label: 'Manage Queue',
                  onPressed: () => providerManageQueue(context),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
