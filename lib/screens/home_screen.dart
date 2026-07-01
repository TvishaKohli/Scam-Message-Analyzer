import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'result_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../services/analyzer.dart';
import '../utils/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  TextEditingController controller = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  bool _isAnalyzing = false;
  Map<String, String?> _currentUser = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    testDB();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _loadCurrentUser() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    controller.dispose();
    super.dispose();
  }

  void analyzeMessage() async {
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a message to analyze'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    HapticFeedback.lightImpact();

    await Future.delayed(Duration(milliseconds: 500));

    // Store scan history
    final currentUser = await AuthService.getCurrentUser();
    if (currentUser != null) {
      final result = await Analyzer.analyze(controller.text);

      final scanHistory = ScanHistory(
        userId: int.parse(currentUser['id']!),
        message: controller.text,
        score: result['score'],
        level: result['level'],
        reasons: List<String>.from(result['reasons']),
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.instance.insertScanHistory(scanHistory);
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ResultScreen(message: controller.text),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: Offset(0.0, 1.0), end: Offset.zero),
            ),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    );

    setState(() {
      _isAnalyzing = false;
    });
  }

  void testDB() async {
    final patterns = await DatabaseHelper.instance.getPatterns();
    print(patterns);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.shield, color: AppColors.orange, size: 22),
            SizedBox(width: 8),
            Text(
              'Scam Analyzer',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person_outline, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.primary),
            onPressed: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.card,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    'Are you sure you want to logout?',
                    style: TextStyle(color: Colors.white60),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await AuthService.logout();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: Text(
                        'Logout',
                        style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),

              // ── Welcome greeting ───────────────────────────────────────
              Text(
                'Welcome ${_currentUser['name'] ?? ''},',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Stay one step ahead of scams',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),

              SizedBox(height: 24),

              // ── Message input card ─────────────────────────────────────
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black26,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Message',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 5,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Paste message here...',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppColors.orange.withOpacity(0.2),
                              width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.orange, width: 2),
                        ),
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // ── Analyze button ─────────────────────────────────────────
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.orange, AppColors.softOrange],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange.withOpacity(0.40),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _isAnalyzing ? null : analyzeMessage,
                        child: Center(
                          child: _isAnalyzing
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Analyzing...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Analyze Message',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 28),

              // ── Feature cards ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _featureCard('Lightning Fast', Icons.flash_on),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _featureCard('AI Powered', Icons.smart_toy),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _featureCard('Secure', Icons.lock_outline),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _featureCard('History', Icons.history),
                  ),
                ],
              ),

              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard(String title, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.orange, size: 22),
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
