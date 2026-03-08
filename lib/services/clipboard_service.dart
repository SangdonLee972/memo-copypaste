import 'package:uuid/uuid.dart';
import 'database_service.dart';

/// 클립보드 히스토리 아이템 모델
class ClipboardItem {
  final String id;
  final String text;
  final DateTime copiedAt;
  final String? sourceSnippetId;

  ClipboardItem({
    String? id,
    required this.text,
    DateTime? copiedAt,
    this.sourceSnippetId,
  })  : id = id ?? const Uuid().v4(),
        copiedAt = copiedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'sourceSnippetId': sourceSnippetId,
      'copiedAt': copiedAt.toIso8601String(),
    };
  }

  factory ClipboardItem.fromMap(Map<String, dynamic> map) {
    return ClipboardItem(
      id: map['id'] as String,
      text: map['text'] as String,
      sourceSnippetId: map['sourceSnippetId'] as String?,
      copiedAt: DateTime.parse(map['copiedAt'] as String),
    );
  }
}

/// 클립보드 히스토리 서비스
class ClipboardService {
  final DatabaseService _db = DatabaseService();

  Future<void> addToHistory(String text, {String? sourceSnippetId}) async {
    final item = ClipboardItem(
      text: text,
      sourceSnippetId: sourceSnippetId,
    );
    await _db.insertClipboardItem(item);
  }

  Future<List<ClipboardItem>> getHistory() async {
    return await _db.getClipboardHistory();
  }

  Future<void> clearHistory() async {
    await _db.clearClipboardHistory();
  }

  Future<void> deleteHistoryItem(String id) async {
    await _db.deleteClipboardItem(id);
  }
}
