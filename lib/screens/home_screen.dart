import 'package:flutter/material.dart';
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

/// 홈 화면: 카테고리 그리드 (실제 메모복붙 앱과 동일 구조)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isEditMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메모복붙'),
        actions: [
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
            icon: Icon(_isEditMode ? Icons.check : Icons.edit_outlined),
            onPressed: () => setState(() => _isEditMode = !_isEditMode),
            tooltip: _isEditMode ? '완료' : '편집',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = provider.categories;

          return CustomScrollView(
            slivers: [
              // 상단 요약
              SliverToBoxAdapter(
                child: _buildSummaryHeader(provider),
              ),
              // 카테고리 그리드
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
                      // 마지막은 "추가" 카드
                      if (index == categories.length) {
                        return _buildAddCategoryCard(context);
                      }
                      final category = categories[index];
                      final count = provider.categoryCounts[category.id] ?? 0;
                      return CategoryCard(
                        category: category,
                        snippetCount: count,
                        isEditMode: _isEditMode,
                        onTap: () {
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
    final totalCopies = provider.allSnippets.fold<int>(0, (sum, s) => sum + s.copyCount);

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
            icon: Icons.copy,
            label: '총 복사',
            value: '$totalCopies',
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
