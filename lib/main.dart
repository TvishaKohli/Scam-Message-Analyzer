import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/history_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';
import 'services/csv_loader.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scam Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/home': (context) => HomeScreen(),
        '/history': (context) => HistoryScreen(),
        '/admin': (context) => AdminScreen(),
        '/profile': (context) => ProfileScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isAdmin    = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    await CsvLoader.loadDatasets();
    final isLoggedIn = await AuthService.isLoggedIn();
    final isAdmin    = isLoggedIn ? await AuthService.isAdmin() : false;
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isAdmin    = isAdmin;
      _isLoading  = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF0F0F1E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
              SizedBox(height: 24),
              Text(
                'Training AI model...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _isAdmin
        ? AdminScreen()
        : _isLoggedIn
            ? HomeScreen()
            : LoginScreen();
  }
}
