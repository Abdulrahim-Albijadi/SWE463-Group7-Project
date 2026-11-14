import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/queue_rules.dart';
import '../../models/queue_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/provider_queue_provider.dart';
import '../../providers/provider_support.dart';
import '../../widgets/provider/provider_widgets.dart';

enum _QueueAction { call, serve, skip }

class QueueManagementScreen extends StatefulWidget {
  const QueueManagementScreen({super.key});

  @override
  State<QueueManagementScreen> createState() => _QueueManagementScreenState();
}

class _QueueManagementScreenState extends State<QueueManagementScreen> {
  _QueueAction? _running;
  _QueueAction? _lastAction;
  QueueEntry? _target;
  String? _queueId;
  OperationResult? _result;

  // A write can finish before its snapshot arrives. Disable actions until
  // the existing shared stream reflects that particular write.
  bool _awaitingSnapshot(ProviderQueueProvider state) {
    if (_result?.isOk != true || _queueId != state.queue?.id) return false;
    return _lastAction == _QueueAction.call
        ? state.waitingEntries.any((entry) => entry.id == _target?.id)
        : state.calledEntry?.id == _target?.id;
  }

  Future<void> _run(_QueueAction action, {bool retry = false}) async {
    final state = context.read<ProviderQueueProvider>();
    if (_running != null ||
        state.isBusy ||
        _awaitingSnapshot(state) ||
        state.status != LoadStatus.ready ||
        state.queue == null) {
      return;
    }
    final isCall = action == _QueueAction.call;
    if (isCall ? !state.canCallNext : !state.canFinishCalled) return;
    final target = isCall ? state.waitingEntries.first : state.calledEntry!;
    // Retry must not accidentally operate on a different customer's ticket.
    if (retry && (_target?.id != target.id || _queueId != state.queue!.id)) {
      setState(() => _result = null);
      return;
    }
    final userId = context.read<AuthProvider>().currentUser?.id;
    setState(() {
      _running = action;
      _lastAction = action;
      _target = target;
      _queueId = state.queue!.id;
      _result = null;
    });
    final result = await switch (action) {
      _QueueAction.call => state.callNext(),
      _QueueAction.serve => state.markServed(),
      _QueueAction.skip => state.skipCalled(),
    };
    if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
      return;
    }
    setState(() {
      _running = null;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProviderQueueProvider>();
    final queue = state.queue;
    final called = state.calledEntry;
    final waiting = state.waitingEntries;
    final busy = _running != null || state.isBusy || _awaitingSnapshot(state);
    final showResult = _result != null && _queueId == queue?.id;
    final failed = showResult && !_result!.isOk;
    final targetStillCurrent = _lastAction == _QueueAction.call
        ? state.canCallNext && waiting.firstOrNull?.id == _target?.id
        : state.canFinishCalled && called?.id == _target?.id;
    final retryAvailable = failed && targetStillCurrent;
    return ProviderPage(
      title: 'Queue Management',
      selected: 1,
      canManage: state.status == LoadStatus.ready && queue != null,
      back: true,
      busy: busy,
      children: [
        if (state.status == LoadStatus.loading)
          const ProviderLoading()
        else if (state.status == LoadStatus.error)
          ProviderLoadError(onRetry: state.retry)
        else if (queue == null)
          const ProviderNoQueue()
        else ...[
          ProviderSurface(child: ProviderServiceHeader(queue: queue)),
          const SizedBox(height: 8),
          if (showResult && !failed) ...[
            Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProviderStatus(
                    icon: _lastAction == _QueueAction.skip
                        ? Icons.skip_next_outlined
                        : Icons.task_alt,
                    text:
                        '${providerTicket(_target!)} ${_target!.customerName} — '
                        '${switch (_lastAction) {
                          _QueueAction.call => 'Called',
                          _QueueAction.serve => 'Served',
                          _QueueAction.skip => 'Skipped',
                          null => '',
                        }}',
                  ),
                  if (_lastAction != _QueueAction.call)
                    Text(
                      _lastAction == _QueueAction.serve
                          ? 'Service completed. Call the next customer.'
                          : 'Removed from queue. No customer auto-called.',
                      style: providerCaption,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          ProviderSurface(
            error: failed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      called == null
                          ? 'No customer called'
                          : '${providerTicket(called)} · ${called.customerName}',
                    ),
                    if (called != null)
                      const ProviderStatus(
                        icon: Icons.campaign_outlined,
                        text: 'Called',
                      ),
                  ],
                ),
                if (failed) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: ProviderStatus(
                      icon: Icons.error_outline,
                      error: true,
                      text: _failureMessage(called),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: ProviderButton(
                        label: _running == _QueueAction.serve
                            ? 'Saving…'
                            : retryAvailable &&
                                  _lastAction == _QueueAction.serve
                            ? 'Retry update'
                            : 'Mark as Served',
                        onPressed: busy || !state.canFinishCalled
                            ? null
                            : () => _run(
                                _QueueAction.serve,
                                retry:
                                    retryAvailable &&
                                    _lastAction == _QueueAction.serve,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ProviderButton(
                        label: _running == _QueueAction.skip
                            ? 'Skipping…'
                            : retryAvailable && _lastAction == _QueueAction.skip
                            ? 'Retry skip'
                            : 'Skip',
                        outlined: true,
                        onPressed: busy || !state.canFinishCalled
                            ? null
                            : () => _run(
                                _QueueAction.skip,
                                retry:
                                    retryAvailable &&
                                    _lastAction == _QueueAction.skip,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting customers (${waiting.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (called != null) ...[
            const SizedBox(height: 4),
            Text(
              providerQueueCount(
                state.activeEntries.length,
                state.calledEntry != null,
              ),
              style: providerCaption,
            ),
          ],
          const SizedBox(height: 6),
          if (waiting.isEmpty)
            const ProviderNotice(
              title: 'All caught up',
              message: 'No customers are waiting. New customers will appear here when they join.',
            )
          else
            ProviderSurface(
              child: Column(
                children: [
                  for (var index = 0; index < waiting.length; index++) ...[
                    if (index > 0)
                      const Divider(height: 16, color: Color(0xFFE0F2F1)),
                    ProviderWaitingCustomer(entry: waiting[index]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 10),
          ProviderButton(
            label: _running == _QueueAction.call
                ? 'Calling…'
                : retryAvailable && _lastAction == _QueueAction.call
                ? 'Retry Call Next'
                : 'Call Next',
            onPressed: busy || !state.canCallNext
                ? null
                : () => _run(
                    _QueueAction.call,
                    retry: retryAvailable && _lastAction == _QueueAction.call,
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 4,
            child: busy
                ? const LinearProgressIndicator(
                    color: providerTeal,
                    backgroundColor: Color(0xFFE0F2F1),
                    semanticsLabel: 'Updating queue',
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            busy
                ? 'Updating your queue…'
                : called != null
                ? 'Complete or skip the current customer first.'
                : waiting.isEmpty
                ? 'Call Next becomes available when a customer joins.'
                : 'Call Next calls the first waiting customer. Tickets stay fixed; order follows join time.',
            style: providerCaption,
          ),
        ],
      ],
    );
  }

  String _failureMessage(QueueEntry? called) {
    final verb = switch (_lastAction) {
      _QueueAction.call => 'call ${providerTicket(_target!)}',
      _QueueAction.serve => 'mark ${providerTicket(_target!)} as served',
      _QueueAction.skip => 'skip ${providerTicket(_target!)}',
      null => 'update the queue',
    };
    final detail = _result!.error == OperationError.failed
        ? 'Check your connection and retry.'
        : _result!.message ?? 'Please retry.';
    return 'Couldn’t $verb. '
        '${called?.id == _target?.id ? '${called!.customerName} is still called. ' : ''}'
        '$detail';
  }
}
