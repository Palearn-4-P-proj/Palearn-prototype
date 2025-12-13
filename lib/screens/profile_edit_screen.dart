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
  late TextEditingController photoUrlCtrl;

  // ▶ 프로필 정보 — 서버에서 GET으로 받아와서 업데이트해야 할 부분
  String photoUrl =
      'https://images.unsplash.com/photo-1603415526960-f7e0328d13a2?w=256&h=256&fit=crop';
  String userId = '25030024';

  bool hidePw = true;
  bool hidePw2 = true;
  bool _isLoading = false;

  // 인라인 에러 메시지
  String? _pwError;
  String? _pw2Error;

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

  /// 비밀번호 유효성 검사: 8자 이상, 대문자 1개 이상
  String? _validatePassword(String password) {
    if (password.isEmpty) return null; // 비밀번호 변경 안 함
    if (password.length < 8) {
      return '비밀번호는 8자 이상이어야 합니다';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return '비밀번호에 대문자가 1개 이상 포함되어야 합니다';
    }
    return null;
  }

  Future<void> _updateProfile() async {
    // 비밀번호 유효성 검사
    setState(() {
      _pwError = null;
      _pw2Error = null;
    });

    bool hasError = false;

    if (pwCtrl.text.isNotEmpty) {
      final pwValidation = _validatePassword(pwCtrl.text);
      if (pwValidation != null) {
        setState(() => _pwError = pwValidation);
        hasError = true;
      }

      if (pw2Ctrl.text.isEmpty) {
        setState(() => _pw2Error = '비밀번호 확인을 입력하세요');
        hasError = true;
      } else if (pwCtrl.text != pw2Ctrl.text) {
        setState(() => _pw2Error = '비밀번호가 일치하지 않습니다');
        hasError = true;
      }
    }

    if (hasError) return;

    setState(() => _isLoading = true);

    try {
      // 실제 서버 API 호출
      await ProfileService.updateProfile(
        name: nameCtrl.text,
        email: emailCtrl.text,
        birth: birthCtrl.text,
        photoUrl: photoUrl,
        password: pwCtrl.text.isNotEmpty ? pwCtrl.text : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 업데이트되었습니다.')),
      );
      Navigator.pop(context, true); // true를 반환하여 업데이트됨을 알림
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 업데이트 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      error: _pwError,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: pwCtrl,
                            obscureText: hidePw,
                            onChanged: (_) => setState(() {}),
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
                          if (pwCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildPasswordStrengthIndicator(pwCtrl.text),
                          ],
                        ],
                      ),
                    ),
                    _field(
                      label: '비밀번호 확인',
                      error: _pw2Error,
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
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7DB2FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF7DB2FF).withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('프로필 업데이트', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _field({required String label, required Widget child, String? error}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          child,
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(String password) {
    int strength = 0;
    String label = '약함';
    Color color = Colors.red;

    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    if (strength == 1) {
      label = '약함';
      color = Colors.red;
    } else if (strength == 2) {
      label = '보통';
      color = Colors.orange;
    } else if (strength == 3) {
      label = '강함';
      color = Colors.lightGreen;
    } else if (strength >= 4) {
      label = '매우 강함';
      color = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: strength / 4,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '8자 이상, 대문자 포함 필수',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
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
