import 'package:flutter/material.dart';
import '../services/analyzer.dart';
import '../services/ai_service.dart';

class ResultScreen extends StatefulWidget {
  final String message;

  const ResultScreen({super.key, required this.message});

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int score = 0;
  String level = "";
  List<String> reasons = [];
  String aiResponse = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  void _analyze() async {
    // Get pattern analysis
    final result = await Analyzer.analyze(widget.message);
    
    setState(() {
      score = result['score'];
      level = result['level'];
      reasons = List<String>.from(result['reasons']);
      _isLoading = false;
    });

    // Get AI analysis (fire and forget)
    try {
      final aiResult = await AIService.analyzeMessage(widget.message);
      if (mounted) {
        setState(() {
          aiResponse = aiResult;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          aiResponse = "AI analysis unavailable";
        });
      }
    }
  }

  Color getRiskColor() {
    if (score >= 70) return Colors.red;
    if (score >= 40) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: Color(0xFF0F0F1E),
        title: Text(
          'Analysis Report',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Risk Score Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          getRiskColor().withOpacity(0.8),
                          getRiskColor().withOpacity(0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$score%',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          level,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Message Analysis
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          widget.message,
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Issues
                  if (reasons.isNotEmpty) ...[
                    Text(
                      'Detected Issues:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...reasons.map((reason) => Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: getRiskColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: getRiskColor()),
                          SizedBox(width: 8),
                          Expanded(child: Text(reason, style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    )),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('No suspicious patterns detected', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                  
                  if (aiResponse.isNotEmpty) ...[
                    SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Analysis:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(aiResponse, style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                  
                  Spacer(),
                  
                  // Action Button
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context),
                        child: Center(
                          child: Text(
                            'Analyze Another',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
