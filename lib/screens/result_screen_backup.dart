import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/analyzer.dart';
import '../services/ai_service.dart';

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
  String aiResponse = "";
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
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );

    analyzeMessage();
    getAIAnalysis();
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
      _isLoading = false;
    });
  }

  void getAIAnalysis() async {
    try {
      final result = await AIService.analyzeMessage(widget.message);

      if (mounted) {
        setState(() {
          aiResponse = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          aiResponse =
              "AI analysis temporarily unavailable. Pattern-based analysis complete.";
        });
      }
    }
  }

  Color getRiskColor() {
    if (score >= 70) return Color(0xFFEF4444);
    if (score >= 40) return Color(0xFFF59E0B);
    return Color(0xFF10B981);
  }

  Color getRiskGradientStart() {
    if (score >= 70) return Color(0xFFDC2626);
    if (score >= 40) return Color(0xFFD97706);
    return Color(0xFF059669);
  }

  Color getRiskGradientEnd() {
    if (score >= 70) return Color(0xFF991B1B);
    if (score >= 40) return Color(0xFF92400E);
    return Color(0xFF047857);
  }

  String getRiskEmoji() {
    if (score >= 70) return "🚨";
    if (score >= 40) return "⚠️";
    return "✅";
  }

  TextSpan highlightText(String text) {
    List<TextSpan> spans = [];
    List<String> words = text.split(" ");

    for (int i = 0; i < words.length; i++) {
      String word = words[i];
      bool isSuspicious = reasons.any(
        (r) => r.toLowerCase().contains(word.toLowerCase()),
      );

      spans.add(
        TextSpan(
          text: word + (i < words.length - 1 ? " " : ""),
          style: TextStyle(
            color: isSuspicious ? getRiskColor() : Colors.white,
            fontWeight: isSuspicious ? FontWeight.bold : FontWeight.normal,
            backgroundColor: isSuspicious
                ? getRiskColor().withOpacity(0.2)
                : null,
          ),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F1E),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Color(0xFF0F0F1E),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Analysis Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                titlePadding: EdgeInsets.only(left: 20, bottom: 16),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E)],
                    ),
                  ),
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading)
                    _buildLoadingState()
                  else
                    Column(
                      children: [
                        _buildRiskScoreCard(),
                        SizedBox(height: 24),
                        _buildMessageAnalysis(),
                        SizedBox(height: 24),
                        _buildDetectedIssues(),
                        SizedBox(height: 24),
                        if (aiResponse.isNotEmpty) _buildAIAnalysis(),
                        SizedBox(height: 40),
                        _buildActionButtons(),
                      ],
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        SizedBox(height: 100),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(60),
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
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Checking for suspicious patterns',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRiskScoreCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [getRiskGradientStart(), getRiskGradientEnd()],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: getRiskColor().withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(getRiskEmoji(), style: TextStyle(fontSize: 32)),
                SizedBox(width: 16),
                Text(
                  '$score%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              level,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressAnimation.value * (score / 100),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    )
  }

  Widget _buildMessageAnalysis() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.message,
                    color: Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Message Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF0F0F1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFF6366F1).withOpacity(0.3)),
              ),
              child: RichText(text: highlightText(widget.message)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedIssues() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: getRiskColor().withOpacity(0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: getRiskColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.warning, color: getRiskColor(), size: 24),
                ),
                SizedBox(width: 16),
                Text(
                  'Detected Issues',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: getRiskColor(),
                    borderRadius: BorderRadius.circular(12),
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
            SizedBox(height: 20),
            if (reasons.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'No suspicious patterns detected',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...reasons.map(
                (reason) => Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: getRiskColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: getRiskColor().withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.priority_high,
                        color: getRiskColor(),
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAnalysis() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF8B5CF6).withOpacity(0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: Color(0xFF8B5CF6),
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'AI Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'GEMINI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF0F0F1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(0xFF8B5CF6).withOpacity(0.3)),
              ),
              child: Text(
                aiResponse,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFF6366F1).withOpacity(0.3)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // Share functionality
                    },
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share, color: Color(0xFF6366F1), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Share',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
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
            ),
          ],
        ),
      ],
    );
  }
}
