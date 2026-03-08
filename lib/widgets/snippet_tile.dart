import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

/// 스니펫 리스트 타일 - 원탭 복사 버튼 포함
class SnippetTile extends StatelessWidget {
  final Snippet snippet;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;
  final bool showCategory;
  final bool showDragHandle;
  final String? highlightQuery;

  const SnippetTile({
    super.key,
    required this.snippet,
    required this.onTap,
    required this.onCopy,
    this.onDelete,
    this.onTogglePin,
    this.showCategory = false,
    this.showDragHandle = false,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    final Widget tile = Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              if (showDragHandle) ...[
                const Icon(Icons.drag_handle, size: 20, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
              ],
              // 타입 아이콘
              _buildTypeIcon(),
              const SizedBox(width: 12),
              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목 행
                    Row(
                      children: [
                        if (snippet.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin, size: 13, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                          ),
                        if (snippet.hasVariables)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.auto_fix_high, size: 13, color: AppTheme.secondaryColor.withValues(alpha: 0.7)),
                          ),
                        Expanded(
                          child: Text(
                            snippet.title.isNotEmpty ? snippet.title : '제목 없음',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 내용 미리보기
                    Text(
                      snippet.content,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 하단 정보
                    Row(
                      children: [
                        if (showCategory) ...[
                          _buildCategoryBadge(context),
                          const SizedBox(width: 8),
                        ],
                        if (snippet.tags.isNotEmpty)
                          ...snippet.tags.take(2).map((tag) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(fontSize: 11, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                                ),
                              )),
                        const Spacer(),
                        if (snippet.copyCount > 0)
                          Text(
                            '${snippet.copyCount}회 복사',
                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(snippet.updatedAt),
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 원탭 복사 버튼 (핵심 UX)
              _CopyButton(onCopy: onCopy),
            ],
          ),
        ),
      ),
    );

    if (onDelete != null || onTogglePin != null) {
      return Slidable(
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: onDelete != null && onTogglePin != null ? 0.4 : 0.2,
          children: [
            if (onTogglePin != null)
              SlidableAction(
                onPressed: (_) => onTogglePin!(),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                icon: snippet.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: snippet.isPinned ? '해제' : '고정',
                borderRadius: BorderRadius.circular(12),
              ),
            if (onDelete != null)
              SlidableAction(
                onPressed: (_) => onDelete!(),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: '삭제',
                borderRadius: BorderRadius.circular(12),
              ),
          ],
        ),
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildTypeIcon() {
    final typeConfig = {
      SnippetType.text: (Icons.text_snippet, AppTheme.primaryColor),
      SnippetType.account: (Icons.credit_card, const Color(0xFF51CF66)),
      SnippetType.address: (Icons.location_on, const Color(0xFFFF922B)),
      SnippetType.email: (Icons.email, const Color(0xFF7B61FF)),
      SnippetType.code: (Icons.code, const Color(0xFF339AF0)),
      SnippetType.image: (Icons.image, const Color(0xFFFF6B9D)),
      SnippetType.pdf: (Icons.picture_as_pdf, const Color(0xFFE64980)),
    };

    final (icon, color) = typeConfig[snippet.type] ?? (Icons.text_snippet, AppTheme.primaryColor);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildCategoryBadge(BuildContext context) {
    final provider = context.read<AppProvider>();
    final cat = provider.categories.where((c) => c.id == snippet.categoryId).firstOrNull;
    if (cat == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        cat.name,
        style: TextStyle(fontSize: 10, color: cat.color, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M/d').format(date);
  }
}

/// 원탭 복사 버튼 (체크 애니메이션 포함)
class _CopyButton extends StatefulWidget {
  final VoidCallback onCopy;
  const _CopyButton({required this.onCopy});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _copied
          ? AppTheme.copyGreen.withValues(alpha: 0.12)
          : AppTheme.primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          widget.onCopy();
          setState(() => _copied = true);
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) setState(() => _copied = false);
        },
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            _copied ? Icons.check : Icons.copy_rounded,
            size: 19,
            color: _copied ? AppTheme.copyGreen : AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}
