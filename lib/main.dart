import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

// Providers
import 'package:med_shakthi/src/features/cart/data/cart_data.dart';
import 'package:med_shakthi/src/features/checkout/presentation/screens/address_store.dart';
import 'package:med_shakthi/src/features/checkout/presentation/screens/payment_method_store.dart';
import 'package:med_shakthi/src/features/wishlist/data/wishlist_service.dart';
import 'package:med_shakthi/src/core/theme/theme_provider.dart';
import 'package:med_shakthi/src/core/theme/app_theme.dart';
// Auth & Dashboards
import 'package:med_shakthi/src/features/auth/presentation/screens/login_page.dart';
import 'package:med_shakthi/src/features/dashboard/pharmacy_home_screen.dart';
import 'package:med_shakthi/src/features/dashboard/supplier_dashboard.dart';

// 🔐 Reset Password Page
import 'package:med_shakthi/src/features/auth/presentation/screens/reset_password_page.dart';

/// 🔑 GLOBAL NAVIGATOR KEY (IMPORTANT)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];

    if (supabaseUrl == null ||
        supabaseUrl.isEmpty ||
        supabaseAnonKey == null ||
        supabaseAnonKey.isEmpty ||
        oneSignalAppId == null ||
        oneSignalAppId.isEmpty) {
      throw Exception('Missing configuration in .env');
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    // Initialize OneSignal
    OneSignal.initialize(oneSignalAppId);

    // Ask notification permission (important for Android 13+)
    await OneSignal.Notifications.requestPermission(true);
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartData()),
        ChangeNotifierProvider(create: (_) => AddressStore()),
        ChangeNotifierProvider(create: (_) => PaymentMethodStore()),
        ChangeNotifierProvider(create: (_) => WishlistService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Med Shakthi',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const RootRouter(),
        );
      },
    );
  }
}

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  /// Set to true during signup logic to prevent AuthGate from querying roles
  /// before DB inserts are completed.
  static bool suppressAuthRedirect = false;

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  Session? _session;
  bool _isRecoveringPassword = false;

  @override
  void initState() {
    super.initState();

    try {
      _session = Supabase.instance.client.auth.currentSession;

      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;

        if (!mounted) return;

        if (event == AuthChangeEvent.passwordRecovery) {
          setState(() {
            _isRecoveringPassword = true;
          });

          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
            (_) => false,
          );
          return;
        }

        setState(() {
          _session = session;
          _isRecoveringPassword = false;
        });

        // 🧹 Clear navigation stack whenever auth state changes
        // This ensures any pushed routes (like Signup/Forgot Pwd) are cleared
        // and we are back at the RootRouter which has the PopScope.
        if ((event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.signedOut) &&
            !RootRouter.suppressAuthRedirect) {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      debugPrint('RootRouter initState error: $e');
    }
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6AA39B).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF6AA39B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirm Exit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to leave?\nWe\'ll be waiting for your return.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF6AA39B)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Stay',
                        style: TextStyle(color: Color(0xFF6AA39B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: const Color(0xFF6AA39B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Exit'),
                    ),
                  ),
                ],
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    // 🛑 CHECK IF SUPABASE IS INITIALIZED
    try {
      Supabase.instance.client;
      // 🔐 PASSWORD RESET FLOW (HIGHEST PRIORITY)
      if (_isRecoveringPassword) {
        child = const ResetPasswordPage();
      }
      // 🔐 NORMAL AUTH FLOW
      else if (_session == null) {
        child = const LoginPage();
      } else {
        child = const AuthGate();
      }
    } catch (_) {
      child = const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Configuration Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check if your .env file contains valid SUPABASE_URL and SUPABASE_ANON_KEY.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog(context);
        if (shouldExit && mounted) {
          SystemNavigator.pop();
        }
      },
      child: child,
    );
  }
}

/// 🔐 AUTH GATE (ROLE BASED NAVIGATION)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isSupplier = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _setupOneSignalObserver();
  }

  void _setupOneSignalObserver() {
    // 1. Check synchronously first just in case it's already available
    final initialId = OneSignal.User.pushSubscription.id;
    if (initialId != null) {
      _updatePlayerIdInDb(initialId);
    }

    // 2. Listen for future changes (e.g. late initialization or permission grant)
    OneSignal.User.pushSubscription.addObserver((state) {
      final newId = state.current.id;
      if (newId != null) {
        _updatePlayerIdInDb(newId);
      }
    });
  }

  Future<void> _updatePlayerIdInDb(String playerId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Check if they are a supplier
      final supplierData = await Supabase.instance.client
          .from('suppliers')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (supplierData != null) {
        await Supabase.instance.client
            .from('suppliers')
            .update({'onesignal_player_id': playerId})
            .eq('user_id', user.id);
        debugPrint(
          "Successfully updated OneSignal Player ID for supplier: $playerId",
        );
      }
    } catch (e) {
      debugPrint("Failed to update OneSignal Player ID: $e");
    }
  }

  Future<void> _checkUserRole() async {
    try {
      // ⏳ Wait if a signup process is currently orchestrating DB insertions
      while (RootRouter.suppressAuthRedirect) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
      }

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = await Supabase.instance.client
          .from('suppliers')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      // IF USER IS SUPPLIER
      if (data != null) {
        setState(() {
          _isSupplier = true;
        });
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AuthGate error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⏳ Loading
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4C8077)),
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;

    // 🔐 Not logged in
    if (user == null) {
      return const LoginPage();
    }

    // 🧑‍⚕️ Supplier vs User
    if (_isSupplier) {
      return const SupplierDashboard();
    } else {
      return const PharmacyHomeScreen();
    }
  }
}
