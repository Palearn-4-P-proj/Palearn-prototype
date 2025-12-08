import 'package:flutter/material.dart';
import '../generated/login_signup_widgets.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              child: CreateAccountWidget(
                // 🔵 로그인 화면으로 이동
                onTapBackToLogin: () => Navigator.pushReplacementNamed(context, '/login'),

                // ==================================================================
                // 🔵 [FastAPI POST 필요]
                // 회원가입 버튼 클릭 → 서버에 회원정보 전달
                //
                // CreateAccountWidget 내부에서:
                //   onTapSignUp(
                //      username, email, password, birth, photoUrl ...
                //   ) 을 호출하도록 되어 있을 가능성이 매우 높음.
                //
                // 따라서 SignUpScreen에서는 아래처럼:
                //
                // onTapSignUp: (userData) async {
                //     final res = await http.post(
                //       Uri.parse('http://YOUR_API/signup'),
                //       headers: {'Content-Type': 'application/json'},
                //       body: jsonEncode(userData),
                //     );
                //
                //     if (res.statusCode == 200) {
                //       Navigator.pushReplacementNamed(context, '/login');
                //     } else {
                //       // 에러 처리
                //     }
                // }
                //
                // ※ 지금은 generated 위젯의 구조를 모르므로
                //   SignUpScreen엔 API 직접 호출 X
                //   대신 "여기서 POST 해야 함" 주석만 작성
                //
                // ==================================================================
              ),
            ),
          ),
        ),
      ),
    );
  }
}
