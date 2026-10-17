import 'package:flutter/material.dart';

import '../models/queue_data.dart';

const _teal = Color(0xFF00796B);
const _ink = Color(0xFF1D1B20);
const _muted = Color(0xFF64748B);
const _red = Color(0xFFB3261E);
const _amber = Color(0xFFB26A00);
const _background = Color(0xFFF7F9FA);

void _home(BuildContext context) =>
    Navigator.pushNamedAndRemoveUntil(context, '/customer', (_) => false);

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key, required this.state});
  final QueueDemoState state;

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
      return _CustomerPage(
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
            style: TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 32),
          const _SectionTitle('Available Queues'),
          const SizedBox(height: 20),
          if (queue == null)
            const _Surface(
              child: Text(
                'No queues available right now.\nPlease check again later.',
              ),
            )
          else
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ServiceHeader(queue: queue, showOpen: true),
                  const SizedBox(height: 28),
                  if (!called) ...[
                    _Stats(
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
                    _Notice(
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
                        color: near ? _amber : const Color(0xFF475569),
                        fontWeight: near ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  const SizedBox(height: 28),
                  _PrimaryButton(
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
      return _CustomerPage(
        title: 'Queue Details',
        selected: 0,
        back: true,
        children: [
          const _SectionTitle('Queue Information'),
          const SizedBox(height: 24),
          if (queue == null)
            const _Surface(child: Text('This queue is unavailable.'))
          else ...[
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ServiceHeader(queue: queue, showOpen: true),
                  const SizedBox(height: 28),
                  _Stats(
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
                  _PrimaryButton(
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
              const _Notice(
                title: 'You already have an active ticket',
                message: 'Open My Queue to view your current ticket.',
                color: _amber,
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

class MyQueueScreen extends StatelessWidget {
  const MyQueueScreen({super.key, required this.state});
  final QueueDemoState state;

  Future<void> _leave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Leave queue?'),
        content: const Text(
          'You’ll lose your place. Rejoining will put you at the end of the queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: _teal)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave Queue', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (!state.leaveQueue()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only waiting tickets can leave.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      QueueEntry? latest;
      for (final entry in state.entries.reversed) {
        if (entry.customerId == state.currentUser?.id) {
          latest = entry;
          break;
        }
      }
      final ticket = state.myActiveEntry ?? latest;
      final status = ticket?.status;
      final waiting = status == MembershipStatus.waiting;
      final near = waiting && state.customersAhead == 2;
      final skipped = status == MembershipStatus.skipped;
      final left = status == MembershipStatus.left;
      final terminal = status == MembershipStatus.served || skipped || left;
      final accent = skipped
          ? _red
          : left
          ? const Color(0xFF5F6368)
          : _teal;
      final border = skipped
          ? const Color(0xFFF2C6C2)
          : left
          ? const Color(0xFFCBD5E1)
          : const Color(0xFFB2DFDB);
      final fill = skipped
          ? const Color(0xFFFFF5F5)
          : left
          ? const Color(0xFFF8FAFC)
          : const Color(0xFFF0FDFA);
      final name = state.queue?.name ?? 'Service queue';
      final title = switch (status) {
        MembershipStatus.called => 'It’s your turn!',
        MembershipStatus.served => 'Your service is complete.',
        MembershipStatus.skipped => 'You missed your turn.',
        MembershipStatus.left => 'You left the queue.',
        _ => '',
      };
      final message = switch (status) {
        MembershipStatus.called => 'Please proceed to $name now.',
        MembershipStatus.served => 'Thank you for using QueueLess.',
        MembershipStatus.skipped => 'Rejoin the queue to get a new ticket.',
        MembershipStatus.left => 'Your ticket is no longer active.',
        _ =>
          near
              ? 'Your turn is near. Please be ready.'
              : 'We’ll notify you when your turn is near.',
      };
      final statusLabel = switch (status) {
        MembershipStatus.waiting => 'Waiting',
        MembershipStatus.called => 'Called',
        MembershipStatus.served => 'Served',
        MembershipStatus.skipped => 'Skipped',
        MembershipStatus.left => 'Left',
        null => '',
      };
      return _CustomerPage(
        title: 'My Queue',
        selected: 1,
        back: true,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  ticket == null ? 'No Active Queue' : 'Your Ticket',
                ),
              ),
              if (ticket != null) ...[
                Icon(
                  status == MembershipStatus.served
                      ? Icons.check
                      : skipped
                      ? Icons.priority_high
                      : Icons.circle,
                  size: status == MembershipStatus.served || skipped ? 16 : 7,
                  color: waiting ? _amber : accent,
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: waiting ? _amber : accent,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          if (ticket == null)
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'You haven’t joined a queue yet.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text('Browse available queues to get started.'),
                  const SizedBox(height: 24),
                  _PrimaryButton(
                    label: 'Browse Queues',
                    onPressed: () => _home(context),
                  ),
                ],
              ),
            )
          else
            _Surface(
              color: fill,
              border: border,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: state.queue == null
                        ? Text(name)
                        : _ServiceHeader(queue: state.queue!),
                  ),
                  const SizedBox(height: 16),
                  _DashedDivider(color: border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'YOUR TICKET NUMBER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '#${ticket.ticketNumber}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 64,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (waiting) ...[
                          _Stats(
                            value1: '${state.customersAhead ?? 0}',
                            label1: 'Customers ahead',
                            value2: '${state.estimatedWaitMinutes ?? 0} min',
                            label2: 'Estimated wait',
                            color: Colors.white,
                          ),
                          const SizedBox(height: 28),
                        ],
                        _Notice(
                          title: title.isEmpty ? null : title,
                          message: message,
                          titleSize: 20,
                          color: near
                              ? _amber
                              : left
                              ? const Color(0xFF475569)
                              : accent,
                          background: near
                              ? const Color(0xFFFFF3E0)
                              : skipped
                              ? const Color(0xFFFDE8E7)
                              : left
                              ? const Color(0xFFEEF2F6)
                              : const Color(0xFFE0F2F1),
                        ),
                        if (waiting || terminal) const SizedBox(height: 28),
                        if (waiting)
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _red,
                                side: const BorderSide(color: _red),
                                minimumSize: const Size(110, 48),
                              ),
                              onPressed: () => _leave(context),
                              child: const Text('Leave Queue'),
                            ),
                          ),
                        if (terminal)
                          _PrimaryButton(
                            label: 'Browse Queues',
                            onPressed: () => _home(context),
                          ),
                      ],
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

// Shared presentation widgets. Queue rules remain in QueueDemoState.
class _CustomerPage extends StatelessWidget {
  const _CustomerPage({
    required this.title,
    required this.selected,
    required this.children,
    this.back = false,
    this.profileName,
  });
  final String title;
  final int selected;
  final List<Widget> children;
  final bool back;
  final String? profileName;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      title: Text(title),
      centerTitle: true,
      automaticallyImplyLeading: false,
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      leading: back
          ? IconButton(
              tooltip: 'Back to Home',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _home(context),
            )
          : null,
      actions: profileName == null
          ? null
          : [
              IconButton(
                tooltip: 'Profile',
                onPressed: () => Navigator.pushNamed(context, '/profile'),
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE0F2F1),
                  child: Text(
                    profileName!.trim().isEmpty
                        ? 'C'
                        : profileName!.trim().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: _teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: children,
        ),
      ),
    ),
    bottomNavigationBar: _CustomerNavigation(selected: selected),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: _ink,
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.color = Colors.white,
    this.border = const Color(0xFFB2DFDB),
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color color;
  final Color border;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1400796B),
          offset: Offset(0, 4),
          blurRadius: 16,
        ),
      ],
    ),
    child: child,
  );
}

class _ServiceHeader extends StatelessWidget {
  const _ServiceHeader({required this.queue, this.showOpen = false});
  final ServiceQueue queue;
  final bool showOpen;
  @override
  Widget build(BuildContext context) {
    final initials = queue.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.substring(0, 1))
        .join()
        .toUpperCase();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFE0F2F1),
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 14,
              color: _teal,
              fontWeight: FontWeight.w600,
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
                  height: 1.35,
                  color: _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                queue.description,
                style: const TextStyle(fontSize: 14, color: _ink),
              ),
            ],
          ),
        ),
        if (showOpen) ...[
          const SizedBox(width: 8),
          Text(
            queue.isOpen ? '● Open' : 'Closed',
            style: const TextStyle(
              fontSize: 14,
              color: _teal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.value1,
    required this.label1,
    required this.value2,
    required this.label2,
    this.color = const Color(0xFFF0FDFA),
  });
  final String value1, label1, value2, label2;
  final Color color;
  Widget _tile(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _teal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _tile(value1, label1),
      const SizedBox(width: 12),
      _tile(value2, label2),
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    this.title,
    this.titleSize = 16,
    this.color = const Color(0xFF00695C),
    this.background = const Color(0xFFE0F2F1),
    this.icon,
  });
  final String? title;
  final String message;
  final double titleSize;
  final Color color, background;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: titleSize,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                message,
                style: TextStyle(fontSize: 14, height: 1.5, color: color),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 1, child: CustomPaint(painter: _DashPainter(color)));
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + 4 > size.width ? size.width : x + 4, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CustomerNavigation extends StatelessWidget {
  const _CustomerNavigation({required this.selected});
  final int selected;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFE0F2F1),
        height: 80,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? _teal
                : const Color(0xFF5F6368),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? _teal
                : const Color(0xFF5F6368),
          ),
        ),
      ),
    ),
    child: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (index) {
        if (index == selected) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          index == 0 ? '/customer' : '/my-queue',
          (_) => false,
        );
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.format_list_bulleted),
          label: 'Home',
        ),
        NavigationDestination(icon: Icon(Icons.schedule), label: 'My Queue'),
      ],
    ),
  );
}
