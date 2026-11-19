import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/queue_rules.dart';
import '../../models/queue_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/provider_queue_provider.dart';
import '../../providers/provider_support.dart';

const providerTeal = Color(0xFF007D73);
const providerMuted = Color(0xFF56535E);
const providerRed = Color(0xFFC62828);
const _background = Color(0xFFF7F9FA);
const _border = Color(0xFFB2DFE1);
const _tint = Color(0xFFE0F2F1);

void providerDashboard(BuildContext context) =>
    Navigator.pushNamedAndRemoveUntil(context, '/provider', (_) => false);

void providerManageQueue(BuildContext context) =>
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/manage-queue',
      ModalRoute.withName('/provider'),
    );

enum ProviderWriteKind { create, call, finish }

// UI confirmation bookkeeping, scoped to the existing state instance/account.
// The shared Provider still owns the actual operation and emits its updates.
// Keep this guard across route disposal: a completed write must not be repeated
// while its queue snapshot is still delayed. No timer or refresh retries writes.
class ProviderPendingWrite {
  ProviderPendingWrite._(this.kind, this.queueId, this.entryId);

  static final _writes = Expando<Map<String, ProviderPendingWrite>>(
    'provider pending writes',
  );

  final ProviderWriteKind kind;
  final String? queueId;
  final String? entryId;
  OperationResult? _result;
  bool _settled = false;

  bool get acknowledged => _result?.isOk == true;

  static ProviderPendingWrite begin(
    ProviderQueueProvider state, {
    required String userId,
    required ProviderWriteKind kind,
    String? queueId,
    String? entryId,
  }) {
    final write = ProviderPendingWrite._(kind, queueId, entryId);
    (_writes[state] ??= {})[userId] = write;
    return write;
  }

  void complete(OperationResult result) => _result = result;

  static ProviderPendingWrite? current(
    ProviderQueueProvider state,
    String? userId,
  ) {
    final write = _writes[state]?[userId];
    if (write == null || write._settled) return null;
    if (write._result == null) return write;
    if (!write.acknowledged) {
      write._settled = true;
      return null;
    }
    // Retry temporarily clears entries. Only a ready snapshot can confirm a
    // write; an empty list during loading must never release the guard.
    if (state.status != LoadStatus.ready) return write;
    final reflected = switch (write.kind) {
      ProviderWriteKind.create => state.queue != null,
      ProviderWriteKind.call =>
        state.queue?.id != write.queueId ||
            !state.waitingEntries.any((entry) => entry.id == write.entryId),
      ProviderWriteKind.finish =>
        state.queue?.id != write.queueId ||
            state.calledEntry?.id != write.entryId,
    };
    if (!reflected) return write;
    write._settled = true;
    return null;
  }
}

String providerTicket(QueueEntry entry) =>
    '#${entry.ticketNumber.toString().padLeft(2, '0')}';

String providerQueueCount(int activeCount, bool hasCalledCustomer) =>
    hasCalledCustomer
    ? '$activeCount in queue, including 1 called customer'
    : '$activeCount in queue, no customer called';

const providerCaption = TextStyle(
  fontSize: 13,
  height: 1.45,
  color: providerMuted,
);

class ProviderPage extends StatelessWidget {
  const ProviderPage({
    super.key,
    required this.title,
    required this.selected,
    required this.canManage,
    required this.children,
    this.slivers = const [],
    this.back = false,
  });

