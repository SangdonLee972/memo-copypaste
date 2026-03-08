import 'package:uuid/uuid.dart';

/// 스니펫 타입 (메모복붙 실제 앱 기준)
enum SnippetType {
  text,       // 일반 메모
  account,    // 계좌번호
  address,    // 주소
  email,      // 이메일 템플릿
  code,       // 코드 블록
  image,      // 이미지
  pdf,        // PDF
}

/// 핵심 데이터 모델: 스니펫 (메모)
class Snippet {
  final String id;
  String title;
  String content;
  String categoryId;
  List<String> tags;
  SnippetType type;
  String? filePath;
  bool isPinned;
  int sortOrder;
  int copyCount;
  /// 동적 변수 목록 - 복사 시 치환할 변수들
  /// 예: ["고객이름", "회사명"]
  List<String> variables;
  DateTime createdAt;
  DateTime updatedAt;

  Snippet({
    String? id,
    this.title = '',
    this.content = '',
    this.categoryId = '',
    List<String>? tags,
    this.type = SnippetType.text,
    this.filePath,
    this.isPinned = false,
    this.sortOrder = 0,
    this.copyCount = 0,
    List<String>? variables,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        variables = variables ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// content에서 {{변수명}} 패턴을 자동 추출
  List<String> extractVariables() {
    final regex = RegExp(r'\{\{(.+?)\}\}');
    return regex
        .allMatches(content)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
  }

  /// 변수를 치환한 최종 텍스트 반환
  String renderContent(Map<String, String> values) {
    var result = content;
    // 내장 변수
    final now = DateTime.now();
    result = result.replaceAll('{{날짜}}',
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    result = result.replaceAll('{{시간}}',
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
    result = result.replaceAll('{{요일}}',
        ['월', '화', '수', '목', '금', '토', '일'][now.weekday - 1]);
    // 카운터 변수 (복사 횟수 기반)
    result = result.replaceAll('{{#카운터}}', '${copyCount + 1}');
    // 사용자 정의 변수
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  /// 복사 시 사용자 입력이 필요한 변수 목록 (내장 변수 제외)
  List<String> getUserVariables() {
    final builtIn = {'날짜', '시간', '요일', '#카운터'};
    return extractVariables().where((v) => !builtIn.contains(v)).toList();
  }

  bool get hasVariables => extractVariables().isNotEmpty;
  bool get hasUserVariables => getUserVariables().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'tags': tags.join(','),
      'type': type.index,
      'filePath': filePath,
      'isPinned': isPinned ? 1 : 0,
      'sortOrder': sortOrder,
      'copyCount': copyCount,
      'variables': variables.join(','),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Snippet.fromMap(Map<String, dynamic> map) {
    return Snippet(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      tags: (map['tags'] as String?)?.isNotEmpty == true
          ? (map['tags'] as String).split(',')
          : [],
      type: SnippetType.values[map['type'] as int? ?? 0],
      filePath: map['filePath'] as String?,
      isPinned: (map['isPinned'] as int? ?? 0) == 1,
      sortOrder: map['sortOrder'] as int? ?? 0,
      copyCount: map['copyCount'] as int? ?? 0,
      variables: (map['variables'] as String?)?.isNotEmpty == true
          ? (map['variables'] as String).split(',')
          : [],
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Snippet copyWith({
    String? title,
    String? content,
    String? categoryId,
    List<String>? tags,
    SnippetType? type,
    String? filePath,
    bool? isPinned,
    int? sortOrder,
    int? copyCount,
    List<String>? variables,
    DateTime? updatedAt,
  }) {
    return Snippet(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? List.from(this.tags),
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      copyCount: copyCount ?? this.copyCount,
      variables: variables ?? List.from(this.variables),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
