import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

/// 카테고리 (폴더) 모델 - 홈 화면 그리드에 표시
class Category {
  final String id;
  String name;
  String? parentId;
  int colorValue;
  int iconCodePoint;
  int sortOrder;
  DateTime createdAt;

  Category({
    String? id,
    required this.name,
    this.parentId,
    this.colorValue = 0xFF4A90D9,
    this.iconCodePoint = 0xe2c7, // Icons.folder
    this.sortOrder = 0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parentId'] as String?,
      colorValue: map['colorValue'] as int? ?? 0xFF4A90D9,
      iconCodePoint: map['iconCodePoint'] as int? ?? 0xe2c7,
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// 기본 카테고리 색상 팔레트
  static const List<int> colorPalette = [
    0xFF4A90D9, // 파랑
    0xFFFF6B6B, // 빨강
    0xFF51CF66, // 초록
    0xFFFF922B, // 주황
    0xFF7B61FF, // 보라
    0xFFFF6B9D, // 핑크
    0xFF20C997, // 민트
    0xFFFCC419, // 노랑
    0xFF868E96, // 그레이
    0xFF339AF0, // 하늘
    0xFFE64980, // 마젠타
    0xFF5C7CFA, // 인디고
  ];

  /// 기본 아이콘 목록
  static const List<int> iconList = [
    0xe2c7, // folder
    0xea09, // sticky_note_2
    0xe0b0, // credit_card (계좌)
    0xe55f, // location_on (주소)
    0xe158, // email
    0xe86f, // code
    0xe3f4, // image
    0xe415, // picture_as_pdf
    0xe8f9, // star
    0xe87c, // favorite
    0xe8f8, // shopping_cart
    0xe0c9, // link
    0xe80c, // work
    0xe7fd, // school
    0xe53b, // local_hospital
    0xe539, // local_dining
  ];
}
