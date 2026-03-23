import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/snippet.dart';
import '../models/category.dart';
import 'clipboard_service.dart';

class DatabaseService {
  static Database? _database;
  static const _dbSharingChannel = MethodChannel('com.copynote.memo_copypaste/db_sharing');

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// iOS: App Group 경로에 DB를 직접 저장하여 키보드 확장과 공유
  Future<String> _getDBPath() async {
    if (Platform.isIOS) {
      try {
        final groupPath = await _dbSharingChannel.invokeMethod<String>('getDBPath');
        if (groupPath != null && groupPath.isNotEmpty) {
          return groupPath;
        }
      } catch (_) {}
    }
    // 기본 경로 (Android 또는 iOS fallback)
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'memo_copypaste.db');
  }

  /// iOS 위젯/키보드 확장이 DB에 접근할 수 있도록 App Group 컨테이너에 DB 복사
  Future<void> _syncToAppGroup() async {
    // App Group 경로에 직접 저장하므로 별도 복사 불필요
  }

  Future<Database> _initDB() async {
    final path = await _getDBPath();

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE snippets (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL DEFAULT '',
            content TEXT NOT NULL DEFAULT '',
            categoryId TEXT NOT NULL DEFAULT '',
            tags TEXT DEFAULT '',
            type INTEGER DEFAULT 0,
            filePath TEXT,
            isPinned INTEGER DEFAULT 0,
            sortOrder INTEGER DEFAULT 0,
            copyCount INTEGER DEFAULT 0,
            variables TEXT DEFAULT '',
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parentId TEXT,
            colorValue INTEGER DEFAULT 4288585945,
            iconCodePoint INTEGER DEFAULT 58055,
            sortOrder INTEGER DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');

        // 기본 카테고리 생성
        final now = DateTime.now().toIso8601String();
        await db.insert('categories', {
          'id': 'default_general',
          'name': '일반 메모',
          'colorValue': 0xFF4A90D9,
          'iconCodePoint': 0xea09,
          'sortOrder': 0,
          'createdAt': now,
        });
        await db.insert('categories', {
          'id': 'default_account',
          'name': '계좌번호',
          'colorValue': 0xFF51CF66,
          'iconCodePoint': 0xe0b0,
          'sortOrder': 1,
          'createdAt': now,
        });
        await db.insert('categories', {
          'id': 'default_address',
          'name': '주소',
          'colorValue': 0xFFFF922B,
          'iconCodePoint': 0xe55f,
          'sortOrder': 2,
          'createdAt': now,
        });
        await db.insert('categories', {
          'id': 'default_email',
          'name': '이메일 템플릿',
          'colorValue': 0xFF7B61FF,
          'iconCodePoint': 0xe158,
          'sortOrder': 3,
          'createdAt': now,
        });

        await db.execute('''
          CREATE TABLE clipboard_history (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            sourceSnippetId TEXT,
            copiedAt TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE clipboard_history (
              id TEXT PRIMARY KEY,
              text TEXT NOT NULL,
              sourceSnippetId TEXT,
              copiedAt TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // ===== Snippets =====

  Future<List<Snippet>> getSnippets({String? categoryId}) async {
    final db = await database;
    final maps = await db.query(
      'snippets',
      where: categoryId != null ? 'categoryId = ?' : null,
      whereArgs: categoryId != null ? [categoryId] : null,
      orderBy: 'isPinned DESC, sortOrder ASC, updatedAt DESC',
    );
    return maps.map((m) => Snippet.fromMap(m)).toList();
  }

  Future<List<Snippet>> getAllSnippets() async {
    final db = await database;
    final maps = await db.query('snippets', orderBy: 'isPinned DESC, updatedAt DESC');
    return maps.map((m) => Snippet.fromMap(m)).toList();
  }

  Future<List<Snippet>> searchSnippets(String query) async {
    final db = await database;
    final maps = await db.query(
      'snippets',
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
    return maps.map((m) => Snippet.fromMap(m)).toList();
  }

  Future<void> insertSnippet(Snippet snippet) async {
    final db = await database;
    await db.insert('snippets', snippet.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _syncToAppGroup();
  }

  Future<void> updateSnippet(Snippet snippet) async {
    final db = await database;
    await db.update('snippets', snippet.toMap(),
        where: 'id = ?', whereArgs: [snippet.id]);
    await _syncToAppGroup();
  }

  Future<void> deleteSnippet(String id) async {
    final db = await database;
    await db.delete('snippets', where: 'id = ?', whereArgs: [id]);
    await _syncToAppGroup();
  }

  Future<void> updateSnippetOrder(List<Snippet> snippets) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < snippets.length; i++) {
      batch.update(
        'snippets',
        {'sortOrder': i},
        where: 'id = ?',
        whereArgs: [snippets[i].id],
      );
    }
    await batch.commit(noResult: true);
    await _syncToAppGroup();
  }

  // ===== Categories =====

  Future<List<Category>> getCategories({String? parentId}) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: parentId == null ? 'parentId IS NULL' : 'parentId = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'sortOrder ASC, name ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'sortOrder ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<void> insertCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _syncToAppGroup();
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
    await _syncToAppGroup();
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete('snippets', where: 'categoryId = ?', whereArgs: [id]);
    await db.delete('categories', where: 'parentId = ?', whereArgs: [id]);
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await _syncToAppGroup();
  }

  Future<int> getSnippetCountInCategory(String categoryId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM snippets WHERE categoryId = ?',
      [categoryId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> updateCategoryOrder(List<Category> categories) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < categories.length; i++) {
      batch.update(
        'categories',
        {'sortOrder': i},
        where: 'id = ?',
        whereArgs: [categories[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ===== Clipboard History =====

  Future<List<ClipboardItem>> getClipboardHistory() async {
    final db = await database;
    final maps = await db.query('clipboard_history', orderBy: 'copiedAt DESC');
    return maps.map((m) => ClipboardItem.fromMap(m)).toList();
  }

  Future<void> insertClipboardItem(ClipboardItem item) async {
    final db = await database;
    await db.insert('clipboard_history', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteClipboardItem(String id) async {
    final db = await database;
    await db.delete('clipboard_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearClipboardHistory() async {
    final db = await database;
    await db.delete('clipboard_history');
  }

  // ===== Tags =====

  Future<List<String>> getAllTags() async {
    final db = await database;
    final maps = await db.query('snippets', columns: ['tags']);
    final tagSet = <String>{};
    for (final map in maps) {
      final tags = (map['tags'] as String?)?.split(',') ?? [];
      for (final tag in tags) {
        if (tag.trim().isNotEmpty) tagSet.add(tag.trim());
      }
    }
    return tagSet.toList()..sort();
  }
}
