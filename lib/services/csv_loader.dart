import 'package:flutter/services.dart';
import 'database_helper.dart';

/// English stop-words to exclude from NB vocabulary (very frequent, non-discriminating words)
const _stopWords = {
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
  'back', 'join', 'team', 'i\'m', 'im', 'don\'t', 'cant', 'it\'s',
  'there', 'here', 'like', 'know', 'want', 'time', 'need', 'going',
  're', 've', 'll', 'us', 'him', 'her', 'own', 'over', 'under', 'again',
};

class CsvLoader {
  static bool _loaded = false;

  static Future<void> loadDatasets() async {
    if (_loaded) return;
    try {
      // Clear previously stored patterns and NB data
      await DatabaseHelper.instance.clearPatterns();
      await DatabaseHelper.instance.clearNBData();

      await _loadScamPatterns();
      await _loadUserReports();
      await _trainNaiveBayesFromSpamHam();

      _loaded = true;
      print('✅ Datasets loaded & NB model trained successfully');
    } catch (e) {
      print('❌ Error loading datasets: $e');
    }
  }

  // ─── 1. Curated Scam Patterns (rules-based high-confidence patterns) ───

  static Future<void> _loadScamPatterns() async {
    final String csvData = await rootBundle.loadString(
      'assets/datasets/scam_patterns.csv',
    );
    final List<String> lines = csvData.split('\n');

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // CSV parsing that handles quoted fields with commas inside them
      final List<String> parts = _parseCsvLine(line);
      if (parts.length >= 4) {
        final String statement = parts[0].replaceAll('"', '').trim();
        final String category = parts[1].trim();
        final int riskScore = int.tryParse(parts[2].trim()) ?? 0;
        final String keywords = parts[3].replaceAll('"', '').trim();

        await DatabaseHelper.instance.insertScamPattern({
          'statement': statement,
          'category': category,
          'risk_score': riskScore,
          'keywords': keywords,
          'source': 'scam_patterns',
        });
      }
    }
    print('✅ Scam patterns loaded');
  }

  // ─── 2. User Reports (community-verified scam reports) ──────────────────

  static Future<void> _loadUserReports() async {
    final String csvData = await rootBundle.loadString(
      'assets/datasets/user_reports.csv',
    );
    final List<String> lines = csvData.split('\n');

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final List<String> parts = _parseCsvLine(line);
      if (parts.length >= 4) {
        final String statement = parts[0].replaceAll('"', '').trim();
        final String category = parts[1].trim();
        final int verifiedCount = int.tryParse(parts[2].trim()) ?? 0;
        final String riskLevel = parts[3].trim();

        int riskScore;
        switch (riskLevel.toLowerCase()) {
          case 'high':
            riskScore = 85;
            break;
          case 'medium':
            riskScore = 55;
            break;
          default:
            riskScore = 25;
        }

        // Community-verified scams get a small boost
        if (verifiedCount > 500) riskScore = (riskScore + 10).clamp(0, 100);
        else if (verifiedCount > 100) riskScore = (riskScore + 5).clamp(0, 100);

        await DatabaseHelper.instance.insertScamPattern({
          'statement': statement,
          'category': category,
          'risk_score': riskScore,
          'keywords': statement.toLowerCase(),
          'verified_count': verifiedCount,
          'risk_level': riskLevel,
          'source': 'user_reports',
        });
      }
    }
    print('✅ User reports loaded');
  }

  // ─── 3. Naive Bayes Training from spam_ham_india.csv ────────────────────
  //
  // Instead of inserting per-word rows into scam_patterns (which caused chaos),
  // we build a proper NB word-frequency table. During classification, P(spam|msg)
  // is computed using Laplace-smoothed log-probabilities.

  static Future<void> _trainNaiveBayesFromSpamHam() async {
    final String csvData = await rootBundle.loadString(
      'assets/datasets/spam_ham_india.csv',
    );
    final List<String> lines = csvData.split('\n');

    int spamDocs = 0;
    int hamDocs = 0;

    // Use batch DB operations for performance
    final db = await DatabaseHelper.instance.database;

    // Process messages in batches
    const int batchSize = 50;
    List<Map<String, dynamic>> wordBatch = [];

    // Collect all word frequencies in memory first, then bulk insert
    Map<String, List<int>> wordFreqMap = {}; // word -> [spamCount, hamCount]

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Handle quoted messages (message has commas inside quotes)
      String message;
      String label;

      final parts = _parseCsvLine(line);
      if (parts.length < 2) continue;

      message = parts[0].replaceAll('"', '').trim();
      label = parts[1].trim().toLowerCase().replaceAll('\r', '');

      if (label != 'spam' && label != 'ham') continue;

      final bool isSpam = (label == 'spam');
      if (isSpam) spamDocs++; else hamDocs++;

      // Tokenise the message
      final List<String> tokens = _tokenize(message);
      // Remove stop words and short tokens
      final List<String> filteredTokens = tokens
          .where((t) => t.length >= 3 && !_stopWords.contains(t))
          .toList();

      for (final token in filteredTokens) {
        if (!wordFreqMap.containsKey(token)) {
          wordFreqMap[token] = [0, 0];
        }
        if (isSpam) {
          wordFreqMap[token]![0]++;
        } else {
          wordFreqMap[token]![1]++;
        }
      }
    }

    // Filter vocabulary: only keep words that appear at least 2 times total
    // This removes noise from very rare words
    final filteredVocab = wordFreqMap.entries
        .where((e) => (e.value[0] + e.value[1]) >= 2)
        .toList();

    // Bulk insert into DB
    final batch = db.batch();
    for (final entry in filteredVocab) {
      batch.rawInsert('''
        INSERT INTO nb_word_freq (word, spam_count, ham_count)
        VALUES (?, ?, ?)
        ON CONFLICT(word) DO UPDATE SET
          spam_count = spam_count + excluded.spam_count,
          ham_count  = ham_count  + excluded.ham_count
      ''', [entry.key, entry.value[0], entry.value[1]]);
    }
    await batch.commit(noResult: true);

    // Store document totals
    await db.rawUpdate('''
      UPDATE nb_totals SET doc_count = doc_count + ?, word_count = word_count + ?
      WHERE label = 'spam'
    ''', [spamDocs, filteredVocab.fold<int>(0, (sum, e) => sum + e.value[0])]);

    await db.rawUpdate('''
      UPDATE nb_totals SET doc_count = doc_count + ?, word_count = word_count + ?
      WHERE label = 'ham'
    ''', [hamDocs, filteredVocab.fold<int>(0, (sum, e) => sum + e.value[1])]);

    print('✅ NB model trained: $spamDocs spam + $hamDocs ham docs, '
        '${filteredVocab.length} vocabulary words');
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Simple CSV parser that handles quoted fields containing commas
  static List<String> _parseCsvLine(String line) {
    List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }
}
