import 'dart:math';
import 'database_helper.dart';

/// Hybrid scam analyzer combining:
///   1. Rule-based curated pattern matching (high precision, high weight)
///   2. Naive Bayes classification trained on spam_ham_india.csv
///
/// Final score is a weighted blend of both, normalized to 0–100.
class Analyzer {
  static Future<Map<String, dynamic>> analyze(String message) async {
    final String lowerMessage = message.toLowerCase().trim();

    if (lowerMessage.isEmpty) {
      return {
        'score': 0,
        'level': 'Low Risk ✅',
        'reasons': <String>[],
        'categories': <String>[],
        'nb_probability': 0.0,
      };
    }

    // ── 1. Rule-based pattern matching ────────────────────────────────────
    final ruleResult = await _ruleBasedAnalysis(lowerMessage);
    final int ruleScore = ruleResult['score']; // 0–100
    final List<String> reasons = ruleResult['reasons'];
    final Set<String> categories = ruleResult['categories'];

    // ── 2. Naive Bayes classification ─────────────────────────────────────
    final double nbSpamProb = await _naiveBayesSpamProbability(lowerMessage);

    // ── 3. Hybrid scoring ─────────────────────────────────────────────────
    // Rules are more precise; NB adds a statistical base.
    // Weight: 65% rules, 35% NB (rules dominate for known patterns)
    final double ruleWeight = 0.65;
    final double nbWeight = 0.35;

    // Convert NB probability to a 0-100 score
    final double nbScore = nbSpamProb * 100.0;

    double hybridScore = (ruleScore * ruleWeight) + (nbScore * nbWeight);

    // ── 4. Contextual boosters ────────────────────────────────────────────
    // Presence of URLs boosts score (scammers almost always include links)
    if (_containsUrl(lowerMessage)) {
      hybridScore = _boost(hybridScore, 12);
      if (!reasons.contains('Contains suspicious URL or link')) {
        reasons.add('Contains suspicious URL or link');
      }
    }

    // Urgency language boosts score
    final int urgencyMatches = _countUrgencySignals(lowerMessage);
    if (urgencyMatches >= 2) {
      hybridScore = _boost(hybridScore, 8);
      reasons.add('Multiple urgency indicators detected');
    } else if (urgencyMatches == 1) {
      hybridScore = _boost(hybridScore, 4);
    }

    // All-caps or excessive punctuation
    if (_hasExcessiveCaps(message)) {
      hybridScore = _boost(hybridScore, 6);
      reasons.add('Excessive use of CAPS or !!!');
    }

    // OTP request is an immediate strong signal
    if (_asksForOtp(lowerMessage)) {
      hybridScore = _boost(hybridScore, 20);
      if (!reasons.any((r) => r.toLowerCase().contains('otp'))) {
        reasons.add('Asks for OTP — never share your OTP with anyone');
      }
    }

    // Personal info request
    if (_asksForPersonalInfo(lowerMessage)) {
      hybridScore = _boost(hybridScore, 15);
      reasons.add('Requests sensitive personal information');
    }

    // Reward/prize promise
    if (_promisesReward(lowerMessage)) {
      hybridScore = _boost(hybridScore, 10);
      if (!reasons.any((r) => r.toLowerCase().contains('prize') || r.toLowerCase().contains('reward'))) {
        reasons.add('Promises prize, reward or free gifts');
      }
    }

    // ── 5. Ham de-booster ─────────────────────────────────────────────────
    // If NB says it's clearly ham (< 20% spam probability) AND no strong rules fired,
    // apply a moderate de-boost to avoid false positives
    if (nbSpamProb < 0.20 && ruleScore < 30) {
      hybridScore = hybridScore * 0.55;
      if (reasons.isNotEmpty) {
        reasons.insert(0, 'Low statistical spam likelihood');
      }
    } else if (nbSpamProb < 0.35 && ruleScore < 20) {
      hybridScore = hybridScore * 0.7;
    }

    // ── 6. Final normalization to 0–100 ───────────────────────────────────
    final int finalScore = hybridScore.round().clamp(0, 100);

    String level;
    if (finalScore >= 70) {
      level = 'High Risk 🚨';
    } else if (finalScore >= 40) {
      level = 'Medium Risk ⚠️';
    } else {
      level = 'Low Risk ✅';
    }

    return {
      'score': finalScore,
      'level': level,
      'reasons': reasons,
      'categories': categories.toList(),
      'nb_probability': (nbSpamProb * 100).round(),
    };
  }

