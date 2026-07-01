import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminScreen – admin-only panel.
// Access: sign in with the hard-coded admin credentials
//   email   : admin@scam.ai
//   password: admin123
// ─────────────────────────────────────────────────────────────────────────────

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── data ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;

  // Dashboard stats
  int _totalUsers = 0;
  int _totalScans = 0;
  int _highRiskScans = 0;
  int _safeScans = 0;

  // Users tab
  List<Map<String, dynamic>> _users = [];

  // All scans tab
  List<Map<String, dynamic>> _allScans = [];

  // Search / filter
  String _userSearch = '';
  String _scanFilter = 'All'; // All | High | Medium | Safe
  final List<String> _filterOptions = ['All', 'High', 'Medium', 'Safe'];

  // ── Stat card stagger animation ───────────────────────────────────────────
  late AnimationController _statsController;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _statsController = AnimationController(
      duration: Duration(milliseconds: 700),
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final adminData = await DatabaseHelper.instance.getAdminDashboardData();
      setState(() {
        _totalUsers    = adminData['totalUsers']    as int;
        _totalScans    = adminData['totalScans']    as int;
        _highRiskScans = adminData['highRiskScans'] as int;
        _safeScans     = adminData['safeScans']     as int;
        _users         = List<Map<String, dynamic>>.from(adminData['users'] as List);
        _allScans      = List<Map<String, dynamic>>.from(adminData['allScans'] as List);
        _isLoading     = false;
      });
      _statsController
        ..reset()
        ..forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load admin data: $e'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Color _riskColor(int score) {
    if (score >= 70) return Color(0xFFEF4444);
    if (score >= 40) return Color(0xFFF59E0B);
    return Color(0xFF10B981);
  }

  String _riskEmoji(int score) {
    if (score >= 70) return '🚨';
    if (score >= 40) return '⚠️';
    return '✅';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      return iso;
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_userSearch.isEmpty) return _users;
    final q = _userSearch.toLowerCase();
    return _users
        .where((u) =>
            (u['name'] as String).toLowerCase().contains(q) ||
            (u['email'] as String).toLowerCase().contains(q))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredScans {
    return _allScans.where((s) {
      final score = s['score'] as int;
      switch (_scanFilter) {
        case 'High':
          return score >= 70;
        case 'Medium':
          return score >= 40 && score < 70;
        case 'Safe':
          return score < 40;
        default:
          return true;
      }
    }).toList();
  }

  // ── delete helpers ────────────────────────────────────────────────────────

  Future<void> _deleteUser(int userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete User',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Delete "$name" and all their scan history? This cannot be undone.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteUser(userId);
      _loadData();
    }
  }

  Future<void> _deleteScan(int scanId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Scan',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Remove this scan record?',
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteScan(scanId);
      _loadData();
    }
  }

  // ── logout ────────────────────────────────────────────────────────────────

  void _logout() async {
    HapticFeedback.lightImpact();
    await AuthService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDashboardTab(),
                      _buildUsersTab(),
                      _buildScansTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 56, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.orange, AppColors.softOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withOpacity(0.35),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Scam Analyzer  ·  Full access',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.80),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Refresh
          GestureDetector(
            onTap: _loadData,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
          SizedBox(width: 8),
          // Logout
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Dashboard'),
          Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Users'),
          Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Scans'),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 – Dashboard
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardTab() {
    final mediumScans = _totalScans - _highRiskScans - _safeScans;
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          // ── Stat cards grid (staggered pop-in) ──────────────────────────
          Row(
            children: [
              Expanded(child: _animatedStatCard(0,
                icon: Icons.people_outline,
                label: 'Total Users',
                value: _totalUsers.toString(),
                color: Color(0xFF6366F1),
              )),
              SizedBox(width: 12),
              Expanded(child: _animatedStatCard(1,
                icon: Icons.document_scanner_outlined,
                label: 'Total Scans',
                value: _totalScans.toString(),
                color: AppColors.orange,
              )),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _animatedStatCard(2,
                icon: Icons.dangerous_outlined,
                label: 'High Risk',
                value: _highRiskScans.toString(),
                color: Color(0xFFEF4444),
              )),
              SizedBox(width: 12),
              Expanded(child: _animatedStatCard(3,
                icon: Icons.check_circle_outline,
                label: 'Safe Scans',
                value: _safeScans.toString(),
                color: Color(0xFF10B981),
              )),
            ],
          ),

          SizedBox(height: 24),

          // ── Risk distribution bar ────────────────────────────────────────
          _sectionTitle('Risk Distribution'),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: Column(
              children: [
                if (_totalScans == 0)
                  Text('No scans yet', style: TextStyle(color: Colors.white54))
                else ...[
                  _riskBar('High Risk', _highRiskScans, _totalScans, Color(0xFFEF4444)),
                  SizedBox(height: 10),
                  _riskBar('Medium Risk', mediumScans < 0 ? 0 : mediumScans, _totalScans, Color(0xFFF59E0B)),
                  SizedBox(height: 10),
                  _riskBar('Safe', _safeScans, _totalScans, Color(0xFF10B981)),
                ],
              ],
            ),
          ),

          SizedBox(height: 24),

          // ── Recent scans preview ─────────────────────────────────────────
          _sectionTitle('Recent Scans'),
          SizedBox(height: 12),
          if (_allScans.isEmpty)
            _emptyCard('No scans recorded yet')
          else
            ..._allScans.take(5).map((s) => _scanMiniCard(s)),
          if (_allScans.length > 5)
            GestureDetector(
              onTap: () => _tabController.animateTo(2),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'View all ${_allScans.length} scans →',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Wraps [_statCard] in a staggered scale + fade animation.
  Widget _animatedStatCard(int idx, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final start = (idx * 0.18).clamp(0.0, 0.7);
    final end   = (start + 0.45).clamp(0.0, 1.0);
    final curve = Interval(start, end, curve: Curves.easeOutBack);
    final scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _statsController, curve: curve),
    );
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _statsController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: scale,
        child: _statCard(icon: icon, label: label, value: value, color: color),
      ),
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _riskBar(String label, int count, int total, Color color) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(color: Colors.white60, fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        SizedBox(width: 8),
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _scanMiniCard(Map<String, dynamic> s) {
    final score = s['score'] as int;
    final color = _riskColor(score);
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Text(_riskEmoji(score), style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['message'] as String,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  '${s['user_name'] ?? 'Unknown'}  ·  ${_formatDate(s['created_at'] as String)}',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            '$score%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 – Users
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildUsersTab() {
    final users = _filteredUsers;
    return Column(
      children: [
        // Search bar
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _userSearch = v),
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search users…',
              hintStyle: TextStyle(color: Colors.white38),
              prefixIcon: Icon(Icons.search, color: AppColors.orange),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.orange, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // Total badge
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${users.length} user${users.length != 1 ? 's' : ''}',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? _emptyState('No users found', Icons.person_off_outlined)
              : RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: users.length,
                    itemBuilder: (_, i) => _buildUserCard(users[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final scanCount = u['scan_count'] as int? ?? 0;
    final initial = (u['name'] as String).isNotEmpty
        ? (u['name'] as String)[0].toUpperCase()
        : '?';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        border: Border.all(color: AppColors.orange.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.orange, AppColors.softOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u['name'] as String,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                SizedBox(height: 2),
                Text(
                  u['email'] as String,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.document_scanner_outlined, color: AppColors.orange, size: 13),
                    SizedBox(width: 4),
                    Text(
                      '$scanCount scan${scanCount != 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 13),
                    SizedBox(width: 4),
                    Text(
                      _formatDate(u['created_at'] as String),
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Delete
          GestureDetector(
            onTap: () => _deleteUser(u['id'] as int, u['name'] as String),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFEF4444).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 – All Scans
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildScansTab() {
    final scans = _filteredScans;
    return Column(
      children: [
        // Filter chips
        Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions
                  .map((f) => Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _scanFilter = f),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _scanFilter == f
                                  ? AppColors.orange
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _scanFilter == f
                                    ? AppColors.orange
                                    : Colors.white24,
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                color: _scanFilter == f
                                    ? Colors.white
                                    : Colors.white60,
                                fontWeight: _scanFilter == f
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        // Count badge
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Text(
                '${scans.length} result${scans.length != 1 ? 's' : ''}',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: scans.isEmpty
              ? _emptyState('No scans match this filter', Icons.search_off_rounded)
              : RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: scans.length,
                    itemBuilder: (_, i) => _buildScanCard(scans[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildScanCard(Map<String, dynamic> s) {
    final score = s['score'] as int;
    final color = _riskColor(score);
    final reasons = (s['reasons'] as String).split(',').where((r) => r.trim().isNotEmpty).toList();

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: user name + date + risk badge + delete
          Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.orange, size: 14),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${s['user_name'] ?? 'Unknown'}  ·  ${_formatDate(s['created_at'] as String)}',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Text(_riskEmoji(score), style: TextStyle(fontSize: 14)),
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s['level'] as String,
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 6),
              GestureDetector(
                onTap: () => _deleteScan(s['id'] as int),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 15),
                ),
              ),
            ],
          ),

          SizedBox(height: 10),

          // Score bar
          Row(
            children: [
              Text('Risk: ', style: TextStyle(color: Colors.white54, fontSize: 13)),
              Text(
                '$score%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),

          SizedBox(height: 10),

          // Message preview
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.orange.withOpacity(0.12)),
            ),
            child: Text(
              s['message'] as String,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Reasons
          if (reasons.isNotEmpty) ...[
            SizedBox(height: 10),
            Text('Detected Issues:', style: TextStyle(color: Colors.white54, fontSize: 12)),
            SizedBox(height: 6),
            ...reasons.take(3).map(
                  (r) => Container(
                    margin: EdgeInsets.only(bottom: 4),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: color, size: 13),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(r.trim(),
                              style: TextStyle(color: Colors.white60, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
            if (reasons.length > 3)
              Text(
                '…and ${reasons.length - 3} more',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }

  // ── Shared small widgets ───────────────────────────────────────────────────

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.orange, size: 40),
          ),
          SizedBox(height: 16),
          Text(msg, style: TextStyle(color: Colors.white54, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(msg, style: TextStyle(color: Colors.white54, fontSize: 14)),
      ),
    );
  }
}
