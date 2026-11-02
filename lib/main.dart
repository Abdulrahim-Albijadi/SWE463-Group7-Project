import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/queue_data.dart';
import 'screens/customer_screens.dart';
import 'screens/provider_screens.dart';
import 'repositories/repositories.dart';
import 'providers/app_providers.dart';
import 'providers/membership_provider.dart';
import 'providers/auth_provider.dart';

void main() => runApp(
  AppProviders(
    authRepository: AuthRepository(),
    queueRepository: QueueRepository(),
    child: const QueueLessApp(),
  ),
);

class QueueLessApp extends StatefulWidget {
  const QueueLessApp({super.key});

  @override
  State<QueueLessApp> createState() => _QueueLessAppState();
}

class _QueueLessAppState extends State<QueueLessApp> {
  static const _customerRoutes = {'/customer', '/queue-details', '/my-queue'};
  static const _providerRoutes = {
    '/provider',
    '/create-queue',
    '/manage-queue',
  };

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<QueueNotification>? _alerts;

  @override
  void initState() {
    super.initState();
    // In-app message when the customer is near their turn or called.
    _alerts = context.read<MembershipProvider>().alerts.listen(
      (alert) => _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(alert.message)),
      ),
    );
  }

  @override
  void dispose() {
    _alerts?.cancel();
    super.dispose();
  }

  // Signed-out users reach only Login and Register. Each role reaches only its
  // own screens.
  String _allowedRoute(String? requested) {
    final name = requested ?? '/login';
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return name == '/register' ? name : '/login';
    if (_customerRoutes.contains(name) && user.role != UserRole.customer) {
      return '/provider';
    }
    if (_providerRoutes.contains(name) && user.role != UserRole.provider) {
      return '/customer';
    }
    return name;
  }
  
  Route<dynamic> _makeRoute(RouteSettings settings) {
    Widget page;
    switch (_allowedRoute(settings.name)) {
      case '/login':
        page =const LoginScreen();
        break;
      case '/register':
        page = const RegisterScreen();
        break;
      case '/customer':
        page = const CustomerHomeScreen();
        break;
      case '/queue-details':
        page = const QueueDetailsScreen();
        break;
      case '/my-queue':
        page = const MyQueueScreen();
        break;
      case '/provider':
        page = const ProviderDashboardScreen();
        break;
      case '/create-queue':
        page = const CreateQueueScreen();
        break;
      case '/manage-queue':
        page = const QueueManagementScreen();
        break;
      case '/profile':
        page = const ProfileScreen();
        break;
      default:
        page = const LoginScreen();
    }
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'QueueLess',
    scaffoldMessengerKey: _messengerKey,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
      scaffoldBackgroundColor: const Color(0xFFF7F9FA),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F9FA)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    initialRoute: '/login',
    onGenerateRoute: _makeRoute,
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'customer@example.com');
  final _password = TextEditingController(text: 'demopass');
  bool showPassword = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final outcome = await context.read<AuthProvider>().signIn(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!outcome.isOk) return;
    navigator.pushNamedAndRemoveUntil(
      outcome.user!.role == UserRole.customer ? '/customer' : '/provider',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) { 
  final auth = context.watch<AuthProvider>();
   return Scaffold(
    appBar: AppBar(title: const Text('QueueLess')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Sign In',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Sign in as a Customer or a Provider.'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || !v.contains('@')
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Password is required' : null,
              ),
              if (auth.error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    auth.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              const SizedBox(height: 18),
              FilledButton(onPressed: auth.isBusy? null :_login, child: const Text('Sign In')),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Create Account'),
              ),
              const SizedBox(height: 14),
              const Text(
                  'Test accounts: customer@example.com or '
                  'provider@example.com, password demopass.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _register() async {
    if (!_form.currentState!.validate()) return;
    // Demonstration only; passwords are NOT stored anywhere.
    final navigator = Navigator.of(context);
    final outcome= await context.read<AuthProvider>().register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      role: role,
    );

    if(!outcome.isOk) return;

    navigator.pushNamedAndRemoveUntil(
      role == UserRole.customer ? '/customer' : '/provider',
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context){    
    final auth = context.watch<AuthProvider>(); 
    return Scaffold(
    appBar: AppBar(title: const Text('Register')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Create an Account',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) =>
                v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (v) =>
                v == null || v.length < 6 ? 'Use at least 6 characters' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 16),
          const Text('Register as'),
          const SizedBox(height: 8),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(value: UserRole.customer, label: Text('Customer')),
              ButtonSegment(value: UserRole.provider, label: Text('Provider')),
            ],
            selected: {role},
            onSelectionChanged: (selection) =>
                setState(() => role = selection.first),
          ),
          if(auth.error !=null) ...[
            const SizedBox(height: 14),
            Text(
              auth.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.isBusy ? null : _register,
            child: Text(auth.isBusy ? 'Creating...' : 'Create Account'),
          ),
        ],
      ),
    ),
  );}
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});


  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Return to the sign-in screen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().signOut();
    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  

  @override
  Widget build(BuildContext context) { 
    final user = context.watch<AuthProvider>().currentUser;
     return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.account_circle, size: 52),
                    const SizedBox(height: 10),
                    Text(
                      user?.name ?? 'Not signed in',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(user?.email ?? 'No email'),
                    Text('Role: ${user?.role.name ?? 'None'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () => _logout(context),
            ),
          ],
        ),
      ),
    );
    }
}
