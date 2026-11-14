import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/queue_rules.dart';
import '../../providers/auth_provider.dart';
import '../../providers/provider_queue_provider.dart';
import '../../providers/provider_support.dart';
import '../../widgets/provider/provider_widgets.dart';

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