  final String title;
  final int selected;
  final bool canManage, back;
  final List<Widget> children;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().currentUser?.name.trim() ?? '';
    final state = context.watch<ProviderQueueProvider>();
    final pending = ProviderPendingWrite.current(
      state,
      context.watch<AuthProvider>().currentUser?.id,
    );
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: providerTeal,
          onPrimary: Colors.white,
          error: providerRed,
        ),
        textTheme: theme.textTheme.apply(
          bodyColor: const Color(0xFF252329),
          displayColor: const Color(0xFF252329),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: _tint,
          height: 80,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: states.contains(WidgetState.disabled)
                  ? const Color(0xFFADB1B5)
                  : states.contains(WidgetState.selected)
                  ? providerTeal
                  : providerMuted,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.disabled)
                  ? const Color(0xFFADB1B5)
                  : states.contains(WidgetState.selected)
                  ? providerTeal
                  : providerMuted,
            ),
          ),
        ),
      ),
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: PopScope(
          // Management can also be the root route (for example after restoring
          // a direct route). Back always has the same Dashboard destination.
          canPop: !back,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && back) providerDashboard(context);
          },
          child: Scaffold(
            backgroundColor: _background,
            appBar: AppBar(
              title: const Text('QueueLess', style: TextStyle(fontSize: 20)),
              centerTitle: true,
              automaticallyImplyLeading: false,
              backgroundColor: _background,
              surfaceTintColor: Colors.transparent,
              leading: back
                  ? IconButton(
                      tooltip: 'Back to Dashboard',
                      onPressed: () => providerDashboard(context),
                      icon: const Icon(Icons.arrow_back),
                    )
                  : null,
              actions: [
                IconButton(
                  tooltip: 'Profile',
                  onPressed: () => Navigator.pushNamed(context, '/profile'),
                  icon: ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: _tint,
                      child: Text(
                        name.isEmpty
                            ? 'P'
                            : name.characters.first.toUpperCase(),
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: providerTeal,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              top: false,
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                        sliver: SliverList.list(
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (pending != null) ...[
                              ProviderNotice(
                                title: pending.acknowledged
                                    ? 'Waiting for queue updates'
                                    : 'Queue request pending',
                                message: pending.acknowledged
                                    ? 'Your request completed. Waiting for updated queue '
                                          'details before another action. You can leave '
                                          'this screen or refresh queue details.'
                                    : 'Waiting for confirmation. This request may still '
                                          'complete. You can leave this screen; leaving '
                                          'does not cancel it. Check your connection '
                                          'and do not submit it again.',
                                action: ProviderButton(
                                  label: 'Refresh queue details',
                                  outlined: true,
                                  onPressed: state.status == LoadStatus.loading
                                      ? null
                                      : state.retry,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            ...children,
                          ],
                        ),
                      ),
                      for (final sliver in slivers)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: sliver,
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (index) {
                if (index == 1 && !canManage) return;
                if (index == 0) {
                  if (ModalRoute.of(context)?.settings.name != '/provider') {
                    providerDashboard(context);
                  }
                } else if (selected != 1) {
                  providerManageQueue(context);
                }
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.format_list_bulleted),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  enabled: canManage,
                  icon: const Icon(Icons.schedule),
                  label: 'Manage Queue',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProviderSurface extends StatelessWidget {
  const ProviderSurface({super.key, required this.child, this.error = false});
  final Widget child;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFF6F6) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: error ? const Color(0xFFFFCACA) : _border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D007D73),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class ProviderServiceHeader extends StatelessWidget {
  const ProviderServiceHeader({super.key, required this.queue});
  final ServiceQueue queue;

  @override
  Widget build(BuildContext context) {
    final initials = queue.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _tint,
                child: Text(
                  initials,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 14, color: providerTeal),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    queue.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(queue.description, style: providerCaption),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 8,
          children: [
            ProviderStatus(
              icon: queue.isOpen ? Icons.task_alt : Icons.pause_circle_outline,
              text: queue.isOpen ? 'Open' : 'Closed',
            ),
            Text(
              'Avg. ${queue.averageServiceMinutes} min/customer',
              semanticsLabel:
                  'Average service duration: '
                  '${queue.averageServiceMinutes} minutes per customer',
              style: providerCaption,
            ),
          ],
        ),
      ],
    );
  }
}

class ProviderStatus extends StatelessWidget {
  const ProviderStatus({
    super.key,
    required this.icon,
    required this.text,
    this.error = false,
  });
  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: Icon(icon, size: 16, color: error ? providerRed : providerTeal),
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          style: TextStyle(
            color: error ? providerRed : providerTeal,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

class ProviderButton extends StatelessWidget {
  const ProviderButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.semanticsLabel,
  });
  final String label;
  final String? semanticsLabel;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? const Color(0xFFE4E7E8)
            : outlined
            ? Colors.white
            : providerTeal,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? const Color(0xFF62696D)
            : outlined
            ? providerTeal
            : Colors.white,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? outlined
                    ? providerTeal
                    : Colors.white
              : outlined && !states.contains(WidgetState.disabled)
              ? _border
              : Colors.transparent,
          width: states.contains(WidgetState.focused) ? 2 : 1,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(
                label,
                semanticsLabel: semanticsLabel,
                textAlign: TextAlign.center,
              ),
            )
          : FilledButton(
              onPressed: onPressed,
              style: style,
              child: Text(
                label,
                semanticsLabel: semanticsLabel,
                textAlign: TextAlign.center,
              ),
            ),
    );
  }
}

