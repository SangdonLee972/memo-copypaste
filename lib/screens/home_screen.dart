import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/category.dart' as cat;
import '../utils/app_theme.dart';
import 'category_detail_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'clipboard_history_screen.dart';
import '../widgets/category_card.dart';
import '../widgets/add_category_dialog.dart';

/// 홈 화면: 카테고리 그리드
/// - 탭: 카테고리 진입
/// - 꾹 누르기: iOS 홈화면처럼 흔들리며 드래그로 순서변경
/// - 수정 버튼: 탭하면 카테고리 편집
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeMode { normal, reorder, edit }

class _HomeScreenState extends State<HomeScreen> {
  _HomeMode _mode = _HomeMode.normal;
  int? _dragFromIndex;
  int? _dragOverIndex;

  void _exitMode() {
    if (_mode != _HomeMode.normal) {
      setState(() => _mode = _HomeMode.normal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReorder = _mode == _HomeMode.reorder;
    final isEdit = _mode == _HomeMode.edit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('메모복붙'),
        actions: [
          if (isReorder)
            TextButton(
              onPressed: _exitMode,
              child: const Text('완료', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            )
          else if (isEdit)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _exitMode,
              tooltip: '완료',
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: '클립보드 히스토리',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClipboardHistoryScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _mode = _HomeMode.edit),
              tooltip: '수정',
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = provider.categories;
          final screenWidth = MediaQuery.of(context).size.width;
          final cardWidth = (screenWidth - 16 * 2 - 12) / 2;
          final cardHeight = cardWidth / 1.5;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSummaryHeader(provider),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // 마지막: 추가 카드 (reorder 모드에서는 숨김)
                      if (index == categories.length) {
                        if (isReorder) return const SizedBox.shrink();
                        return _buildAddCategoryCard(context);
                      }

                      final category = categories[index];
                      final count = provider.categoryCounts[category.id] ?? 0;

                      // 수정 모드
                      if (isEdit) {
                        return CategoryCard(
                          category: category,
                          snippetCount: count,
                          isEditMode: true,
                          onTap: () => _showEditCategoryDialog(context, category),
                          onEdit: () => _showEditCategoryDialog(context, category),
                          onDelete: () => _confirmDelete(context, category),
                        );
                      }

                      // 일반 + reorder 모드: LongPressDraggable 항상 감싸기
                      final isDragging = _dragFromIndex == index;

                      return LongPressDraggable<int>(
                        data: index,
                        delay: const Duration(milliseconds: 150),
                        hapticFeedbackOnStart: true,
                        onDragStarted: () {
                          if (_mode != _HomeMode.reorder) {
                            HapticFeedback.heavyImpact();
                          }
                          setState(() {
                            _mode = _HomeMode.reorder;
                            _dragFromIndex = index;
                          });
                        },
                        onDragEnd: (_) {
                          setState(() {
                            _dragFromIndex = null;
                            _dragOverIndex = null;
                          });
                        },
                        onDraggableCanceled: (_, offset) {
                          setState(() {
                            _dragFromIndex = null;
                            _dragOverIndex = null;
                          });
                        },
                        feedback: Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1.08,
                            child: SizedBox(
                              width: cardWidth,
                              height: cardHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: CategoryCard(
                                  category: category,
                                  snippetCount: count,
                                  onTap: null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.25,
                          child: CategoryCard(
                            category: category,
                            snippetCount: count,
                            onTap: null,
                          ),
                        ),
                        child: DragTarget<int>(
                          onWillAcceptWithDetails: (details) {
                            if (_dragOverIndex != index) {
                              setState(() => _dragOverIndex = index);
                              HapticFeedback.selectionClick();
                            }
                            return true;
                          },
                          onLeave: (_) {
                            if (_dragOverIndex == index) {
                              setState(() => _dragOverIndex = null);
                            }
                          },
                          onAcceptWithDetails: (details) {
                            final fromIndex = details.data;
                            if (fromIndex != index) {
                              HapticFeedback.mediumImpact();
                              final item = provider.categories.removeAt(fromIndex);
                              provider.categories.insert(index, item);
                              provider.notifyAndSaveCategoryOrder();
                            }
                            setState(() {
                              _dragFromIndex = null;
                              _dragOverIndex = null;
                            });
                          },
                          builder: (context, candidateData, rejectedData) {
                            Widget card = CategoryCard(
                              category: category,
                              snippetCount: count,
                              onTap: isReorder
                                  ? null
                                  : () {
                                      provider.loadSnippetsForCategory(category.id);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CategoryDetailScreen(category: category),
                                        ),
                                      );
                                    },
                            );

                            // reorder 모드: jiggle + 삭제 뱃지
                            if (isReorder && !isDragging) {
                              card = _JiggleWrapper(
                                index: index,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    card,
                                    Positioned(
                                      top: -6,
                                      left: -6,
                                      child: GestureDetector(
                                        onTap: () => _confirmDelete(context, category),
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
                              );
                            }

                            // 드래그가 위에 올라왔을 때 축소 효과
                            final isOver = _dragOverIndex == index && _dragFromIndex != index;
                            return AnimatedScale(
                              scale: isOver ? 0.88 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: AnimatedOpacity(
                                opacity: isOver ? 0.6 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: card,
                              ),
                            );
                          },
                        ),
                      );
                    },
                    childCount: categories.length + 1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(AppProvider provider) {
    final totalSnippets = provider.allSnippets.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          _SummaryChip(
            icon: Icons.sticky_note_2,
            label: '전체 스니펫',
            value: '$totalSnippets',
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          _SummaryChip(
            icon: Icons.category,
            label: '카테고리',
            value: '${provider.categories.length}',
            color: AppTheme.copyGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildAddCategoryCard(BuildContext context) {
    return GestureDetector(
      onTap: () => showAddCategoryDialog(context),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 32, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(
              '카테고리 추가',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, cat.Category category) {
    showAddCategoryDialog(context, existing: category);
  }

  void _confirmDelete(BuildContext context, cat.Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text('"${category.name}" 카테고리와 포함된 모든 스니펫이 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AppProvider>().deleteCategory(category.id);
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

  const _JiggleWrapper({required this.child, required this.index});

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
    final baseAngle = 0.015 + random.nextDouble() * 0.012;
    final delay = Duration(milliseconds: random.nextInt(150));

    _controller = AnimationController(
      duration: Duration(milliseconds: 100 + random.nextInt(80)),
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

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
