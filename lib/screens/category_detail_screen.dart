import 'dart:math';
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
/// - 평소: 탭=복사, 스와이프=삭제/고정
/// - 꾹 누르기: iOS 홈화면처럼 흔들리며 드래그로 순서변경 (계속 여러 개 가능)
/// - 완료 버튼으로 모드 해제
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

  void _enterReorderMode() {
    if (_mode != _ScreenMode.reorder) {
      HapticFeedback.heavyImpact();
      setState(() => _mode = _ScreenMode.reorder);
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
            TextButton(
              onPressed: _exitMode,
              child: const Text('완료', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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

          // 순서변경 모드: iOS 홈화면 스타일
          if (_mode == _ScreenMode.reorder) {
            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: snippets.length,
              // 기본 롱프레스 드래그 사용 — 가장 안정적
              buildDefaultDragHandles: true,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final scale = Tween<double>(begin: 1.0, end: 1.05).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                    );
                    return Transform.scale(
                      scale: scale.value,
                      child: Material(
                        color: Colors.transparent,
                        elevation: 12,
                        shadowColor: Colors.black38,
                        borderRadius: BorderRadius.circular(14),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) {
                HapticFeedback.mediumImpact();
                provider.reorderSnippets(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final snippet = snippets[index];
                return _JiggleWrapper(
                  key: ValueKey(snippet.id),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SnippetTile(
                          snippet: snippet,
                          onTap: () {},
                          onCopy: () {},
                        ),
                        // iOS 스타일 삭제 뱃지
                        Positioned(
                          top: -6,
                          left: -6,
                          child: GestureDetector(
                            onTap: () => _confirmDelete(context, provider, snippet),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.remove, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SnippetTile(
                    snippet: snippet,
                    onLongPress: _enterReorderMode,
                    onTap: _mode == _ScreenMode.edit
                        ? () => _editSnippet(context, snippet)
                        : () {},
                    onCopy: () => _handleCopy(context, provider, snippet),
                    onDelete: () => _confirmDelete(context, provider, snippet),
                    onTogglePin: () => provider.togglePin(snippet),
                    showEditIndicator: _mode == _ScreenMode.edit,
                  ),
                );
              },
            ),
          );
        },
      ),
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

/// iOS 홈화면 스타일 흔들림(jiggle) 애니메이션
class _JiggleWrapper extends StatefulWidget {
  final Widget child;
  final int index;

  const _JiggleWrapper({super.key, required this.child, required this.index});

  @override
  State<_JiggleWrapper> createState() => _JiggleWrapperState();
}

class _JiggleWrapperState extends State<_JiggleWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    final random = Random(widget.index);
    final baseAngle = 0.008 + random.nextDouble() * 0.008;
    final delay = Duration(milliseconds: random.nextInt(200));

    _controller = AnimationController(
      duration: Duration(milliseconds: 150 + random.nextInt(100)),
      vsync: this,
    );

    _rotation = Tween<double>(begin: -baseAngle, end: baseAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(delay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotation,
      builder: (context, child) {
        return Transform.rotate(angle: _rotation.value, child: child);
      },
      child: widget.child,
    );
  }
}
