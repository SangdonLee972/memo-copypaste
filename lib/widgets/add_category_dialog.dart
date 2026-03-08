import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

void showAddCategoryDialog(BuildContext context, {Category? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AddCategorySheet(existing: existing),
  );
}

class _AddCategorySheet extends StatefulWidget {
  final Category? existing;
  const _AddCategorySheet({this.existing});

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  late TextEditingController _nameController;
  late int _selectedColor;
  late int _selectedIcon;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor = widget.existing?.colorValue ?? Category.colorPalette[0];
    _selectedIcon = widget.existing?.iconCodePoint ?? Category.iconList[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(_selectedColor).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  IconData(_selectedIcon, fontFamily: 'MaterialIcons'),
                  size: 22,
                  color: Color(_selectedColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _isEdit ? '카테고리 수정' : '새 카테고리',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 이름
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '카테고리 이름',
              hintText: '예: 계좌번호, 이메일 템플릿...',
            ),
          ),
          const SizedBox(height: 20),
          // 색상 선택
          const Text('색상', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: Category.colorPalette.map((color) {
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: Color(color).withValues(alpha: 0.5), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // 아이콘 선택
          const Text('아이콘', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Category.iconList.map((iconCode) {
              final isSelected = _selectedIcon == iconCode;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = iconCode),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Color(_selectedColor).withValues(alpha: 0.15)
                        : AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(color: Color(_selectedColor), width: 2)
                        : null,
                  ),
                  child: Icon(
                    IconData(iconCode, fontFamily: 'MaterialIcons'),
                    size: 20,
                    color: isSelected ? Color(_selectedColor) : AppTheme.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                child: Text(_isEdit ? '수정' : '만들기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final provider = context.read<AppProvider>();

    if (_isEdit) {
      final updated = Category(
        id: widget.existing!.id,
        name: name,
        parentId: widget.existing!.parentId,
        colorValue: _selectedColor,
        iconCodePoint: _selectedIcon,
        sortOrder: widget.existing!.sortOrder,
        createdAt: widget.existing!.createdAt,
      );
      provider.updateCategory(updated);
    } else {
      provider.addCategory(Category(
        name: name,
        colorValue: _selectedColor,
        iconCodePoint: _selectedIcon,
      ));
    }

    Navigator.pop(context);
  }
}
