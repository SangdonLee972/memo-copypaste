import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../services/sync_service.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showCopyFeedback = true;
  bool _autoReplaceBuiltIn = true;

  final SyncService _syncService = SyncService();
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLastSyncTime();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showCopyFeedback = prefs.getBool('showCopyFeedback') ?? true;
      _autoReplaceBuiltIn = prefs.getBool('autoReplaceBuiltIn') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _loadLastSyncTime() async {
    try {
      if (_syncService.isSignedIn) {
        final time = await _syncService.getLastSyncTime();
        if (mounted) {
          setState(() => _lastSyncTime = time);
        }
      }
    } catch (_) {
      // Firebase 미설정 시 무시
    }
  }

  Future<void> _performSync() async {
    if (!_syncService.isSignedIn) {
      _showLoginDialog();
      return;
    }

    setState(() => _isSyncing = true);
    try {
      await _syncService.syncAll();
      await _syncService.updateSyncTimestamp();
      await _loadLastSyncTime();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('동기화가 완료되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('동기화 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isSignUp ? '회원가입' : '로그인'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setDialogState(() => isSignUp = !isSignUp),
                child: Text(
                  isSignUp ? '이미 계정이 있으신가요? 로그인' : '계정이 없으신가요? 회원가입',
                  style: const TextStyle(color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () async {
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                if (email.isEmpty || password.isEmpty) return;

                try {
                  if (isSignUp) {
                    await _syncService.signUpWithEmail(email, password);
                  } else {
                    await _syncService.signInWithEmail(email, password);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {});
                    _performSync();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('오류: $e')),
                    );
                  }
                }
              },
              child: Text(isSignUp ? '회원가입' : '로그인'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    await _syncService.signOut();
    setState(() {
      _lastSyncTime = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const _SectionHeader(title: '복사 설정'),
          SwitchListTile(
            title: const Text('복사 피드백'),
            subtitle: const Text('복사 시 확인 메시지를 표시합니다'),
            value: _showCopyFeedback,
            onChanged: (v) {
              setState(() => _showCopyFeedback = v);
              _saveSetting('showCopyFeedback', v);
            },
          ),
          SwitchListTile(
            title: const Text('내장 변수 자동 치환'),
            subtitle: const Text('{{날짜}}, {{시간}}, {{요일}} 자동 치환'),
            value: _autoReplaceBuiltIn,
            onChanged: (v) {
              setState(() => _autoReplaceBuiltIn = v);
              _saveSetting('autoReplaceBuiltIn', v);
            },
          ),
          const Divider(),
          const _SectionHeader(title: '클라우드'),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined, color: AppTheme.primaryColor),
            title: const Text('클라우드 동기화'),
            subtitle: Text(
              _syncService.isSignedIn
                  ? (_lastSyncTime != null
                      ? '마지막 동기화: ${DateFormat('yyyy-MM-dd HH:mm').format(_lastSyncTime!)}'
                      : '로그인됨: ${_syncService.currentUser?.email ?? "익명"}')
                  : '로그인하여 동기화를 시작하세요',
            ),
            trailing: _isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    onPressed: _isSyncing ? null : _performSync,
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('지금 동기화'),
                  ),
                ),
                const SizedBox(width: 8),
                if (_syncService.isSignedIn)
                  OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _handleSignOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('로그아웃'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _showLoginDialog,
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('로그인'),
                  ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader(title: '앱 정보'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('버전'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('이용약관'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('개인정보처리방침'),
            onTap: () {},
          ),
          const Divider(),
          const _SectionHeader(title: '위험'),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('전체 데이터 삭제', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmDeleteAll(context),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 데이터 삭제'),
        content: const Text('모든 카테고리와 스니펫이 삭제됩니다.\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final provider = context.read<AppProvider>();
              final categories = List.from(provider.categories);
              for (final cat in categories) {
                await provider.deleteCategory(cat.id);
              }
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('데이터가 삭제되었습니다')),
                );
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

