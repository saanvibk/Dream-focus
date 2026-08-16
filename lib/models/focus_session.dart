class FocusSession {
  final String id;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final int focusedSeconds;
  final int coinsEarned;
  final bool completed;

  const FocusSession({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.focusedSeconds,
    required this.coinsEarned,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'focusedSeconds': focusedSeconds,
    'coinsEarned': coinsEarned,
    'completed': completed,
  };

  static FocusSession? fromJson(Map<String, dynamic> json) {
    try {
      final date = DateTime.parse(json['date'] as String).toLocal();
      final start = DateTime.parse(json['startTime'] as String).toLocal();
      final end = DateTime.parse(json['endTime'] as String).toLocal();
      final seconds = json['focusedSeconds'] as num;
      final coins = json['coinsEarned'] as num;
      return FocusSession(
        id: json['id'] as String,
        date: date,
        startTime: start,
        endTime: end,
        focusedSeconds: seconds.toInt(),
        coinsEarned: coins.toInt(),
        completed: json['completed'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
