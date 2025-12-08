import 'package:flutter/material.dart';
// 📌 서버 통신 시 http, dio 등이 필요함
// import 'package:http/http.dart' as http;
// import 'dart:convert';

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
    emailCtrl = TextEditingController(text: 'example@example.com');
    nameCtrl = TextEditingController(text: 'John Smith');
    birthCtrl = TextEditingController();
    pwCtrl = TextEditingController();
    pw2Ctrl = TextEditingController();
    photoUrlCtrl = TextEditingController(text: photoUrl);

    // =========================================================================
    // 🟦 [중요] 프로필 초기 데이터 불러오기 — FastAPI GET 필요
    //
    // GET /profile/{user_id}
    //
    // 응답 예)
    // {
    //   "name": "한은진",
    //   "email": "abc@gmail.com",
    //   "birth": "2004-06-24",
    //   "photo_url": "...",
    // }
    //
    // Flutter 예)
    // final res = await http.get(Uri.parse('$BASE/profile/$userId'));
    // final data = json.decode(res.body);
    // setState(() {
    //   nameCtrl.text = data["name"];
    //   emailCtrl.text = data["email"];
    //   birthCtrl.text = data["birth"];
    //   photoUrl = data["photo_url"];
    // });
    //
    // =========================================================================
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = ModalRoute.of(context)?.settings.arguments as Map?;
      if (a != null) {
        setState(() {
          nameCtrl.text = a['name']?.toString() ?? nameCtrl.text;
          userId = a['userId']?.toString() ?? userId;
          final p = a['photoUrl']?.toString();
          if (p != null) {
            photoUrl = p;
            photoUrlCtrl.text = p;
          }
        });
      }
    });
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

  // ===========================================================================
  // 🟦 [중요] 프로필 업데이트 — FastAPI POST 또는 PUT 필요
  //
  // POST /profile/update
  //
  // body 예)
  // {
  //   "user_id": "25030024",
  //   "email": "...",
  //   "name": "...",
  //   "birth": "...",
  //   "password": "1234",
  // }
  //
  // Flutter 예)
  // final res = await http.post(
  //   Uri.parse('$BASE/profile/update'),
  //   headers: {"Content-Type": "application/json"},
  //   body: json.encode({
  //     "user_id": userId,
  //     "email": emailCtrl.text,
  //     "name": nameCtrl.text,
  //     "birth": birthCtrl.text,
  //     "password": pwCtrl.text,
  //   }),
  // );
  //
  // 성공하면:
  // Navigator.pop(context);  // 프로필 화면으로 복귀
  // ===========================================================================
  Future<void> _updateProfile() async {
    // TODO: 실제 서버 POST 연결 필요

    // 현재는 데모용 알림
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
                  const Text('Edit My Profile',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
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
                      child: TextField(
                        controller: birthCtrl,
                        decoration: _decoration('DD / MM / YYYY'),
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
                        child: const Text('Update Profile'),
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
