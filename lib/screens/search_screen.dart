import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/snippet_tile.dart';
import '../widgets/variable_input_dialog.dart';
import 'snippet_edit_screen.dart';

/// 전체 검색 화면 (실시간 검색 + 필터링)
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().enterSearchMode();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<AppProvider>().exitSearchMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: '모든 스니펫 검색...',
              border: InputBorder.none,
              fillColor: Colors.transparent,
              filled: true,
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _controller.clear();
                        context.read<AppProvider>().search('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              context.read<AppProvider>().search(value);
              setState(() {});
            },
          ),
        ),
        body: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final snippets = provider.snippets;
            final query = provider.searchQuery;

            if (query.isEmpty) {
              // 최근 스니펫 표시
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      '전체 스니펫 (${snippets.length}개)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snippets.length,
                      itemBuilder: (context, index) {
                        final snippet = snippets[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SnippetTile(
                            snippet: snippet,
                            showCategory: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SnippetEditScreen(snippet: snippet)),
                            ),
                            onCopy: () => _handleCopy(context, provider, snippet),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            if (snippets.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      '"$query"에 대한 검색 결과가 없습니다',
                      style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: snippets.length,
              itemBuilder: (context, index) {
                final snippet = snippets[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SnippetTile(
                    snippet: snippet,
                    showCategory: true,
                    highlightQuery: query,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SnippetEditScreen(snippet: snippet)),
                    ),
                    onCopy: () => _handleCopy(context, provider, snippet),
                  ),
                );
              },
            );
          },
        ),
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
        _showCopied(context);
      }
    } else {
      await provider.copySnippet(snippet);
      if (context.mounted) _showCopied(context);
    }
  }

  void _showCopied(BuildContext context) {
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
      ),
    );
  }
}
