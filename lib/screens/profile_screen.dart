import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../utils/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  String _userName = '';
  String _userEmail = '';
  int? _currentUserId;
  bool _isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadUser();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _loadUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUserId = int.tryParse(user['id'] ?? '');
          _userName = user['name'] ?? '';
          _userEmail = user['email'] ?? '';
          _isLoading = false;
        });
        _fadeController.forward();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────
  void _logout() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text(
              'Log Out',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Clear History ─────────────────────────────────────────────────────
  void _clearHistory() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear History',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete all your scan history. This action cannot be undone.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_currentUserId != null) {
                final db = await DatabaseHelper.instance.database;
                await db.delete(
                  'scan_history',
                  where: 'user_id = ?',
                  whereArgs: [_currentUserId],
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Scan history cleared'),
                    backgroundColor: AppColors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Clear',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit Profile (name) ───────────────────────────────────────────────
  void _editProfile() {
    HapticFeedback.lightImpact();
    final nameController = TextEditingController(text: _userName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Edit Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Display Name',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter your name',
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
                        color: AppColors.orange.withOpacity(0.2), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.orange, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty && _currentUserId != null) {
                      final db = await DatabaseHelper.instance.database;
                      await db.update(
                        'users',
                        {'name': newName},
                        where: 'id = ?',
                        whereArgs: [_currentUserId],
                      );
                      // Update shared prefs
                      final prefs =
                          await AuthService.getCurrentUser();
                      setState(() => _userName = newName);
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Profile updated'),
                        backgroundColor: AppColors.orange,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Change Password ───────────────────────────────────────────────────
  void _changePassword() {
    HapticFeedback.lightImpact();
    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();
    bool _obscureCurrent = true;
    bool _obscureNew = true;
    bool _obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Change Password',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _pwdField(
                      'Current Password',
                      currentPwdController,
                      _obscureCurrent,
                      () => setModalState(
                          () => _obscureCurrent = !_obscureCurrent),
                    ),
                    const SizedBox(height: 14),
                    _pwdField(
                      'New Password',
                      newPwdController,
                      _obscureNew,
                      () => setModalState(() => _obscureNew = !_obscureNew),
                    ),
                    const SizedBox(height: 14),
                    _pwdField(
                      'Confirm New Password',
                      confirmPwdController,
                      _obscureConfirm,
                      () => setModalState(
                          () => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final current = currentPwdController.text.trim();
                          final newPwd = newPwdController.text.trim();
                          final confirm = confirmPwdController.text.trim();

                          if (current.isEmpty ||
                              newPwd.isEmpty ||
                              confirm.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Please fill all fields'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (newPwd != confirm) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Passwords do not match'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (_currentUserId != null) {
                            final db =
                                await DatabaseHelper.instance.database;
                            // Verify current password
                            final rows = await db.query(
                              'users',
                              where: 'id = ? AND password = ?',
                              whereArgs: [_currentUserId, current],
                            );
                            if (rows.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Current password is incorrect'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            await db.update(
                              'users',
                              {'password': newPwd},
                              where: 'id = ?',
                              whereArgs: [_currentUserId],
                            );
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Password changed successfully'),
                              backgroundColor: AppColors.orange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Update Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _pwdField(
    String label,
    TextEditingController ctrl,
    bool obscure,
    VoidCallback toggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppColors.background,
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.white38,
                size: 20,
              ),
              onPressed: toggle,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: AppColors.orange.withOpacity(0.2), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.orange, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Orange header ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.orange, AppColors.softOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withOpacity(0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.orange),
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      child: Column(
                        children: [
                          // ── Avatar + name + email ───────────────────────
                          _buildAvatar(),
                          const SizedBox(height: 14),
                          Text(
                            _userName.isNotEmpty ? _userName : 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userEmail,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Account section ─────────────────────────────
                          _buildSection(
                            'Account',
                            [
                              _buildTile(
                                icon: Icons.person_outline,
                                label: 'Edit Profile',
                                onTap: _editProfile,
                              ),
                              _buildDivider(),
                              _buildTile(
                                icon: Icons.lock_outline,
                                label: 'Change Password',
                                onTap: _changePassword,
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Customize section ────────────────────────────
                          _buildSection(
                            'Customize',
                            [
                              _buildTile(
                                icon: Icons.dark_mode_outlined,
                                label: 'Theme',
                                trailing: Text(
                                  'Dark',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                  ),
                                ),
                                onTap: () {},
                              ),
                              _buildDivider(),
                              _buildTile(
                                icon: Icons.delete_outline,
                                label: 'Clear History',
                                onTap: _clearHistory,
                              ),
                              _buildDivider(),
                              _buildTile(
                                icon: Icons.power_settings_new,
                                label: 'Log Out',
                                labelColor: const Color(0xFFEF4444),
                                iconColor: const Color(0xFFEF4444),
                                onTap: _logout,
                                showChevron: false,
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // ── Version ──────────────────────────────────────
                          Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Avatar widget ─────────────────────────────────────────────────────
  Widget _buildAvatar() {
    final initials = _userName.isNotEmpty
        ? _userName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.orange, AppColors.softOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withOpacity(0.40),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Section card ──────────────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // ── Row tile ──────────────────────────────────────────────────────────
  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
    Color? labelColor,
    Color? iconColor,
    bool showChevron = true,
  }) {
    final color = iconColor ?? AppColors.orange;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing,
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: Colors.white38, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  // ── Divider between tiles ─────────────────────────────────────────────
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.06),
      indent: 54,
    );
  }
}
