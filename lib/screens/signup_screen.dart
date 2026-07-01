import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ── Entrance animations ──────────────────────────────────────────────────
  late AnimationController _entranceController;
  late Animation<Offset> _headerSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _headerSlide = Tween<Offset>(begin: Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _entranceController,
      curve: Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<Offset>(begin: Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _entranceController,
      curve: Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.lightImpact();

    try {
      final success = await AuthService.signup(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );

        await Future.delayed(Duration(seconds: 2));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email already exists'),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signup failed. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Reusable styled field builder
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool obscure = false,
    bool showToggle = false,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.background),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: Icon(prefixIcon, color: AppColors.orange),
        suffixIcon: showToggle
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey.shade400,
                ),
                onPressed: onToggle,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Orange hero banner (slides down) ──────────────────────────
            SlideTransition(
              position: _headerSlide,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24, 72, 24, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.orange, AppColors.softOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withOpacity(0.35),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Back button row
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.arrow_back,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_add,
                          size: 48, color: Colors.white),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Join Scam Analyzer to stay safe',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Sign up form card (fades + slides up) ─────────────────────
            FadeTransition(
              opacity: _cardFade,
              child: SlideTransition(
                position: _cardSlide,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Container(
                    padding: EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Let\'s get started 🚀',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.background,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Fill in your details below',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                          ),
                          SizedBox(height: 24),

                          // Full Name
                          _buildField(
                            controller: _nameController,
                            hint: 'Full Name',
                            prefixIcon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              if (value.length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 14),

                          // Email
                          _buildField(
                            controller: _emailController,
                            hint: 'Email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 14),

                          // Password
                          _buildField(
                            controller: _passwordController,
                            hint: 'Password',
                            prefixIcon: Icons.lock_outline,
                            obscure: _obscurePassword,
                            showToggle: true,
                            onToggle: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 14),

                          // Confirm Password
                          _buildField(
                            controller: _confirmPasswordController,
                            hint: 'Confirm Password',
                            prefixIcon: Icons.lock_outline,
                            obscure: _obscureConfirmPassword,
                            showToggle: true,
                            onToggle: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 30),

                          // Sign Up button
                          Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.orange,
                                  AppColors.softOrange
                                ],
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
                                onTap: _isLoading ? null : _signup,
                                child: Center(
                                  child: _isLoading
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Creating account...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.person_add,
                                                color: Colors.white, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Sign Up',
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Already have account link (fades with card) ───────────────
            FadeTransition(
              opacity: _cardFade,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
