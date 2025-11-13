import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // On web, skip login and go straight to main page (uses token auth)
    if (kIsWeb) {
      return const MainPage();
    }
    // On native, check session
    final auth = AuthService();
    return FutureBuilder<bool>(
      future: auth.sessionExists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final loggedIn = snapshot.data == true;
        if (loggedIn) {
          return const MainPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
