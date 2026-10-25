import 'package:flutter/material.dart';

import '../../models/queue_data.dart';

const customerTeal = Color(0xFF00796B);
const _ink = Color(0xFF1D1B20);
const customerMuted = Color(0xFF64748B);
const customerRed = Color(0xFFB3261E);
const customerAmber = Color(0xFFB26A00);
const _background = Color(0xFFF7F9FA);

void customerHome(BuildContext context) =>
    Navigator.pushNamedAndRemoveUntil(context, '/customer', (_) => false);

// Shared presentation widgets. Queue rules remain in QueueDemoState.
class CustomerPage extends StatelessWidget {
  const CustomerPage({
    super.key,
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
              onPressed: () => customerHome(context),
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
                      color: customerTeal,
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

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
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

class Surface extends StatelessWidget {
  const Surface({
    super.key,
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

class ServiceHeader extends StatelessWidget {
  const ServiceHeader({super.key, required this.queue, this.showOpen = false});
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
              color: customerTeal,
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
              color: customerTeal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class Stats extends StatelessWidget {
  const Stats({
    super.key,
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
              color: customerTeal,
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

class Notice extends StatelessWidget {
  const Notice({
    super.key,
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

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: customerTeal,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key, required this.color});
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
                ? customerTeal
                : const Color(0xFF5F6368),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? customerTeal
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
