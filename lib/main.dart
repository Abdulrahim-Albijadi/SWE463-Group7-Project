import 'package:flutter/material.dart';
import 'models/queue_data.dart';
import 'screens/customer_screens.dart';
import 'screens/provider_screens.dart';

void main() => runApp(const QueueLessApp());

class QueueLessApp extends StatefulWidget {
  const QueueLessApp({super.key});

  @override
  State<QueueLessApp> createState() => _QueueLessAppState();
}

class _QueueLessAppState extends State<QueueLessApp> {
  final QueueDemoState state = QueueDemoState();

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  Route<dynamic> _makeRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case '/login':
        page = LoginScreen(state: state);
        break;
      case '/register':
        page = RegisterScreen(state: state);
        break;
      case '/customer':
        page = CustomerHomeScreen(state: state);
        break;
      case '/queue-details':
        page = QueueDetailsScreen(state: state);
        break;
      case '/my-queue':
        page = MyQueueScreen(state: state);
        break;
      case '/provider':
        page = ProviderDashboardScreen(state: state);
        break;
      case '/create-queue':
        page = CreateQueueScreen(state: state);
        break;
      case '/manage-queue':
        page = QueueManagementScreen(state: state);
        break;
      case '/profile':
        page = ProfileScreen(state: state);
        break;
      default:
        page = LoginScreen(state: state);
    }
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'QueueLess',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
      scaffoldBackgroundColor: const Color(0xFFF7F9FA),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F9FA)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    initialRoute: '/login',
    onGenerateRoute: _makeRoute,
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});
  final QueueDemoState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'customer@example.com');
  final _password = TextEditingController(text: 'demopass');
  UserRole role = UserRole.customer;
  bool showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (!_form.currentState!.validate()) return;
    // UI demonstration ONLY. No credentials are checked or persisted.
    widget.state.signInAs(role, email: _email.text.trim());
    Navigator.pushNamedAndRemoveUntil(context,
      role == UserRole.customer ? '/customer' : '/provider', (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QueueLess')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Form(key: _form, child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          Text('Sign In', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Demo login for Customer and Provider roles'),
          const SizedBox(height: 20),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: !showPassword,
            decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(
              icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => showPassword = !showPassword),
            )),
            validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
          ),
          const SizedBox(height: 16),
          const Text('Demo role'),
          const SizedBox(height: 8),
          SegmentedButton<UserRole>(segments: const [
            ButtonSegment(value: UserRole.customer, label: Text('Customer')),
            ButtonSegment(value: UserRole.provider, label: Text('Provider')),
          ], selected: {role}, onSelectionChanged: (selected) =>
            setState(() => role = selected.first)),
          const SizedBox(height: 18),
          FilledButton(onPressed: _login, child: const Text('Sign In')),
          TextButton(onPressed: () => Navigator.pushNamed(context, '/register'),
            child: const Text('Create Account')),
          const SizedBox(height: 14),
          const Text('Placeholder only. Firebase Authentication is planned for Phase 3.',
            textAlign: TextAlign.center),
        ],
      )),
    )),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.state});
  final QueueDemoState state;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  UserRole role = UserRole.customer;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  void _register() {
    if (!_form.currentState!.validate()) return;
    // Demonstration only; passwords are NOT stored anywhere.
    widget.state.signInAs(role, email: _email.text.trim(), name: _name.text.trim());
    Navigator.pushNamedAndRemoveUntil(context,
      role == UserRole.customer ? '/customer' : '/provider', (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Register')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Create an Account', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      TextFormField(controller: _name,
        decoration: const InputDecoration(labelText: 'Full name'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email'),
        validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _password, obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
        validator: (v) => v == null || v.length < 6 ? 'Use at least 6 characters' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _confirm, obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm password'),
        validator: (v) => v != _password.text ? 'Passwords do not match' : null),
      const SizedBox(height: 16),
      const Text('Register as'),
      const SizedBox(height: 8),
      SegmentedButton<UserRole>(segments: const [
        ButtonSegment(value: UserRole.customer, label: Text('Customer')),
        ButtonSegment(value: UserRole.provider, label: Text('Provider')),
      ], selected: {role}, onSelectionChanged: (selection) =>
        setState(() => role = selection.first)),
      const SizedBox(height: 20),
      FilledButton(onPressed: _register, child: const Text('Create Account')),
      const SizedBox(height: 12),
      const Text('Demo only. Real registration will use Firebase Authentication.'),
    ])),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});
  final QueueDemoState state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final user = state.currentUser;
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Padding(padding: const EdgeInsets.all(20), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_circle, size: 52),
                const SizedBox(height: 10),
                Text(user?.name ?? 'Not signed in',
                  style: Theme.of(context).textTheme.titleLarge),
                Text(user?.email ?? 'No email'),
                Text('Role: ${user?.role.name ?? 'None'}'),
              ],
            ))),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text('Return to the sign-in screen?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Log Out')),
                    ],
                  ));
                if (confirmed != true || !context.mounted) return;
                state.logout();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              },
            ),
          ],
        )),
      );
    },
  );
}
