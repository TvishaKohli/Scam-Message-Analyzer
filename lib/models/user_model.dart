class User {
  final int? id;
  final String email;
  final String password;
  final String name;
  final DateTime createdAt;

  User({
    this.id,
    required this.email,
    required this.password,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      email: map['email'],
      password: map['password'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class ScanHistory {
  final int? id;
  final int userId;
  final String message;
  final int score;
  final String level;
  final List<String> reasons;
  final DateTime createdAt;

  ScanHistory({
    this.id,
    required this.userId,
    required this.message,
    required this.score,
    required this.level,
    required this.reasons,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'message': message,
      'score': score,
      'level': level,
      'reasons': reasons.join(','), // Store as comma-separated string
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScanHistory.fromMap(Map<String, dynamic> map) {
    return ScanHistory(
      id: map['id'],
      userId: map['user_id'],
      message: map['message'],
      score: map['score'],
      level: map['level'],
      reasons: map['reasons']?.toString().split(',') ?? [], // Split back to list
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
