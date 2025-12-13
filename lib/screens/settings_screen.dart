import 'package:flutter/material.dart';
import '../main.dart';
import '../data/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDarkMode = themeProvider?.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF7DB2FF),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    '설정',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            // 설정 목록
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 앱 설정 섹션
                  _buildSectionTitle('앱 설정'),
                  const SizedBox(height: 12),

                  // 다크 모드
                  _buildSettingTile(
                    icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    title: '다크 모드',
                    trailing: Switch(
                      value: isDarkMode,
                      onChanged: (_) => themeProvider?.toggleTheme(),
                      activeTrackColor: const Color(0xFF7DB2FF),
                      activeThumbColor: Colors.white,
                    ),
                  ),

                  // 알림 설정
                  _buildSettingTile(
                    icon: Icons.notifications_outlined,
                    title: '알림',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                      activeTrackColor: const Color(0xFF7DB2FF),
                      activeThumbColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 일반 섹션
                  _buildSectionTitle('일반'),
                  const SizedBox(height: 12),

                  // 캐시 삭제
                  _buildSettingTile(
                    icon: Icons.cleaning_services_outlined,
                    title: '캐시 삭제',
                    onTap: _clearCache,
                  ),

                  const SizedBox(height: 24),

                  // 정보 섹션
                  _buildSectionTitle('정보'),
                  const SizedBox(height: 12),

                  // 앱 버전
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: '앱 버전',
                    subtitle: '1.0.0',
                  ),

                  // 이용약관
                  _buildSettingTile(
                    icon: Icons.description_outlined,
                    title: '이용약관',
                    onTap: () {
                      // TODO: 이용약관 페이지로 이동
                    },
                  ),

                  // 개인정보 처리방침
                  _buildSettingTile(
                    icon: Icons.privacy_tip_outlined,
                    title: '개인정보 처리방침',
                    onTap: () {
                      // TODO: 개인정보 처리방침 페이지로 이동
                    },
                  ),

                  const SizedBox(height: 24),

                  // 계정 섹션
                  _buildSectionTitle('계정'),
                  const SizedBox(height: 12),

                  // 로그아웃
                  _buildSettingTile(
                    icon: Icons.logout,
                    title: '로그아웃',
                    titleColor: Colors.orange,
                    onTap: _logout,
                  ),

                  // 회원 탈퇴
                  _buildSettingTile(
                    icon: Icons.delete_forever_outlined,
                    title: '회원 탈퇴',
                    titleColor: Colors.red,
                    onTap: _showDeleteAccountDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F0FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF7DB2FF), size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: titleColor ?? Colors.black87,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              )
            : null,
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: Colors.grey) : null),
        onTap: onTap,
      ),
    );
  }

  Future<void> _clearCache() async {
    await CacheManager.clearAllCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('캐시가 삭제되었습니다.')),
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('회원 탈퇴'),
          ],
        ),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n\n모든 데이터가 삭제되며 복구할 수 없습니다.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: 실제 탈퇴 API 호출
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('회원 탈퇴 기능은 준비 중입니다.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
  }
}
