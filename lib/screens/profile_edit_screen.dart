import 'package:flutter/material.dart';
import '../data/api_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController emailCtrl;
  late TextEditingController nameCtrl;
  late TextEditingController birthCtrl;
  late TextEditingController pwCtrl;
  late TextEditingController pw2Ctrl;
  late TextEditingController photoUrlCtrl;  // 프로필 사진 URL 입력용

  // ▶ 프로필 정보 — 서버에서 GET으로 받아와서 업데이트해야 할 부분
  String photoUrl =
      'https://images.unsplash.com/photo-1603415526960-f7e0328d13a2?w=256&h=256&fit=crop';
  String userId = '25030024';

  bool hidePw = true;
  bool hidePw2 = true;

  @override
  void initState() {
    super.initState();
    emailCtrl = TextEditingController();
    nameCtrl = TextEditingController();
    birthCtrl = TextEditingController();
    pwCtrl = TextEditingController();
    pw2Ctrl = TextEditingController();
    photoUrlCtrl = TextEditingController();

    // API에서 프로필 정보 불러오기
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ProfileService.getProfile();
      if (mounted) {
        setState(() {
          nameCtrl.text = data['name']?.toString() ?? '';
          emailCtrl.text = data['email']?.toString() ?? '';
          birthCtrl.text = data['birth']?.toString() ?? '';
          userId = data['user_id']?.toString() ?? userId;
          final p = data['photo_url']?.toString();
          if (p != null && p.isNotEmpty) {
            photoUrl = p;
            photoUrlCtrl.text = p;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      // arguments에서 백업 데이터 사용
      if (mounted) {
        final a = ModalRoute.of(context)?.settings.arguments as Map?;
        if (a != null) {
          setState(() {
            nameCtrl.text = a['name']?.toString() ?? '';
            userId = a['userId']?.toString() ?? userId;
            final p = a['photoUrl']?.toString();
            if (p != null) {
              photoUrl = p;
              photoUrlCtrl.text = p;
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    nameCtrl.dispose();
    birthCtrl.dispose();
    pwCtrl.dispose();
    pw2Ctrl.dispose();
    photoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    // 현재 birthCtrl에서 날짜 파싱 시도
    DateTime initialDate = DateTime(2000, 1, 1);
    if (birthCtrl.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(birthCtrl.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7DB2FF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        birthCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _updateProfile() async {
    // 비밀번호 확인 검증
    if (pwCtrl.text.isNotEmpty && pwCtrl.text != pw2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    // TODO: 실제 서버 POST 연결 필요
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('프로필이 업데이트되었습니다.')),
    );
    Navigator.pop(context);
  }

  void _showPhotoUrlDialog() {
    photoUrlCtrl.text = photoUrl;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('프로필 사진 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '이미지 URL을 입력하세요',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: photoUrlCtrl,
              decoration: InputDecoration(
                hintText: 'https://example.com/image.jpg',
                filled: true,
                fillColor: const Color(0xFFD6E6FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            // 미리보기
            if (photoUrlCtrl.text.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  photoUrlCtrl.text,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (photoUrlCtrl.text.isNotEmpty) {
                setState(() {
                  photoUrl = photoUrlCtrl.text;
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7DB2FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // 🔵 상단 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF7DB2FF),
                borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text('프로필 수정',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  Opacity(
                    opacity: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white),
                      onPressed: () {},
                    ),
                  )
                ],
              ),
            ),

            // 내용
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    // 프로필 사진
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                            radius: 48,
                            backgroundImage: NetworkImage(photoUrl)),
                        InkWell(
                          onTap: _showPhotoUrlDialog,
                          child: Container(
                            margin:
                            const EdgeInsets.only(right: 4, bottom: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF7DB2FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Text(nameCtrl.text,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text('ID: $userId',
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 18),

                    _field(
                      label: '아이디',
                      child: TextField(
                        controller: emailCtrl,
                        decoration: _decoration('example@example.com'),
                      ),
                    ),
                    _field(
                      label: '이름',
                      child: TextField(
                        controller: nameCtrl,
                        decoration: _decoration('홍길동'),
                      ),
                    ),
                    _field(
                      label: '생일',
                      child: GestureDetector(
                        onTap: () => _selectBirthDate(),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: birthCtrl,
                            decoration: _decoration('생일을 선택하세요').copyWith(
                              suffixIcon: const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF7DB2FF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _field(
                      label: '비밀번호',
                      child: TextField(
                        controller: pwCtrl,
                        obscureText: hidePw,
                        decoration: _decoration(null).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(hidePw
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => hidePw = !hidePw),
                          ),
                        ),
                      ),
                    ),
                    _field(
                      label: '비밀번호 확인',
                      child: TextField(
                        controller: pw2Ctrl,
                        obscureText: hidePw2,
                        decoration: _decoration(null).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(hidePw2
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => hidePw2 = !hidePw2),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 업데이트 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7DB2FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('프로필 업데이트', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  InputDecoration _decoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFD6E6FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
