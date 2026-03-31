import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:reorderables/reorderables.dart';
import '../providers/app_provider.dart';
import '../models/category.dart' as cat;
import '../utils/app_theme.dart';
import 'category_detail_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'clipboard_history_screen.dart';
import '../widgets/category_card.dart';
import '../widgets/add_category_dialog.dart';

enum _HomeMode { normal, reorder, edit }

/// 홈 화면: 카테고리 그리드
/// - 일반 모드: 탭하면 카테고리 진입
/// - 길게 누르기: 순서변경 모드 (드래그로 위치 이동)
/// - 수정 버튼: 수정 모드 (탭하면 카테고리 편집)
/// - 빈 공간 탭: 모드 해제
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeMode _mode = _HomeMode.normal;

  void _exitMode() {
    if (_mode != _HomeMode.normal) {
      setState(() => _mode = _HomeMode.normal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메모복붙'),
        actions: [
          if (_mode == _HomeMode.normal) ...[
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
          ] else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _exitMode,
              tooltip: '완료',
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _exitMode,
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final categories = provider.categories;

            if (_mode == _HomeMode.reorder) {
              return _buildReorderMode(provider, categories);
            }

            return _buildNormalOrEditMode(provider, categories);
          },
        ),
      ),
    );
  }

  /// 순서변경 모드: ReorderableWrap으로 드래그 이동
  Widget _buildReorderMode(AppProvider provider, List<cat.Category> categories) {
    final width = (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2;
    final height = width / 1.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        children: [
          _buildSummaryHeader(provider),
          const SizedBox(height: 8),
          ReorderableWrap(
            spacing: 12,
            runSpacing: 12,
            onReorder: (oldIndex, newIndex) {
              provider.reorderCategories(oldIndex, newIndex);
            },
            children: categories.map((category) {
              final count = provider.categoryCounts[category.id] ?? 0;
              return SizedBox(
                key: ValueKey(category.id),
                width: width,
                height: height,
                child: CategoryCard(
                  category: category,
                  snippetCount: count,
                  isEditMode: false,
                  onTap: () {},
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 일반 모드 & 수정 모드
  Widget _buildNormalOrEditMode(AppProvider provider, List<cat.Category> categories) {
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
                if (index == categories.length) {
                  return _buildAddCategoryCard(context);
                }
                final category = categories[index];
                final count = provider.categoryCounts[category.id] ?? 0;
                return GestureDetector(
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _mode = _HomeMode.reorder);
                  },
                  child: CategoryCard(
                    category: category,
                    snippetCount: count,
                    isEditMode: _mode == _HomeMode.edit,
                    onTap: _mode == _HomeMode.edit
                        ? () => _showEditCategoryDialog(context, category)
                        : () {
                            provider.loadSnippetsForCategory(category.id);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CategoryDetailScreen(category: category),
                              ),
                            );
                          },
                    onEdit: () => _showEditCategoryDialog(context, category),
                    onDelete: () => _confirmDelete(context, category),
                  ),
                );
              },
              childCount: categories.length + 1,
            ),
          ),
        ),
      ],
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
