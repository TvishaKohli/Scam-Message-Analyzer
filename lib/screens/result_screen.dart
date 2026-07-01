import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/analyzer.dart';
import '../utils/app_colors.dart';

class ResultScreen extends StatefulWidget {
  final String message;

  const ResultScreen({super.key, required this.message});

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  int score = 0;
  String level = "";
  List<String> reasons = [];
  int nbProbability = 0;
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
              parent: _slideController, curve: Curves.elasticOut),
        );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _progressController, curve: Curves.easeOutCubic),
    );

    analyzeMessage();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void analyzeMessage() async {
    final result = await Analyzer.analyze(widget.message);

    setState(() {
      score = result['score'];
      level = result['level'];
      reasons = List<String>.from(result['reasons']);
      nbProbability = result['nb_probability'] ?? 0;
      _isLoading = false;
    });

    _slideController.forward();
    _progressController.forward();
  }

  Color getRiskColor() {
    if (score >= 70) return Color(0xFFEF4444);
    if (score >= 40) return Color(0xFFF59E0B);
    return Color(0xFF10B981);
  }

  String getRiskEmoji() {
    if (score >= 70) return "🚨";
    if (score >= 40) return "⚠️";
    return "✅";
  }

  String getRiskLabel() {
    if (score >= 70) return "High Risk";
    if (score >= 40) return "Medium Risk";
    return "Low Risk";
  }

  TextSpan highlightText(String text) {
    List<TextSpan> spans = [];
    List<String> words = text.toLowerCase().split(' ');

    for (int i = 0; i < words.length; i++) {
      String word = words[i];
      bool isSuspicious = false;

      for (String reason in reasons) {
        if (word.contains(reason.toLowerCase())) {
          isSuspicious = true;
          break;
        }
      }

      spans.add(
        TextSpan(
          text: word + (i < words.length - 1 ? ' ' : ''),
          style: TextStyle(
            color: isSuspicious ? getRiskColor() : Colors.white70,
            backgroundColor: isSuspicious
                ? getRiskColor().withOpacity(0.2)
                : Colors.transparent,
            fontWeight:
                isSuspicious ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
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
                ),
                child: SafeArea(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield, color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Analysis Result',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_isLoading)
                  _buildLoadingState()
                else
                  Column(
                    children: [
                      _buildRiskScoreCard(),
                      SizedBox(height: 20),
                      _buildMessageAnalysis(),
                      SizedBox(height: 20),
                      _buildDetectedIssues(),
                      SizedBox(height: 32),
                      _buildActionButton(),
                    ],
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading state ──────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Column(
      children: [
        SizedBox(height: 80),
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.orange, AppColors.softOrange],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withOpacity(0.35),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        SizedBox(height: 24),
        Text(
          'Analyzing message...',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Scanning for scam indicators',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  // ── Risk score card ────────────────────────────────────────────────────

  Widget _buildRiskScoreCard() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: getRiskColor().withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: getRiskColor().withOpacity(0.15),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Score circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: getRiskColor().withOpacity(0.15),
                    border:
                        Border.all(color: getRiskColor(), width: 2.5),
                  ),
                  child: Center(
                    child: Text(
                      '$score%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: getRiskColor(),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getRiskEmoji() + '  ' + getRiskLabel(),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        level,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // ML badge
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'ML',
                        style: TextStyle(
                          color: AppColors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$nbProbability%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 8,
                color: Colors.white12,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor:
                          _progressAnimation.value * (score / 100),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              getRiskColor(),
                              getRiskColor().withOpacity(0.6)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message analysis card ──────────────────────────────────────────────

  Widget _buildMessageAnalysis() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.message_outlined,
                    color: AppColors.orange, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Message Analysis',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.orange.withOpacity(0.15)),
            ),
            child: RichText(
              text: highlightText(widget.message),
            ),
          ),
        ],
      ),
    );
  }

  // ── Detected issues card ───────────────────────────────────────────────

  Widget _buildDetectedIssues() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: getRiskColor().withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: getRiskColor().withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: getRiskColor(), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Detected Issues',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: getRiskColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${reasons.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (reasons.isEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Color(0xFF10B981), size: 22),
                  SizedBox(width: 12),
                  Text(
                    'No suspicious patterns detected',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: reasons
                  .map(
                    (reason) => Container(
                      margin: EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: getRiskColor().withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: getRiskColor().withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.priority_high,
                              color: getRiskColor(), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ── Action button ──────────────────────────────────────────────────────

  Widget _buildActionButton() {
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
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Analyze Another',
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
  }
}
