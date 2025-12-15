import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _saveNotificationSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FD);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? const Color(0xFFE5E5E5) : Colors.black87;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : Colors.grey;

    return Scaffold(
      backgroundColor: bgColor,
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
                  _buildSectionTitle('앱 설정', subTextColor),
                  const SizedBox(height: 12),

                  // 알림 설정
                  _buildSettingTile(
                    icon: Icons.notifications_outlined,
                    title: '알림',
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (val) => _saveNotificationSetting(val),
                      activeTrackColor: const Color(0xFF7DB2FF),
                      activeThumbColor: Colors.white,
                    ),
                    cardColor: cardColor,
                    textColor: textColor,
                  ),

                  const SizedBox(height: 24),

                  // 일반 섹션
                  _buildSectionTitle('일반', subTextColor),
                  const SizedBox(height: 12),

                  // 캐시 삭제
                  _buildSettingTile(
                    icon: Icons.cleaning_services_outlined,
                    title: '캐시 삭제',
                    onTap: _clearCache,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),

                  const SizedBox(height: 24),

                  // 정보 섹션
                  _buildSectionTitle('정보', subTextColor),
                  const SizedBox(height: 12),

                  // 앱 버전
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: '앱 버전',
                    subtitle: '1.0.0',
                    cardColor: cardColor,
                    textColor: textColor,
                  ),

                  // 이용약관
                  _buildSettingTile(
                    icon: Icons.description_outlined,
                    title: '이용약관',
                    onTap: () => Navigator.pushNamed(context, '/terms'),
                    cardColor: cardColor,
                    textColor: textColor,
                  ),

                  // 개인정보 처리방침
                  _buildSettingTile(
                    icon: Icons.privacy_tip_outlined,
                    title: '개인정보 처리방침',
                    onTap: () => Navigator.pushNamed(context, '/privacy'),
                    cardColor: cardColor,
                    textColor: textColor,
                  ),

                  const SizedBox(height: 24),

                  // 계정 섹션
                  _buildSectionTitle('계정', subTextColor),
                  const SizedBox(height: 12),

                  // 회원 탈퇴
                  _buildSettingTile(
                    icon: Icons.delete_forever_outlined,
                    title: '회원 탈퇴',
                    titleColor: Colors.red,
                    onTap: _showDeleteAccountDialog,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
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
    Color cardColor = Colors.white,
    Color textColor = Colors.black87,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBgColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE7F0FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
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
            color: iconBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF7DB2FF), size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: titleColor ?? textColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFB0B0B0) : Colors.grey),
              )
            : null,
        trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: isDark ? const Color(0xFFB0B0B0) : Colors.grey) : null),
        onTap: onTap,
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Color(0xFF7DB2FF)),
            SizedBox(width: 8),
            Text('캐시 삭제'),
          ],
        ),
        content: const Text(
          '캐시된 데이터를 삭제하시겠습니까?\n\n로컬에 저장된 임시 데이터가 삭제됩니다.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await CacheManager.clearAllCache();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('캐시가 삭제되었습니다.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7DB2FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
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
