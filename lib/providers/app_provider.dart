import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/snippet.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/clipboard_service.dart';
import '../services/sync_service.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final SyncService _sync = SyncService();

  final ClipboardService _clipboardService = ClipboardService();

  List<Category> _categories = [];
  List<Snippet> _snippets = [];
  List<Snippet> _allSnippets = [];
  List<String> _allTags = [];
  Map<String, int> _categoryCounts = {};
  List<ClipboardItem> _clipboardHistory = [];

  String? _currentCategoryId;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isSearchMode = false;

  // Getters
  List<Category> get categories => _categories;
  List<Snippet> get snippets => _snippets;
  List<Snippet> get allSnippets => _allSnippets;
  List<String> get allTags => _allTags;
  Map<String, int> get categoryCounts => _categoryCounts;
  List<ClipboardItem> get clipboardHistory => _clipboardHistory;
  String? get currentCategoryId => _currentCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isSearchMode => _isSearchMode;

  Category? get currentCategory {
    if (_currentCategoryId == null) return null;
    return _categories.where((c) => c.id == _currentCategoryId).firstOrNull;
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await loadCategories();
    await loadAllSnippets();
    await _loadCategoryCounts();
    await loadTags();
    _isLoading = false;
    notifyListeners();
    // 앱 시작 시 클라우드에서 다운로드 (로그인 상태일 때)
    _syncFromCloud();
  }

  /// 클라우드 자동 동기화 (백그라운드, 실패해도 무시)
  void _syncToCloud() {
    if (!_sync.isSignedIn) return;
    _sync.uploadAll().then((_) => _sync.updateSyncTimestamp()).catchError((_) {});
  }

  /// 클라우드에서 다운로드 후 로컬 갱신
  void _syncFromCloud() {
    if (!_sync.isSignedIn) return;
    _sync.downloadAll().then((_) async {
      await loadCategories();
      await loadAllSnippets();
      await _loadCategoryCounts();
      await loadTags();
    }).catchError((_) {});
  }

  // ===== Categories =====

  Future<void> loadCategories() async {
    _categories = await _db.getAllCategories();
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    // 새 카테고리는 맨 뒤에 추가 (최대 sortOrder + 1)
    final maxSort = _categories.isEmpty
        ? 0
        : _categories.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final newCategory = Category(
      id: category.id,
      name: category.name,
      parentId: category.parentId,
      colorValue: category.colorValue,
      iconCodePoint: category.iconCodePoint,
      sortOrder: maxSort,
      createdAt: category.createdAt,
    );
    await _db.insertCategory(newCategory);
    await loadCategories();
    await _loadCategoryCounts();
    _syncToCloud();
  }

  Future<void> updateCategory(Category category) async {
    await _db.updateCategory(category);
    await loadCategories();
    _syncToCloud();
  }

  Future<void> deleteCategory(String id) async {
    await _db.deleteCategory(id);
    if (_currentCategoryId == id) _currentCategoryId = null;
    await loadCategories();
    await loadAllSnippets();
    await _loadCategoryCounts();
    _syncToCloud();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    notifyListeners();
    await _db.updateCategoryOrder(_categories);
  }

  /// 외부에서 categories 리스트를 직접 수정한 후 호출
  Future<void> notifyAndSaveCategoryOrder() async {
    notifyListeners();
    await _db.updateCategoryOrder(_categories);
    _syncToCloud();
  }

  // ===== Snippets =====

  Future<void> loadAllSnippets() async {
    _allSnippets = await _db.getAllSnippets();
    notifyListeners();
  }

  Future<void> loadSnippetsForCategory(String categoryId) async {
    _currentCategoryId = categoryId;
    _isSearchMode = false;
    _searchQuery = '';
    _snippets = await _db.getSnippets(categoryId: categoryId);
    notifyListeners();
  }

  Future<void> addSnippet(Snippet snippet) async {
    await _db.insertSnippet(snippet);
    if (_currentCategoryId != null) {
      _snippets = await _db.getSnippets(categoryId: _currentCategoryId);
    }
    await loadAllSnippets();
    await _loadCategoryCounts();
    await loadTags();
    notifyListeners();
    _syncToCloud();
  }

  Future<void> updateSnippet(Snippet snippet) async {
    await _db.updateSnippet(snippet.copyWith(updatedAt: DateTime.now()));
    if (_currentCategoryId != null) {
      _snippets = await _db.getSnippets(categoryId: _currentCategoryId);
    }
    await loadAllSnippets();
    await loadTags();
    notifyListeners();
    _syncToCloud();
  }

  Future<void> deleteSnippet(String id) async {
    await _db.deleteSnippet(id);
    if (_currentCategoryId != null) {
      _snippets = await _db.getSnippets(categoryId: _currentCategoryId);
    }
    await loadAllSnippets();
    await _loadCategoryCounts();
    await loadTags();
    notifyListeners();
    _syncToCloud();
  }

  /// 핵심 기능: 스니펫 복사 (변수 치환 포함)
  Future<String> copySnippet(Snippet snippet, {Map<String, String>? variables}) async {
    String text;
    if (snippet.hasVariables && variables != null) {
      text = snippet.renderContent(variables);
    } else if (snippet.hasVariables && !snippet.hasUserVariables) {
      // 내장 변수만 있는 경우 자동 치환
      text = snippet.renderContent({});
    } else {
      text = snippet.content;
    }

    await Clipboard.setData(ClipboardData(text: text));

    // 클립보드 히스토리에 저장
    await addClipboardHistory(text, snippet.id);

    // 복사 횟수만 증가 (updatedAt은 변경하지 않아 순서 유지)
    final updated = snippet.copyWith(copyCount: snippet.copyCount + 1, updatedAt: snippet.updatedAt);
    await _db.updateSnippet(updated);

    // 리스트 갱신
    if (_currentCategoryId != null) {
      _snippets = await _db.getSnippets(categoryId: _currentCategoryId);
    }
    await loadAllSnippets();
    notifyListeners();

    return text;
  }

  Future<void> togglePin(Snippet snippet) async {
    await updateSnippet(snippet.copyWith(isPinned: !snippet.isPinned));
  }

  Future<void> reorderSnippets(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _snippets.removeAt(oldIndex);
    _snippets.insert(newIndex, item);
    notifyListeners();
    await _db.updateSnippetOrder(_snippets);
    _syncToCloud();
  }

  Future<void> moveSnippetToCategory(String snippetId, String categoryId) async {
    final snippet = _allSnippets.where((s) => s.id == snippetId).firstOrNull;
    if (snippet != null) {
      await updateSnippet(snippet.copyWith(categoryId: categoryId));
      await _loadCategoryCounts();
    }
  }

  // ===== Search =====

  void enterSearchMode() {
    _isSearchMode = true;
    _searchQuery = '';
    _snippets = _allSnippets;
    notifyListeners();
  }

  void exitSearchMode() {
    _isSearchMode = false;
    _searchQuery = '';
    if (_currentCategoryId != null) {
      loadSnippetsForCategory(_currentCategoryId!);
    }
    notifyListeners();
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.isEmpty) {
      _snippets = _allSnippets;
    } else {
      _snippets = await _db.searchSnippets(query);
    }
    notifyListeners();
  }

  // ===== Clipboard History =====

  Future<void> loadClipboardHistory() async {
    _clipboardHistory = await _clipboardService.getHistory();
    notifyListeners();
  }

  Future<void> addClipboardHistory(String text, String? sourceSnippetId) async {
    await _clipboardService.addToHistory(text, sourceSnippetId: sourceSnippetId);
    await loadClipboardHistory();
  }

  Future<void> clearClipboardHistory() async {
    await _clipboardService.clearHistory();
    _clipboardHistory = [];
    notifyListeners();
  }

  Future<void> deleteClipboardHistoryItem(String id) async {
    await _clipboardService.deleteHistoryItem(id);
    await loadClipboardHistory();
  }

  // ===== Tags =====

  Future<void> loadTags() async {
    _allTags = await _db.getAllTags();
    notifyListeners();
  }

  // ===== Private =====

  Future<void> _loadCategoryCounts() async {
    final counts = <String, int>{};
    for (final cat in _categories) {
      counts[cat.id] = await _db.getSnippetCountInCategory(cat.id);
    }
    _categoryCounts = counts;
    notifyListeners();
  }
}
