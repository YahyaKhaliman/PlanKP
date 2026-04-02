import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/master/providers/master_provider.dart';
import 'features/jadwal/providers/jadwal_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/jadwal/screens/jadwal_detail_screen.dart';
import 'features/jadwal/screens/realisasi_form_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlanKPApp());
}

class PlanKPApp extends StatelessWidget {
  const PlanKPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MasterProvider()),
        ChangeNotifierProvider(create: (_) => JadwalProvider()),
      ],
      child: MaterialApp(
        title: 'PlanKP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routes: {
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.register: (_) => const RegisterScreen(),
          AppRoutes.dashboard: (_) => const _ProtectedRoute(
                child: DashboardScreen(),
              ),
          AppRoutes.jadwalDetail: (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments as int;
            return _ProtectedRoute(
              allowedRoles: const ['admin'],
              child: JadwalDetailScreen(jadwalId: args),
            );
          },
          AppRoutes.realisasiForm: (ctx) {
            final args =
                ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
            return _ProtectedRoute(
              allowedRoles: const ['user'],
              child: RealisasiFormScreen(args: args),
            );
          },
        },
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.checkSession();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          auth.isLoggedIn ? AppRoutes.dashboard : AppRoutes.login,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProtectedRoute extends StatelessWidget {
  final Widget child;
  final List<String>? allowedRoles;

  const _ProtectedRoute({
    required this.child,
    this.allowedRoles,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoggedIn) {
      final role = auth.jabatan;
      final isRoleAllowed =
          allowedRoles == null || allowedRoles!.contains(role);
      if (isRoleAllowed) return child;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
