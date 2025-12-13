import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/api_service.dart';
import '../core/widgets.dart';

const _blue = Color(0xFF7DB2FF);
const _blueLight = Color(0xFFE7F0FF);
const _ink = Color(0xFF0E3E3E);

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _codeCtrl = TextEditingController();

  bool _loading = true;
  bool _adding = false;
  List<FriendSummary> _friends = [];
  String? _myFriendCode;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadMyFriendCode();
  }

  Future<void> _loadMyFriendCode() async {
    try {
      final profile = await ProfileService.getProfile();
      if (mounted) {
        setState(() {
          _myFriendCode = profile['friend_code']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading friend code: $e');
    }
  }

  void _copyFriendCode() {
    if (_myFriendCode != null) {
      Clipboard.setData(ClipboardData(text: _myFriendCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구 코드가 복사되었습니다!')),
      );
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);

    try {
      final data = await FriendsService.getFriends();
      if (mounted) {
        setState(() {
          _friends = data.map((item) => FriendSummary(
            id: item['id']?.toString() ?? '',
            name: item['name']?.toString() ?? '',
            todayRate: item['todayRate'] ?? 0,
            avatarUrl: item['avatarUrl']?.toString(),
          )).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) {
        setState(() {
          _friends = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _addByCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() => _adding = true);

    try {
      await FriendsService.addFriend(code: code);
      if (!mounted) return;

      _codeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구가 추가되었습니다!')),
      );
      await _loadFriends();
    } catch (e) {
      debugPrint('Error adding friend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('친구 추가 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _openDetail(FriendSummary f) {
    Navigator.pushNamed(
      context,
      '/friend_detail',
      arguments: FriendDetailArgs(friendId: f.id, name: f.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FD);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? const Color(0xFFE5E5E5) : _ink;
    final blueLightColor = isDark ? const Color(0xFF1E3A5F) : _blueLight;

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: const CommonBottomNav(currentItem: NavItem.friends),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFriends, // ← 새로고침 시 GET 호출
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const SizedBox(height: 8),

              // 파란색 헤더
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: const BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '친구',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, '/notifications'),
                      icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 내 친구 코드 박스
              if (_myFriendCode != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _blue, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, color: _blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('내 친구 코드', style: TextStyle(color: textColor, fontSize: 12)),
                            Text(
                              _myFriendCode!,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _copyFriendCode,
                        icon: const Icon(Icons.copy, color: _blue),
                        tooltip: '복사',
                      ),
                    ],
                  ),
                ),

              // 친구 추가 박스
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: blueLightColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('친구 추가', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl,
                            decoration: InputDecoration(
                              hintText: '친구 코드 입력',
                              filled: true,
                              fillColor: cardColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: _adding ? null : _addByCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _adding
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Text('추가', style: TextStyle(color: Colors.white)),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 친구 목록 박스
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('친구 목록',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 8),

                    // 로딩 상태
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(28.0),
                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                      )

                    // 친구 없음
                    else if (_friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(28.0),
                        child: Text('등록된 친구가 없습니다.',
                            style: TextStyle(color: Colors.white70)),
                      )

                    // 친구 목록
                    else
                      ..._friends.map((f) => _FriendTile(friend: f, onTap: () => _openDetail(f))),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 모델 & 타일 =====

class FriendSummary {
  final String id;
  final String name;
  final String? avatarUrl;
  final int todayRate;

  FriendSummary({
    required this.id,
    required this.name,
    required this.todayRate,
    this.avatarUrl,
  });
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onTap});
  final FriendSummary friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white,
        backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
        child: friend.avatarUrl == null ? const Icon(Icons.person, color: _blue) : null,
      ),
      title: Text(friend.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      subtitle: Text('달성률 ${friend.todayRate}%',
          style: const TextStyle(color: Colors.white70)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white),
      onTap: onTap,
    );
  }
}

// 상세 화면 arguments 전달용
class FriendDetailArgs {
  final String friendId;
  final String name;
  const FriendDetailArgs({required this.friendId, required this.name});
}
