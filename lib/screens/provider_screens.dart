import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/queue_rules.dart';
import '../models/queue_data.dart';
import '../providers/auth_provider.dart';
import '../providers/provider_queue_provider.dart';
import '../providers/provider_support.dart';
import '../widgets/provider/provider_widgets.dart';

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProviderQueueProvider>();
    final queue = state.queue;
    final called = state.calledEntry;
    return ProviderPage(
      title: 'Provider Dashboard',
      selected: 0,
      canManage: state.status == LoadStatus.ready && queue != null,
      busy: state.isBusy,
      children: [
        if (state.status == LoadStatus.loading)
          const ProviderLoading()
        else if (state.status == LoadStatus.error)
          ProviderLoadError(onRetry: state.retry)
        else if (queue == null)
          const ProviderNoQueue()
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
                Text(_queueCount(state), style: providerCaption),
                const SizedBox(height: 4),
                Text(
                  'Average service duration: ${queue.averageServiceMinutes} min',
                  style: providerCaption,
                ),
                const SizedBox(height: 22),
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
                const SizedBox(height: 22),
                ProviderButton(
                  label: 'Manage Queue',
                  onPressed: state.isBusy
                      ? null
                      : () => Navigator.pushNamed(context, '/manage-queue'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _queueCount(ProviderQueueProvider state) => state.calledEntry == null
    ? '${state.activeEntries.length} in queue, no customer called'
    : '${state.activeEntries.length} in queue, including 1 called customer';

class CreateQueueScreen extends StatefulWidget {
  const CreateQueueScreen({super.key});

  @override
  State<CreateQueueScreen> createState() => _CreateQueueScreenState();
}

class _CreateQueueScreenState extends State<CreateQueueScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _minutes = TextEditingController(text: '5');
  bool _submitted = false;
  bool _creating = false;
  bool _created = false;
  OperationResult? _failure;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final state = context.read<ProviderQueueProvider>();
    if (_creating ||
        _created ||
        state.isBusy ||
        state.status != LoadStatus.ready ||
        state.queue != null) {
      return;
    }
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final userId = context.read<AuthProvider>().currentUser?.id;
    setState(() {
      _creating = true;
      _failure = null;
    });
    final result = await state.createQueue(
      name: _name.text.trim(),
      description: _description.text.trim(),
      averageServiceMinutes: int.parse(_minutes.text.trim()),
    );
    if (!mounted || context.read<AuthProvider>().currentUser?.id != userId) {
      return;
    }
    setState(() {
      _creating = false;
      _created = result.isOk;
      _failure = result.isOk ? null : result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProviderQueueProvider>();
    final busy = _creating || state.isBusy;
    final queue = state.queue;
    return ProviderPage(
      title: 'Create Queue',
      selected: 0,
      canManage: state.status == LoadStatus.ready && queue != null,
      back: true,
      busy: busy,
      children: [
        if (_creating)
          _buildForm(busy: true)
        else if (state.status == LoadStatus.loading)
          const ProviderLoading()
        else if (state.status == LoadStatus.error)
          ProviderLoadError(onRetry: state.retry)
        else if (_created || queue != null)
          ProviderSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProviderStatus(
                  icon: Icons.task_alt,
                  text: _created ? 'Queue created' : 'You already have a queue',
                ),
                const SizedBox(height: 20),
                if (queue != null) ...[
                  ProviderServiceHeader(queue: queue),
                  const SizedBox(height: 20),
                  Text(
                    '${state.waitingEntries.length} customers waiting',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _created
                        ? 'Your queue is ready. Customers can now join ${queue.name}.'
                        : 'Each provider can create one queue. Manage your existing queue below.',
                    style: providerCaption,
                  ),
                ] else ...[
                  const Text(
                    'Your queue was saved. Waiting for the latest queue details…',
                    style: providerCaption,
                  ),
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
                const SizedBox(height: 20),
                ProviderButton(
                  label: 'Manage Queue',
                  onPressed: queue == null || busy
                      ? null
                      : () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/manage-queue',
                          (_) => false,
                        ),
                ),
                const SizedBox(height: 12),
                ProviderButton(
                  label: 'Back to Dashboard',
                  outlined: true,
                  onPressed: busy ? null : () => providerDashboard(context),
                ),
              ],
            ),
          )
        else
          _buildForm(busy: busy),
      ],
    );
  }

  Widget _buildForm({required bool busy}) => Form(
    key: _form,
    autovalidateMode: _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Set up your service details. Each provider can create one queue.',
          style: providerCaption,
        ),
        const SizedBox(height: 16),
        _field(
          label: 'Queue name',
          fieldKey: 'queue-name',
          controller: _name,
          hint: 'Enter queue name',
          enabled: !busy,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Queue name is required.'
              : null,
        ),
        const SizedBox(height: 16),
        _field(
          label: 'Description',
          fieldKey: 'queue-description',
          controller: _description,
          hint: 'Describe your service',
          enabled: !busy,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Description is required.'
              : null,
        ),
        const SizedBox(height: 16),
        _field(
          label: 'Average service duration',
          fieldKey: 'queue-minutes',
          controller: _minutes,
          hint: 'Enter duration',
          enabled: !busy,
          numeric: true,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return 'Service duration is required.';
            final minutes = int.tryParse(text);
            if (!RegExp(r'^\d+$').hasMatch(text) ||
                minutes == null ||
                minutes <= 0) {
              return 'Enter a whole number greater than 0.';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter a positive whole number of minutes.',
          style: TextStyle(fontSize: 12, color: providerMuted),
        ),
        const SizedBox(height: 12),
        if (busy) ...[
          const Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  semanticsLabel: 'Creating queue',
                ),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Creating queue…', style: providerCaption)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_failure != null) ...[
          ProviderNotice(
            title: 'Creation failed',
            error: true,
            message: _failure!.error == OperationError.failed
                ? 'Couldn’t create your queue. Please try again.'
                : _failure!.message ?? 'Please try again.',
          ),
          const SizedBox(height: 12),
        ],
        ProviderButton(
          label: busy
              ? 'Creating queue…'
              : _failure != null
              ? 'Retry creation'
              : 'Create Queue',
          onPressed: busy ? null : _create,
        ),
        const SizedBox(height: 10),
        ProviderButton(
          label: 'Cancel',
          outlined: true,
          onPressed: busy ? null : () => providerDashboard(context),
        ),
      ],
    ),
  );

  Widget _field({
    required String label,
    required String fieldKey,
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    required FormFieldValidator<String> validator,
    bool numeric = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontSize: 14)),
      const SizedBox(height: 6),
      Semantics(
        label: label,
        child: TextFormField(
          key: ValueKey(fieldKey),
          controller: controller,
          enabled: enabled,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          textCapitalization: numeric
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          textInputAction: numeric
              ? TextInputAction.done
              : TextInputAction.next,
          onFieldSubmitted: numeric ? (_) => _create() : null,
          scrollPadding: const EdgeInsets.all(24),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: numeric ? 'minutes' : null,
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFE4E7E8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF9DA3A8)),
            ),
            errorMaxLines: 3,
          ),
          validator: validator,
        ),
      ),
    ],
  );
}

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
            Text(_queueCount(state), style: providerCaption),
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
                    _WaitingCustomer(entry: waiting[index]),
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

class _WaitingCustomer extends StatelessWidget {
  const _WaitingCustomer({required this.entry});
  final QueueEntry entry;

  @override
  Widget build(BuildContext context) {
    final joined = entry.joinedAt.toLocal();
    final time =
        '${joined.hour.toString().padLeft(2, '0')}:'
        '${joined.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Text(
          providerTicket(entry),
          style: const TextStyle(
            color: providerTeal,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.customerName),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 12, color: providerMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Waiting · Joined $time',
                      style: providerCaption,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
