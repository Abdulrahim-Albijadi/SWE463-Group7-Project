import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/queue_data.dart';
import '../../providers/auth_provider.dart';

const providerTeal = Color(0xFF007D73);
const providerMuted = Color(0xFF56535E);
const providerRed = Color(0xFFC62828);
const _background = Color(0xFFF7F9FA);
const _border = Color(0xFFB2DFE1);
const _tint = Color(0xFFE0F2F1);

void providerDashboard(BuildContext context) =>
    Navigator.pushNamedAndRemoveUntil(context, '/provider', (_) => false);

String providerTicket(QueueEntry entry) =>
    '#${entry.ticketNumber.toString().padLeft(2, '0')}';

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
    this.back = false,
    this.busy = false,
  });

  final String title;
  final int selected;
  final bool canManage, back, busy;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().currentUser?.name.trim() ?? '';
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
      child: PopScope(
        canPop: !busy,
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
                    onPressed: busy ? null : () => providerDashboard(context),
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Profile',
                onPressed: busy
                    ? null
                    : () => Navigator.pushNamed(context, '/profile'),
                icon: CircleAvatar(
                  radius: 22,
                  backgroundColor: _tint,
                  child: Text(
                    name.isEmpty ? 'P' : name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: providerTeal,
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
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (index) {
              if (busy || (index == 1 && !canManage)) return;
              if (index == 0) {
                if (ModalRoute.of(context)?.settings.name != '/provider') {
                  providerDashboard(context);
                }
              } else if (selected != 1) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/manage-queue',
                  (_) => false,
                );
              }
            },
            destinations: [
              NavigationDestination(
                enabled: !busy,
                icon: const Icon(Icons.format_list_bulleted),
                label: 'Dashboard',
              ),
              NavigationDestination(
                enabled: canManage && !busy,
                icon: const Icon(Icons.schedule),
                label: 'Manage Queue',
              ),
            ],
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
            CircleAvatar(
              radius: 20,
              backgroundColor: _tint,
              child: Text(
                initials,
                style: const TextStyle(fontSize: 14, color: providerTeal),
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
      Icon(icon, size: 16, color: error ? providerRed : providerTeal),
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
  });
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          color: outlined && !states.contains(WidgetState.disabled)
              ? _border
              : Colors.transparent,
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
              child: Text(label, textAlign: TextAlign.center),
            )
          : FilledButton(
              onPressed: onPressed,
              style: style,
              child: Text(label, textAlign: TextAlign.center),
            ),
    );
  }
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
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: ProviderSurface(
      error: error,
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
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}

class ProviderLoading extends StatelessWidget {
  const ProviderLoading({super.key});

  @override
  Widget build(BuildContext context) => Column(
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
  );
}

class ProviderLoadError extends StatelessWidget {
  const ProviderLoadError({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ProviderNotice(
    title: 'Couldn’t load your queue',
    message:
        'Check your connection and try again. Your queue hasn’t been changed.',
    error: true,
    action: ProviderButton(label: 'Retry', onPressed: onRetry),
  );
}

class ProviderNoQueue extends StatelessWidget {
  const ProviderNoQueue({super.key});

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
          onPressed: () => Navigator.pushNamed(context, '/create-queue'),
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