  // ── Rule-based matching ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _ruleBasedAnalysis(String lowerMsg) async {
    final patterns = await DatabaseHelper.instance.getPatterns();

    double totalScore = 0;
    // Track how many strong patterns matched (each pattern has a weight)
    int patternHits = 0;
    Set<String> matchedCategories = {};
    Set<String> uniqueReasons = {};

    for (var pattern in patterns) {
      bool matched = false;
      final int patternRiskScore = pattern['risk_score'] as int? ?? 0;

      // Multi-keyword matching from the 'keywords' field
      if (pattern['keywords'] != null) {
        final String keywordsField = pattern['keywords'].toString().toLowerCase();
        final List<String> keywordList = keywordsField.split(',');

        for (String keyword in keywordList) {
          keyword = keyword.trim();
          if (keyword.length >= 3 && lowerMsg.contains(keyword)) {
            matched = true;
            // Show the keyword in a user-friendly way
            final String displayKw = keyword[0].toUpperCase() + keyword.substring(1);
            uniqueReasons.add('Contains "$displayKw" — a common scam indicator');
            break; // one reason per pattern is enough
          }
        }
      }

      // Statement matching (whole-phrase match, higher confidence)
      if (!matched && pattern['statement'] != null) {
        final String statement = pattern['statement'].toString().toLowerCase();
        if (statement.length >= 5 && lowerMsg.contains(statement)) {
          matched = true;
          uniqueReasons.add('Matches known scam phrase: "${pattern['statement']}"');
        }
      }

      if (matched) {
        // Normalise the per-pattern score (each pattern may be 0–100).
        // We accumulate weighted scores. Higher-risk patterns contribute more.
        totalScore += patternRiskScore.toDouble();
        patternHits++;

        if (pattern['category'] != null && pattern['category'].toString().isNotEmpty) {
          matchedCategories.add(pattern['category'].toString());
        }
      }
    }

    // Aggregate: average score across matched patterns, then boost for corroboration
    double ruleScore = 0;
    if (patternHits > 0) {
      // Use the MAX pattern score weighted by hit count (not sum, to avoid inflation)
      double avgHitScore = totalScore / patternHits;
      double corroborationBonus = (patternHits - 1) * 5.0;
      ruleScore = (avgHitScore + corroborationBonus).clamp(0, 100);
    }

    // Multiple distinct categories = stronger signal
    if (matchedCategories.length > 1) {
      ruleScore = _boost(ruleScore, (matchedCategories.length - 1) * 8);
      uniqueReasons.add('Multiple scam categories detected: ${matchedCategories.join(', ')}');
    }

