import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  List<ScanHistory> _scanHistory = [];
  bool _isLoading = true;
  String _userName = '';
  int? _currentUserId;

  // ── Stagger controller ───────────────────────────────────────────────────
  late AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _loadHistory();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  // ── BUG FIX: always set _isLoading = false, even if user is null.
  // Previously, if getCurrentUser() returned null, isLoading stayed
  // true forever and the screen was stuck spinning.
  // Also stores userId so history is strictly per-user.
  void _loadHistory() async {
    try {
      final user = await AuthService.getCurrentUser();

      if (user != null) {
        final userId = int.parse(user['id']!);

        // Fetch this user's scan history — filtered by user_id in SQL.
        // Client-side filter below acts as a safety net for any stale
        // DB rows that may have an incorrect user_id from old sessions.
        final rawHistory =
            await DatabaseHelper.instance.getScanHistory(userId);
        // Safety net: double-check every record belongs to this user
        final history =
            rawHistory.where((s) => s.userId == userId).toList();

        setState(() {
          _currentUserId = userId;
          _userName = user['name'] ?? '';
          _scanHistory = history;
          _isLoading = false;
        });
        _listController
          ..reset()
          ..forward();
      } else {
        // User session not found — show empty state instead of spinning
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Safety net: on any error, stop loading and show empty state
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getRiskColor(int score) {
    if (score >= 70) return Color(0xFFEF4444);
    if (score >= 40) return Color(0xFFF59E0B);
    return Color(0xFF10B981);
  }

  String _getRiskEmoji(int score) {
    if (score >= 70) return "🚨";
    if (score >= 40) return "⚠️";
    return "✅";
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Orange header banner ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 56, 20, 24),
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
                  color: AppColors.orange.withOpacity(0.30),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
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
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_userName.isNotEmpty)
                        Text(
                          '${_userName}\'s scans only',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.80),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Logout button
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.logout,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.orange),
                    ),
                  )
                : _scanHistory.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.orange,
                        onRefresh: () async => _loadHistory(),
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
                          itemCount: _scanHistory.length,
                          itemBuilder: (context, index) {
                            final scan = _scanHistory[index];
                            // Stagger: each card starts 60ms after previous
                            final start = (index * 0.08).clamp(0.0, 0.8);
                            final end = (start + 0.4).clamp(0.0, 1.0);
                            final interval = Interval(start, end,
                                curve: Curves.easeOutCubic);
                            final fade = Tween<double>(
                                    begin: 0.0, end: 1.0)
                                .animate(CurvedAnimation(
                                    parent: _listController,
                                    curve: interval));
                            final slide = Tween<Offset>(
                                    begin: Offset(0, 0.18),
                                    end: Offset.zero)
                                .animate(CurvedAnimation(
                                    parent: _listController,
                                    curve: interval));
                            return FadeTransition(
                              opacity: fade,
                              child: SlideTransition(
                                position: slide,
                                child: _buildHistoryCard(scan),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history,
              color: AppColors.orange,
              size: 48,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No scan history yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Analyze a message to see your history here',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── History card ──────────────────────────────────────────────────────

  Widget _buildHistoryCard(ScanHistory scan) {
    final riskColor = _getRiskColor(scan.score);
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + risk badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(scan.createdAt),
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              Row(
                children: [
                  Text(_getRiskEmoji(scan.score),
                      style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      scan.level,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 12),

          // Score bar
          Row(
            children: [
              Text(
                'Risk Score: ',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              Text(
                '${scan.score}%',
                style: TextStyle(
                  color: riskColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 6),

          // Mini progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: scan.score / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              minHeight: 5,
            ),
          ),

          SizedBox(height: 12),

          // Message preview
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.orange.withOpacity(0.12)),
            ),
            child: Text(
              scan.message,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Detected issues (up to 3)
          if (scan.reasons.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              'Detected Issues:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            SizedBox(height: 6),
            ...scan.reasons.take(3).map(
                  (reason) => Container(
                    margin: EdgeInsets.only(bottom: 4),
                    padding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: riskColor, size: 13),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (scan.reasons.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  '...and ${scan.reasons.length - 3} more',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────

  void _logout() async {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold)),
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
            child: Text('Logout',
                style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
