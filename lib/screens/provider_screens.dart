import 'package:flutter/material.dart';
import '../models/queue_data.dart';

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key, required this.state});
  final QueueDemoState state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('QueueLess'), actions: [
        IconButton(tooltip: 'Profile', icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => Navigator.pushNamed(context, '/profile')),
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Provider Dashboard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (state.queue == null)
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('No queue yet', style: Theme.of(context).textTheme.titleLarge),
              const Text('Create your service queue so customers can join.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pushNamed(context, '/create-queue'),
                child: const Text('Create Queue')),
            ],
          ))),
        if (state.queue != null)
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.queue!.name, style: Theme.of(context).textTheme.titleLarge),
              Text(state.queue!.description),
              const SizedBox(height: 8),
              const Chip(label: Text('Open')),
              Text('${state.waitingEntries.length} customers waiting'),
              Text('${state.activeEntries.length} in queue, including ${state.calledEntry == null ? 0 : 1} called'),
              Text('Average duration: ${state.queue!.averageServiceMinutes} min'),
              const SizedBox(height: 14),
              Text('Currently called', style: Theme.of(context).textTheme.titleSmall),
              Text(state.calledEntry == null ? 'Nobody called' :
                '#${state.calledEntry!.ticketNumber.toString().padLeft(2, '0')} · ${state.calledEntry!.customerName}'),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/manage-queue'),
                child: const Text('Manage Queue'),
              )),
            ],
          ))),
        if (state.queue != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => Navigator.pushNamed(context, '/create-queue'),
            child: const Text('View Create Queue screen (demo only)')),
        ],
      ]),
      bottomNavigationBar: const _ProviderNavigation(selected: 0),
    ),
  );
}

class CreateQueueScreen extends StatefulWidget {
  const CreateQueueScreen({super.key, required this.state});
  final QueueDemoState state;

  @override
  State<CreateQueueScreen> createState() => _CreateQueueScreenState();
}

class _CreateQueueScreenState extends State<CreateQueueScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _minutes = TextEditingController(text: '5');

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _create() {
    if (!_form.currentState!.validate()) return;
    final ok = widget.state.createQueue(
      name: _name.text,
      description: _description.text,
      minutes: int.parse(_minutes.text),
    );
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Only one queue per provider. This is a preview screen.'),
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Queue created')));
    Navigator.pushNamedAndRemoveUntil(context, '/provider', (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create Queue')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Set up your service', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Each provider can create one queue.'),
      const SizedBox(height: 16),
      TextFormField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Queue name', hintText: 'Campus Barber',
          border: OutlineInputBorder()),
        validator: (v) => v == null || v.trim().isEmpty ? 'Queue name is required' : null,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _description,
        decoration: const InputDecoration(labelText: 'Description', hintText: 'Barber service',
          border: OutlineInputBorder()),
        validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _minutes,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Average duration (minutes)',
          border: OutlineInputBorder()),
        validator: (v) {
          final number = int.tryParse(v?.trim() ?? '');
          if (number == null || number <= 0) return 'Enter a whole number greater than 0';
          return null;
        },
      ),
      const SizedBox(height: 20),
      FilledButton(onPressed: _create, child: const Text('Create Queue')),
      OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      const SizedBox(height: 10),
      const Text('Phase 2 starter: sample data only. No Firebase operation is performed.'),
    ])),
    bottomNavigationBar: const _ProviderNavigation(selected: 0),
  );
}

class QueueManagementScreen extends StatelessWidget {
  const QueueManagementScreen({super.key, required this.state});
  final QueueDemoState state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Queue Management')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(child: ListTile(
          leading: const Icon(Icons.content_cut),
          title: Text(state.queue?.name ?? 'No service queue'),
          subtitle: Text('Average: ${state.queue?.averageServiceMinutes ?? 0} min/customer'),
        )),
        const SizedBox(height: 12),
        Text('Currently called', style: Theme.of(context).textTheme.titleMedium),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(state.calledEntry == null ? 'No customer called' :
              '#${state.calledEntry!.ticketNumber.toString().padLeft(2, '0')} · ${state.calledEntry!.customerName}'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FilledButton(
                onPressed: state.calledEntry == null ? null : () { state.markServed(); },
                child: const Text('Mark as Served'),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(
                onPressed: state.calledEntry == null ? null : () { state.skipCalled(); },
                child: const Text('Skip'),
              )),
            ]),
          ],
        ))),
        const SizedBox(height: 14),
        Text('Waiting customers (${state.waitingEntries.length})',
          style: Theme.of(context).textTheme.titleMedium),
        if (state.waitingEntries.isEmpty)
          const Card(child: ListTile(title: Text('All caught up'),
            subtitle: Text('No customers are currently waiting.'))),
        for (final entry in state.waitingEntries)
          Card(child: ListTile(
            leading: CircleAvatar(child: Text('#${entry.ticketNumber}')),
            title: Text(entry.customerName),
            subtitle: const Text('Waiting'),
            trailing: const Icon(Icons.hourglass_bottom),
          )),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: state.calledEntry != null || state.waitingEntries.isEmpty
              ? null : () { state.callNext(); },
          child: const Text('Call Next'),
        ),
        if (state.calledEntry != null)
          const Text('Complete or skip the current customer first.',
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Demo only: positions change, ticket numbers stay fixed.'),
      ]),
      bottomNavigationBar: const _ProviderNavigation(selected: 1),
    ),
  );
}

class _ProviderNavigation extends StatelessWidget {
  const _ProviderNavigation({required this.selected});
  final int selected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selected,
    onDestinationSelected: (index) {
      if (index == selected) return;
      Navigator.pushNamedAndRemoveUntil(context,
        index == 0 ? '/provider' : '/manage-queue', (_) => false);
    },
    destinations: const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
      NavigationDestination(icon: Icon(Icons.format_list_numbered), label: 'Manage Queue'),
    ],
  );
}
