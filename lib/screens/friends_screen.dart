import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/api_service.dart';
import '../core/widgets.dart';
import '../services/achievement_service.dart';
import '../widgets/achievement_toast.dart';

const _blue = Color(0xFF7DB2FF);
const _blueLight = Color(0xFFE7F0FF);
const _ink = Color(0xFF0E3E3E);
const _green = Color(0xFF4CAF50);

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

  // 샘플 데이터 - 친구별 현재 계획 및 업적
  static const _samplePlans = [
    'Python 기초 마스터',
    'React 웹 개발',
    'Flutter 앱 개발',
    'JavaScript 심화',
    'AI/ML 입문',
    'Java Spring Boot',
  ];

  static const _sampleAchievements = [
    ['첫 걸음', '3일 연속 학습'],
    ['첫 걸음', '열정적인 학습자', '계획 완수'],
    ['첫 걸음', '일주일 연속 학습'],
    ['첫 걸음'],
    ['첫 걸음', '3일 연속 학습', '첫 친구'],
    ['첫 걸음', '열정적인 학습자'],
  ];

  Future<void> _loadFriends() async {
    setState(() => _loading = true);

    try {
      final data = await FriendsService.getFriends();
      if (mounted) {
        setState(() {
          _friends = data.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return FriendSummary(
              id: item['id']?.toString() ?? '',
              name: item['name']?.toString() ?? '',
              todayRate: item['todayRate'] ?? 0,
              avatarUrl: item['avatarUrl']?.toString(),
              // 샘플 데이터로 현재 계획과 업적 추가
              currentPlan: item['currentPlan']?.toString() ?? _samplePlans[i % _samplePlans.length],
              achievements: (item['achievements'] as List?)?.cast<String>() ?? _sampleAchievements[i % _sampleAchievements.length],
            );
          }).toList();
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

      // 친구 추가 업적 체크
      if (mounted) {
        final achievement = await AchievementService.onFriendAdded(_friends.length);
        if (achievement != null && mounted) {
          showAchievementToast(context, achievement);
        }
      }
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
  final String? currentPlan;
  final List<String> achievements;

  FriendSummary({
    required this.id,
    required this.name,
    required this.todayRate,
    this.avatarUrl,
    this.currentPlan,
    this.achievements = const [],
  });
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onTap});
  final FriendSummary friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 아바타 + 이름 + 달성률
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
                    child: friend.avatarUrl == null ? const Icon(Icons.person, color: _blue) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getProgressColor(friend.todayRate).withAlpha(50),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '오늘 ${friend.todayRate}%',
                                style: TextStyle(
                                  color: _getProgressColor(friend.todayRate),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),

              // 현재 학습 중인 계획 (있는 경우)
              if (friend.currentPlan != null && friend.currentPlan!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          friend.currentPlan!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 업적 배지 (있는 경우)
              if (friend.achievements.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: friend.achievements.take(4).map((badge) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getBadgeColor(badge).withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getBadgeColor(badge).withAlpha(100)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getBadgeIcon(badge), size: 12, color: _getBadgeColor(badge)),
                          const SizedBox(width: 4),
                          Text(
                            badge,
                            style: TextStyle(
                              color: _getBadgeColor(badge),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(int rate) {
    if (rate >= 100) return _green;
    if (rate >= 50) return Colors.amber;
    return Colors.white;
  }

  Color _getBadgeColor(String badge) {
    switch (badge) {
      case '첫 걸음':
        return const Color(0xFFFFD700);
      case '열정적인 학습자':
        return const Color(0xFFFF6B35);
      case '3일 연속 학습':
        return const Color(0xFFFF5722);
      case '일주일 연속 학습':
        return const Color(0xFFFF9800);
      case '계획 완수':
        return _green;
      case '첫 친구':
        return const Color(0xFF3F51B5);
      default:
        return Colors.white;
    }
  }

  IconData _getBadgeIcon(String badge) {
    switch (badge) {
      case '첫 걸음':
        return Icons.emoji_events;
      case '열정적인 학습자':
        return Icons.local_fire_department;
      case '3일 연속 학습':
        return Icons.whatshot;
      case '일주일 연속 학습':
        return Icons.local_fire_department;
      case '계획 완수':
        return Icons.verified;
      case '첫 친구':
        return Icons.people;
      default:
        return Icons.star;
    }
  }
}

// 상세 화면 arguments 전달용
class FriendDetailArgs {
  final String friendId;
  final String name;
  const FriendDetailArgs({required this.friendId, required this.name});
}
