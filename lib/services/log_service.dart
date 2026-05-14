import 'package:flutter/foundation.dart';

class LogService extends ChangeNotifier {
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void log(String message) {
    _entries.add(LogEntry(message: message, time: DateTime.now()));
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

class LogEntry {
  final String message;
  final DateTime time;
  LogEntry({required this.message, required this.time});

  String get timeStr {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