// Announce just the message. Interactive actions remain separate semantic
// nodes, preserving their button roles and keyboard/screen-reader focus.
class ProviderAnnouncement extends StatelessWidget {
  const ProviderAnnouncement({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(child: child),
  );
}

class ProviderActionPair extends StatelessWidget {
  const ProviderActionPair({
    super.key,
    required this.primary,
    required this.secondary,
  });

  final Widget primary, secondary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 8), secondary],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: primary),
          const SizedBox(width: 8),
          Expanded(child: secondary),
        ],
      );
    },
  );
}

class ProviderNotice extends StatelessWidget {
  const ProviderNotice({
    super.key,
    required this.title,
    required this.message,
    this.error = false,
    this.action,
  });
  final String title, message;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ProviderSurface(
    error: error,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProviderAnnouncement(
          message: '$title. $message',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProviderStatus(
                icon: error ? Icons.error_outline : Icons.task_alt,
                text: title,
                error: error,
              ),
              const SizedBox(height: 10),
              Text(message, style: providerCaption),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}

class ProviderLoading extends StatelessWidget {
  const ProviderLoading({super.key});

  @override
  Widget build(BuildContext context) => ProviderAnnouncement(
    message:
        'Loading your queue. Please wait while we retrieve your queue details.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProviderSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Loading your queue...', style: providerCaption),
              SizedBox(height: 8),
              Text(
                'Please wait while we retrieve your queue details.',
                style: providerCaption,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: CircularProgressIndicator(
            color: providerTeal,
            backgroundColor: _tint,
            semanticsLabel: 'Loading your queue',
          ),
        ),
      ],
    ),
  );
}

class ProviderLoadError extends StatelessWidget {
  const ProviderLoadError({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ProviderNotice(
    title: 'Couldn’t load your queue',
    message:
        'Check your connection and try again. Refreshing queue details does not '
        'repeat queue actions.',
    error: true,
    action: ProviderButton(
      label: 'Retry',
      semanticsLabel: 'Retry loading your queue',
      onPressed: onRetry,
    ),
  );
}

class ProviderNoQueue extends StatelessWidget {
  const ProviderNoQueue({super.key, this.canCreate = true});
  final bool canCreate;

  @override
  Widget build(BuildContext context) => ProviderSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProviderStatus(icon: Icons.list, text: 'No queue yet'),
        const SizedBox(height: 14),
        const Text(
          'Welcome to QueueLess',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          'Create your service queue so customers can join and track their turn.',
          style: providerCaption,
        ),
        const SizedBox(height: 12),
        ProviderButton(
          label: 'Create Queue',
          onPressed: canCreate
              ? () => Navigator.pushNamed(context, '/create-queue')
              : null,
        ),
        const SizedBox(height: 10),
        const Text(
          'You can create one queue per provider.',
          style: providerCaption,
        ),
      ],
    ),
  );
}

// Shares the page's scroll viewport so only nearby customer rows are built.
// Rows can grow freely for long names and larger text settings.
class ProviderWaitingSliver extends StatelessWidget {
  const ProviderWaitingSliver({super.key, required this.entries});

  final List<QueueEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Build the lookup only when Flutter needs to reconcile a live reorder.
    late final indices = {
      for (var index = 0; index < entries.length; index++)
        entries[index].id: index,
    };
    return SliverList.builder(
      itemCount: entries.length,
      addAutomaticKeepAlives: false,
      findChildIndexCallback: (key) => indices[(key as ValueKey<String>).value],
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          key: ValueKey(entry.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: ProviderSurface(
            child: MergeSemantics(child: ProviderWaitingCustomer(entry: entry)),
          ),
        );
      },
    );
  }
}

class ProviderWaitingCustomer extends StatelessWidget {
  const ProviderWaitingCustomer({super.key, required this.entry});
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
          semanticsLabel: 'Ticket ${entry.ticketNumber}',
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
                  const ExcludeSemantics(
                    child: Icon(Icons.schedule, size: 12, color: providerMuted),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Waiting · Joined $time',
                      semanticsLabel: 'Waiting. Joined at $time.',
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
