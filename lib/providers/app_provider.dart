import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/snippet.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/clipboard_service.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

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
  }

  // ===== Categories =====

  Future<void> loadCategories() async {
    _categories = await _db.getAllCategories();
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    await _db.insertCategory(category);
    await loadCategories();
    await _loadCategoryCounts();
  }

  Future<void> updateCategory(Category category) async {
    await _db.updateCategory(category);
    await loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await _db.deleteCategory(id);
    if (_currentCategoryId == id) _currentCategoryId = null;
    await loadCategories();
    await loadAllSnippets();
    await _loadCategoryCounts();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, item);
    notifyListeners();
    await _db.updateCategoryOrder(_categories);
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
  }

  Future<void> updateSnippet(Snippet snippet) async {
    await _db.updateSnippet(snippet.copyWith(updatedAt: DateTime.now()));
    if (_currentCategoryId != null) {
      _snippets = await _db.getSnippets(categoryId: _currentCategoryId);
    }
    await loadAllSnippets();
    await loadTags();
    notifyListeners();
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

    // 복사 횟수 증가
    final updated = snippet.copyWith(copyCount: snippet.copyCount + 1);
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
