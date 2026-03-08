import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 복사 시 변수 치환 다이얼로그 (메모복붙 핵심 UX)
/// 예: "안녕하세요, {{고객이름}}님" → 고객이름 입력 후 복사
Future<Map<String, String>?> showVariableInputDialog(
  BuildContext context,
  List<String> variables, {
  String? snippetContent,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => _VariableInputDialog(
      variables: variables,
      snippetContent: snippetContent,
    ),
  );
}

class _VariableInputDialog extends StatefulWidget {
  final List<String> variables;
  final String? snippetContent;

  const _VariableInputDialog({required this.variables, this.snippetContent});

  @override
  State<_VariableInputDialog> createState() => _VariableInputDialogState();
}

class _VariableInputDialogState extends State<_VariableInputDialog> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {for (final v in widget.variables) v: TextEditingController()};
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_fix_high, size: 18, color: AppTheme.secondaryColor),
          ),
          const SizedBox(width: 10),
          const Text('변수 입력', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.snippetContent != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.snippetContent!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              '복사 시 아래 변수가 치환됩니다',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            ...widget.variables.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _controllers[v],
                    autofocus: widget.variables.indexOf(v) == 0,
                    decoration: InputDecoration(
                      labelText: v,
                      hintText: '$v 입력...',
                      prefixIcon: const Icon(Icons.edit, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (_) {
                      // 마지막 변수면 복사 실행
                      if (v == widget.variables.last) _submit();
                    },
                  ),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('복사'),
        ),
      ],
    );
  }

  void _submit() {
    final values = <String, String>{};
    for (final entry in _controllers.entries) {
      values[entry.key] = entry.value.text;
    }
    Navigator.pop(context, values);
  }
}
