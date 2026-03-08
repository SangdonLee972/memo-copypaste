import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/snippet.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/variable_input_dialog.dart';

/// 스니펫 생성/편집 화면
class SnippetEditScreen extends StatefulWidget {
  final Snippet? snippet;
  final String? categoryId;

  const SnippetEditScreen({super.key, this.snippet, this.categoryId});

  @override
  State<SnippetEditScreen> createState() => _SnippetEditScreenState();
}

class _SnippetEditScreenState extends State<SnippetEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  late List<String> _tags;
  late String _categoryId;
  late SnippetType _type;
  bool _isEdited = false;

  bool get _isNew => widget.snippet == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.snippet?.title ?? '');
    _contentController = TextEditingController(text: widget.snippet?.content ?? '');
    _tagController = TextEditingController();
    _tags = List.from(widget.snippet?.tags ?? []);
    _categoryId = widget.snippet?.categoryId ?? widget.categoryId ?? '';
    _type = widget.snippet?.type ?? SnippetType.text;

    _titleController.addListener(_markEdited);
    _contentController.addListener(_markEdited);
  }

  void _markEdited() {
    setState(() => _isEdited = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isEdited,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final save = await _showSaveDialog();
          if (save == true) await _save();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? '새 스니펫' : '스니펫 편집'),
          actions: [
            if (!_isNew) ...[
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyContent(),
                tooltip: '복사',
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => SharePlus.instance.share(ShareParams(text: _contentController.text)),
                tooltip: '공유',
              ),
            ],
            TextButton(
              onPressed: _save,
              child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타입 선택
              _buildTypeSelector(),
              const SizedBox(height: 16),
              // 카테고리 선택
              _buildCategorySelector(),
              const SizedBox(height: 16),
              // 제목
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: '제목 (선택사항)',
                  border: InputBorder.none,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const Divider(height: 24),
              // 내용 (변수 안내)
              _buildVariableGuide(),
              const SizedBox(height: 8),
              // 내용 입력
              TextField(
                controller: _contentController,
                style: const TextStyle(fontSize: 16, height: 1.7),
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요...\n\n변수 사용: {{고객이름}}, {{날짜}} 등\n복사 시 자동으로 치환됩니다.',
                  border: InputBorder.none,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
                minLines: 10,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 16),
              // 태그
              _buildTagSection(),
              const SizedBox(height: 16),
              // 미리보기 (변수가 있는 경우)
              if (_contentController.text.contains('{{'))
                _buildPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      (SnippetType.text, Icons.text_snippet, '일반'),
      (SnippetType.account, Icons.credit_card, '계좌'),
      (SnippetType.address, Icons.location_on, '주소'),
      (SnippetType.email, Icons.email, '이메일'),
      (SnippetType.code, Icons.code, '코드'),
    ];

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: types.map((t) {
          final isSelected = _type == t.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.$2, size: 15, color: isSelected ? Colors.white : AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(t.$3),
                ],
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              onSelected: (_) => setState(() {
                _type = t.$1;
                _isEdited = true;
              }),
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final provider = context.read<AppProvider>();
    final categories = provider.categories;
    final current = categories.where((c) => c.id == _categoryId).firstOrNull;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('카테고리 선택', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                ...categories.map((cat) => ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(cat.icon, size: 18, color: cat.color),
                      ),
                      title: Text(cat.name),
                      selected: cat.id == _categoryId,
                      onTap: () {
                        setState(() {
                          _categoryId = cat.id;
                          _isEdited = true;
                        });
                        Navigator.pop(ctx);
                      },
                    )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: current?.color.withValues(alpha: 0.08) ?? AppTheme.bgLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (current != null) Icon(current.icon, size: 18, color: current.color),
            const SizedBox(width: 8),
            Text(
              current?.name ?? '카테고리 선택',
              style: TextStyle(
                color: current != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildVariableGuide() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high, size: 16, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '{{변수명}} 복사 시 치환 | {{날짜}} {{시간}} {{요일}} {{#카운터}} 자동',
              style: TextStyle(fontSize: 12, color: AppTheme.primaryColor.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final content = _contentController.text;
    final vars = Snippet(content: content).getUserVariables();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.copyGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.copyGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview, size: 16, color: AppTheme.copyGreen.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                '미리보기 (내장 변수 치환)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.copyGreen.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Snippet(content: content).renderContent(
              {for (final v in vars) v: '[$v]'},
            ),
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSection() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ..._tags.map((tag) => Chip(
              label: Text('#$tag', style: const TextStyle(fontSize: 12)),
              onDeleted: () {
                setState(() {
                  _tags.remove(tag);
                  _isEdited = true;
                });
              },
              visualDensity: VisualDensity.compact,
            )),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _tagController,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: '태그 추가...',
              border: InputBorder.none,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            onSubmitted: (tag) {
              tag = tag.trim();
              if (tag.isNotEmpty && !_tags.contains(tag)) {
                setState(() {
                  _tags.add(tag);
                  _tagController.clear();
                  _isEdited = true;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력하세요')),
      );
      return;
    }

    if (_categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택하세요')),
      );
      return;
    }

    final snippet = Snippet(
      id: widget.snippet?.id,
      title: title.isNotEmpty ? title : (content.length > 30 ? '${content.substring(0, 30)}...' : content),
      content: content,
      categoryId: _categoryId,
      tags: _tags,
      type: _type,
      isPinned: widget.snippet?.isPinned ?? false,
      sortOrder: widget.snippet?.sortOrder ?? 0,
      copyCount: widget.snippet?.copyCount ?? 0,
      createdAt: widget.snippet?.createdAt,
    );

    if (_isNew) {
      await provider.addSnippet(snippet);
    } else {
      await provider.updateSnippet(snippet);
    }

    _isEdited = false;
    if (mounted) Navigator.pop(context);
  }

  Future<bool?> _showSaveDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장하시겠습니까?'),
        content: const Text('변경사항이 있습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('저장 안함')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
        ],
      ),
    );
  }

  Future<void> _copyContent() async {
    final snippet = Snippet(content: _contentController.text);
    String text;
    if (snippet.hasVariables && snippet.hasUserVariables) {
      final variables = await showVariableInputDialog(
        context,
        snippet.getUserVariables(),
        snippetContent: snippet.content,
      );
      if (variables == null) return;
      text = snippet.renderContent(variables);
    } else {
      text = snippet.renderContent({});
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('클립보드에 복사됨'),
          backgroundColor: AppTheme.copyGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }
  }
}