    return {
      'score': ruleScore.round().clamp(0, 100),
      'reasons': uniqueReasons.toList(),
      'categories': matchedCategories,
    };
  }

  // ── Naive Bayes ──────────────────────────────────────────────────────────

  static Future<double> _naiveBayesSpamProbability(String message) async {
    try {
      final totals = await DatabaseHelper.instance.getNBTotals();
      final int spamDocs = totals['spam_docs'] ?? 1;
      final int hamDocs  = totals['ham_docs']  ?? 1;
      final int totalDocs = spamDocs + hamDocs;

      if (totalDocs == 0) return 0.5;

      final int vocabSize = await DatabaseHelper.instance.getNBVocabSize();
      if (vocabSize == 0) return 0.5;

      final int totalSpamWords = totals['spam_words'] ?? 1;
      final int totalHamWords  = totals['ham_words']  ?? 1;

      // Prior probabilities
      final double logPriorSpam = log(spamDocs / totalDocs);
      final double logPriorHam  = log(hamDocs  / totalDocs);

      // Tokenize and filter
      final tokens = _tokenize(message)
          .where((t) => t.length >= 3 && !_stopWords.contains(t))
          .toList();

      if (tokens.isEmpty) return 0.5;

      double logLikelihoodSpam = 0.0;
      double logLikelihoodHam  = 0.0;

      // Laplace smoothing: P(word|spam) = (count_spam + 1) / (total_spam_words + vocab)
      for (final token in tokens) {
        final freq = await DatabaseHelper.instance.getNBWordFreq(token);

        final int spamCount = (freq?['spam_count'] as int? ?? 0);
        final int hamCount  = (freq?['ham_count']  as int? ?? 0);

        final double pWordSpam = (spamCount + 1) / (totalSpamWords + vocabSize);
        final double pWordHam  = (hamCount  + 1) / (totalHamWords  + vocabSize);

        logLikelihoodSpam += log(pWordSpam);
        logLikelihoodHam  += log(pWordHam);
      }

      final double logSpam = logPriorSpam + logLikelihoodSpam;
      final double logHam  = logPriorHam  + logLikelihoodHam;

      // Convert log-probs to probability using softmax
      final double maxLog = max(logSpam, logHam);
      final double expSpam = exp(logSpam - maxLog);
      final double expHam  = exp(logHam  - maxLog);
      final double pSpam   = expSpam / (expSpam + expHam);

      return pSpam.clamp(0.0, 1.0);
    } catch (e) {
      print('NB error: $e');
      return 0.5; // uncertain on error
    }
  }

  // ── Signal detectors ──────────────────────────────────────────────────────

  static bool _containsUrl(String msg) {
    return RegExp(r'https?://|bit\.ly|tiny\.cc|tinyurl|goo\.gl|t\.co|'
            r'short(url|\.url)|ow\.ly|[a-z0-9\-]+\.(in|com|co|net|io|app)/\S')
        .hasMatch(msg);
  }

  static int _countUrgencySignals(String msg) {
    const urgencyPhrases = [
      'urgent', 'immediately', 'right now', 'act now', 'last chance',
      'today only', 'expires today', 'expires soon', 'limited time',
      'do not ignore', 'warning', 'alert', 'last warning', 'final notice',
      'do not delay', '24 hours', 'within 24', 'hurry', 'asap',
    ];
    int count = 0;
    for (final phrase in urgencyPhrases) {
      if (msg.contains(phrase)) count++;
    }
    return count;
  }

  static bool _hasExcessiveCaps(String originalMsg) {
    final letters = originalMsg.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (letters.length < 10) return false;
    final capsCount = letters.runes.where((r) => r >= 65 && r <= 90).length;
    final capsRatio = capsCount / letters.length;
    // More than 40% caps is suspicious
    return capsRatio > 0.40 || originalMsg.contains('!!!');
  }

  static bool _asksForOtp(String msg) {
    const otpSignals = [
      'share otp', 'send otp', 'enter otp', 'provide otp',
      'give otp', 'otp required', 'otp needed', 'one time password',
      'verify with otp', 'otp to verify',
    ];
    return otpSignals.any((s) => msg.contains(s));
  }

  static bool _asksForPersonalInfo(String msg) {
    const infoSignals = [
      'share your account', 'share account number', 'bank account number',
      'card number', 'cvv', 'credit card details', 'debit card details',
      'share your password', 'send your password', 'aadhar number',
      'aadhaar number', 'pan card number', 'pan number',
      'share your pan', 'date of birth', 'mother\'s maiden name',
      'security question', 'net banking password', 'atm pin',
      'share pin', 'enter your pin',
    ];
    return infoSignals.any((s) => msg.contains(s));
  }

  static bool _promisesReward(String msg) {
    const rewardSignals = [
      'won a prize', 'you have won', 'you\'ve won', 'claim your prize',
      'claim your reward', 'free gift', 'you are selected', 'lucky winner',
      'congratulations you', 'free iphone', 'free samsung', 'win a car',
      'win iphone', '100% free', 'claim now', 'lottery winner',
      'you have been selected', 'lucky draw',
    ];
    return rewardSignals.any((s) => msg.contains(s));
  }

  static double _boost(double score, double amount) {
    return (score + amount * (1 - score / 100)).clamp(0, 100);
  }

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static const _stopWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'be',
    'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
    'would', 'could', 'should', 'may', 'might', 'shall', 'can', 'not',
    'no', 'nor', 'so', 'yet', 'both', 'either', 'neither', 'each', 'few',
    'more', 'most', 'other', 'some', 'such', 'than', 'too', 'very', 'just',
    'its', 'it', 'i', 'my', 'me', 'we', 'our', 'you', 'your', 'he', 'she',
    'they', 'their', 'this', 'that', 'these', 'those', 'what', 'which',
    'who', 'whom', 'when', 'where', 'why', 'how', 'all', 'any', 'if', 'up',
    'out', 'about', 'into', 'through', 'during', 'before', 'after', 'above',
    'below', 'between', 'same', 'then', 'only', 'also', 'am', 'now', 'hi',
    'ok', 'yes', 'get', 'please', 'thank', 'thanks', 'good', 'okay',
    'back', 'join', 'team', 'don\'t', 'cant', 'it\'s', 'there', 'here',
    'like', 'know', 'want', 'time', 'need', 're', 've', 'll', 'us',
    'him', 'her', 'own', 'over', 'under', 'again', 'im', 'i\'m',
  };
}
