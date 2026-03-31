import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/snippet.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/snippet_tile.dart';
import '../widgets/variable_input_dialog.dart';
import 'snippet_edit_screen.dart';

/// 카테고리 상세: 해당 카테고리의 스니펫 목록
/// - 일반 모드: 복사만 가능
/// - 길게 누르기: 순서변경 모드 (드래그로 위치 이동)
/// - 수정 버튼: 수정 모드 (스니펫 탭 → 편집)
/// - 빈 공간 탭: 모드 해제
class CategoryDetailScreen extends StatefulWidget {
  final Category category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

enum _ScreenMode { normal, reorder, edit }

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  _ScreenMode _mode = _ScreenMode.normal;

  void _exitMode() {
    if (_mode != _ScreenMode.normal) {
      setState(() => _mode = _ScreenMode.normal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: widget.category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(widget.category.icon, size: 16, color: widget.category.color),
            ),
            const SizedBox(width: 10),
            Text(widget.category.name),
          ],
        ),
        actions: [
          if (_mode == _ScreenMode.reorder)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _exitMode,
              tooltip: '완료',
            )
          else if (_mode == _ScreenMode.edit)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _exitMode,
              tooltip: '완료',
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _mode = _ScreenMode.edit),
              tooltip: '수정',
            ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final snippets = provider.snippets;

          if (snippets.isEmpty) {
            return _buildEmptyState(context);
          }

          // 순서변경 모드: ReorderableListView
          if (_mode == _ScreenMode.reorder) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _exitMode,
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: snippets.length,
                buildDefaultDragHandles: false,
                onReorder: (oldIndex, newIndex) {
                  provider.reorderSnippets(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final snippet = snippets[index];
                  return ReorderableDragStartListener(
                    key: ValueKey(snippet.id),
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SnippetTile(
                        snippet: snippet,
                        showDragHandle: true,
                        onTap: () {},
                        onCopy: () {},
                      ),
                    ),
                  );
                },
              ),
            );
          }

          // 일반 모드 & 수정 모드
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _exitMode,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: snippets.length,
              itemBuilder: (context, index) {
                final snippet = snippets[index];
                return GestureDetector(
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _mode = _ScreenMode.reorder);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SnippetTile(
                      snippet: snippet,
                      onTap: _mode == _ScreenMode.edit
                          ? () => _editSnippet(context, snippet)
                          : () {},
                      onCopy: () => _handleCopy(context, provider, snippet),
                      onDelete: () => _confirmDelete(context, provider, snippet),
                      onTogglePin: () => provider.togglePin(snippet),
                      showEditIndicator: _mode == _ScreenMode.edit,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      // 순서변경 모드에서는 FAB 숨김
      floatingActionButton: _mode == _ScreenMode.reorder
          ? null
          : FloatingActionButton(
              onPressed: () => _createSnippet(context),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.category.icon,
            size: 64,
            color: widget.category.color.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '스니펫이 없습니다',
            style: TextStyle(fontSize: 17, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 6),
          Text(
            '자주 사용하는 문구를 추가해보세요',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _createSnippet(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('스니펫 추가'),
          ),
        ],
      ),
    );
  }

  void _createSnippet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SnippetEditScreen(categoryId: widget.category.id),
      ),
    );
  }

  void _editSnippet(BuildContext context, Snippet snippet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SnippetEditScreen(snippet: snippet),
      ),
    );
  }

  /// 핵심 UX: 복사 시 변수 치환
  Future<void> _handleCopy(BuildContext context, AppProvider provider, Snippet snippet) async {
    if (snippet.hasUserVariables) {
      final variables = await showVariableInputDialog(
        context,
        snippet.getUserVariables(),
        snippetContent: snippet.content,
      );
      if (variables != null && context.mounted) {
        await provider.copySnippet(snippet, variables: variables);
        _showCopiedFeedback(context);
      }
    } else {
      await provider.copySnippet(snippet);
      if (context.mounted) _showCopiedFeedback(context);
    }
  }

  void _showCopiedFeedback(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('클립보드에 복사됨'),
          ],
        ),
        backgroundColor: AppTheme.copyGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider, Snippet snippet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('스니펫 삭제'),
        content: Text('"${snippet.title.isNotEmpty ? snippet.title : '제목 없음'}" 스니펫을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteSnippet(snippet.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
