import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/api_service.dart';
import '../core/widgets.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = true;

  // ▶ 서버에서 불러와야 할 실제 내 프로필 정보
  String name = 'John Smith';
  String userId = '25030024';
  String photoUrl =
      'https://images.unsplash.com/photo-1603415526960-f7e0328d13a2?w=256&h=256&fit=crop';

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    try {
      final data = await ProfileService.getProfile();
      if (mounted) {
        setState(() {
          name = data['name']?.toString() ?? 'User';
          userId = data['user_id']?.toString() ?? '';
          photoUrl = data['photo_url']?.toString() ??
              'https://images.unsplash.com/photo-1603415526960-f7e0328d13a2?w=256&h=256&fit=crop';
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _logout() async {
    // 로그아웃 확인 모달 표시
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
              backgroundColor: const Color(0xFF7DB2FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AuthService.logout();
    } catch (e) {
      debugPrint('Error during logout: $e');
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FD);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? const Color(0xFFE5E5E5) : Colors.black;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : Colors.black54;
    final menuBgColor = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0ECFF);

    if (loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: const CommonBottomNav(currentItem: NavItem.profile),
      body: SafeArea(
        child: Column(
          children: [
            // ─────────── 뒤로가기 버튼 포함 헤더 ───────────
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
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),

                  const Spacer(),

                  const Text(
                    '프로필',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  ),

                  const Spacer(),

                  // 오른쪽 더미 아이콘 (정렬용)
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

            // ─────────── 프로필 카드 ───────────
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Column(
                    children: [
                      CircleAvatar(radius: 48, backgroundImage: NetworkImage(photoUrl)),
                      const SizedBox(height: 12),
                      Text(name,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ID: $userId',
                              style: TextStyle(color: subTextColor)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: userId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('친구 코드가 복사되었습니다'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.copy,
                              size: 16,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      _menuTile(
                        icon: Icons.person_outline_rounded,
                        label: '프로필 수정',
                        onTap: () {
                          Navigator.pushNamed(context, '/profile_edit', arguments: {
                            'name': name,
                            'userId': userId,
                            'photoUrl': photoUrl,
                          });
                        },
                        bgColor: menuBgColor,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 12),
                      _menuTile(
                        icon: Icons.settings_outlined,
                        label: '설정',
                        onTap: () {
                          Navigator.pushNamed(context, '/settings');
                        },
                        bgColor: menuBgColor,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 12),
                      _buildDarkModeToggle(menuBgColor, textColor),
                      const SizedBox(height: 12),
                      _menuTile(
                        icon: Icons.logout_rounded,
                        label: '로그아웃',
                        onTap: _logout,
                        bgColor: menuBgColor,
                        textColor: textColor,
                      ),
                      const SizedBox(height: 40), // 하단 여백 추가
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle(Color bgColor, Color textColor) {
    final themeProvider = ThemeProvider.of(context);
    final isDarkMode = themeProvider?.themeMode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF7DB2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '다크 모드',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const Spacer(),
          Switch(
            value: isDarkMode,
            onChanged: (_) => themeProvider?.toggleTheme(),
            activeTrackColor: const Color(0xFF7DB2FF),
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
    Color bgColor = const Color(0xFFE0ECFF),
    Color textColor = Colors.black,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF7DB2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: danger ? const Color(0xFFE53935) : textColor,
                )),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: textColor.withAlpha(100)),
          ],
        ),
      ),
    );
  }
}
