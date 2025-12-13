import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../core/widgets.dart';

/// 공통 컬러
const _blue = Color(0xFF7DB2FF);
const _blueLight = Color(0xFFD4E5FE);
const _ink = Color(0xFF093030);

/// ==============================
/// Login
/// ==============================
class LoginWidget extends StatefulWidget {
  const LoginWidget({
    super.key,
    this.onTapSignUpText,
    this.onTapLogin,
  });

  final VoidCallback? onTapSignUpText;
  final VoidCallback? onTapLogin;

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // 인라인 에러 메시지 검증
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    bool hasError = false;

    if (email.isEmpty) {
      setState(() => _emailError = '이메일을 입력하세요');
      hasError = true;
    } else if (!_isValidEmail(email)) {
      setState(() => _emailError = '올바른 이메일 형식이 아닙니다');
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = '비밀번호를 입력하세요');
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.login(email: email, password: password);
      if (result['success'] == true && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _passwordError = '이메일 또는 비밀번호가 올바르지 않습니다');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      width: double.infinity,
      height: size.height,
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: size.height,
            child: ClipPath(
              clipper: _BottomArcClipper(),
              child: Container(color: _blue),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: size.height * 0.18,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    color: Colors.black.withValues(alpha: 0.06),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        '로그인',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text('이메일',
                        style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _RoundedField(
                      hint: 'example@example.com',
                      controller: _emailController,
                      onChanged: (_) => setState(() => _emailError = null),
                    ),
                    if (_emailError != null) ...[
                      const SizedBox(height: 4),
                      Text(_emailError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],

                    const SizedBox(height: 20),
                    const Text('비밀번호',
                        style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _RoundedField(
                      hint: '비밀번호 입력',
                      obscure: _obscurePassword,
                      controller: _passwordController,
                      onChanged: (_) => setState(() => _passwordError = null),
                      onSubmitted: (_) => _handleLogin(),
                      trailing: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                          color: _ink.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    if (_passwordError != null) ...[
                      const SizedBox(height: 4),
                      Text(_passwordError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],

                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _PrimaryButton(text: '로그인', onTap: _handleLogin),

                    const SizedBox(height: 16),

                    const Spacer(),

                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
                      child: const Center(
                        child: Text.rich(
                          TextSpan(
                            text: "계정이 없으신가요? ",
                            style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w300),
                            children: [
                              TextSpan(
                                text: '회원가입',
                                style: TextStyle(
                                  color: Color(0xFF6CB5FD),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ==============================
/// Sign Up (Create Account)
/// ==============================
class CreateAccountWidget extends StatefulWidget {
  const CreateAccountWidget({super.key, this.onTapBackToLogin});
  final VoidCallback? onTapBackToLogin;

  @override
  State<CreateAccountWidget> createState() => _CreateAccountWidgetState();
}

class _CreateAccountWidgetState extends State<CreateAccountWidget> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePassword2 = true;

  // 인라인 에러 메시지
  String? _emailError;
  String? _nameError;
  String? _passwordError;
  String? _password2Error;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  /// 비밀번호 유효성 검사: 8자 이상, 대문자 1개 이상
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return '비밀번호는 8자 이상이어야 합니다';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return '비밀번호에 대문자가 1개 이상 포함되어야 합니다';
    }
    return null;
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final password2 = _password2Controller.text;

    // 인라인 에러 초기화
    setState(() {
      _emailError = null;
      _nameError = null;
      _passwordError = null;
      _password2Error = null;
    });

    bool hasError = false;

    // 이메일 검증
    if (email.isEmpty) {
      setState(() => _emailError = '이메일을 입력하세요');
      hasError = true;
    } else if (!_isValidEmail(email)) {
      setState(() => _emailError = '올바른 이메일 형식이 아닙니다');
      hasError = true;
    }

    // 이름 검증
    if (name.isEmpty) {
      setState(() => _nameError = '이름을 입력하세요');
      hasError = true;
    }

    // 비밀번호 검증
    if (password.isEmpty) {
      setState(() => _passwordError = '비밀번호를 입력하세요');
      hasError = true;
    } else {
      final pwError = _validatePassword(password);
      if (pwError != null) {
        setState(() => _passwordError = pwError);
        hasError = true;
      }
    }

    // 비밀번호 확인 검증
    if (password2.isEmpty) {
      setState(() => _password2Error = '비밀번호 확인을 입력하세요');
      hasError = true;
    } else if (password != password2) {
      setState(() => _password2Error = '비밀번호가 일치하지 않습니다');
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.signup(
        username: email.split('@').first,
        email: email,
        password: password,
        name: name,
        birth: '2000-01-01',
      );

      // 회원가입 성공 후 자동 로그인
      if (mounted) {
        try {
          final loginResult = await AuthService.login(email: email, password: password);
          if (loginResult['success'] == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('회원가입 성공!')),
            );
            Navigator.pushReplacementNamed(context, '/home');
            return;
          }
        } catch (loginError) {
          debugPrint('Auto-login failed: $loginError');
        }

        // 자동 로그인 실패 시 로그인 화면으로
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회원가입 성공! 로그인해주세요.')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      width: double.infinity,
      height: size.height,
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: size.height,
            child: ClipPath(
              clipper: _BottomArcClipper(),
              child: Container(color: _blue),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: size.height * 0.18,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    color: Colors.black.withValues(alpha: 0.06),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        '회원가입',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text('이메일',
                        style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _RoundedField(
                      hint: 'example@example.com',
                      controller: _emailController,
                      onChanged: (_) => setState(() => _emailError = null),
                    ),
                    if (_emailError != null) ...[
                      const SizedBox(height: 4),
                      Text(_emailError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],

                    const SizedBox(height: 16),
                    const Text('이름',
                        style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _RoundedField(
                      hint: '홍길동',
                      controller: _nameController,
                      onChanged: (_) => setState(() => _nameError = null),
                    ),
                    if (_nameError != null) ...[
                      const SizedBox(height: 4),
                      Text(_nameError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],

                    const SizedBox(height: 16),
                    const Text('비밀번호',
                        style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _RoundedField(
                      hint: '비밀번호 입력',
                      obscure: _obscurePassword,
                      controller: _passwordController,
                      onChanged: (_) => setState(() => _passwordError = null),
                      trailing: GestureDetector(
                        onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                          color: _ink.withAlpha(180),
                        ),
                      ),
                    ),
                    if (_passwordError != null) ...[
                      const SizedBox(height: 4),
                      Text(_passwordError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                    const SizedBox(height: 8),
                    PasswordStrengthIndicator(password: _passwordController.text),

                    const SizedBox(height: 16),
                    const Text('비밀번호 확인',
                        style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _RoundedField(
                      hint: '비밀번호 확인 입력',
                      obscure: _obscurePassword2,
                      controller: _password2Controller,
                      onChanged: (_) => setState(() => _password2Error = null),
                      trailing: GestureDetector(
                        onTap: () => setState(() => _obscurePassword2 = !_obscurePassword2),
                        child: Icon(
                          _obscurePassword2 ? Icons.visibility : Icons.visibility_off,
                          size: 20,
                          color: _ink.withAlpha(180),
                        ),
                      ),
                    ),
                    if (_password2Error != null) ...[
                      const SizedBox(height: 4),
                      Text(_password2Error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],

                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _PrimaryButton(text: '회원가입', onTap: _handleSignUp),

                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onTapBackToLogin ?? () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Center(
                        child: Text.rich(
                          TextSpan(
                            text: '이미 계정이 있으신가요? ',
                            style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w300),
                            children: [
                              TextSpan(
                                text: '로그인',
                                style: TextStyle(
                                  color: Color(0xFF6CB5FD),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ==============================
/// 공용 작은 위젯들
/// ==============================
class _RoundedField extends StatelessWidget {
  const _RoundedField({
    this.hint,
    this.obscure = false,
    this.trailing,
    this.controller,
    this.onChanged,
    this.onSubmitted,
  });
  final String? hint;
  final bool obscure;
  final Widget? trailing;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _blueLight,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: onSubmitted != null ? TextInputAction.done : TextInputAction.next,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: TextStyle(
                  color: _ink.withAlpha(115),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFE0E6F6),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


/// 상단 하늘색 영역의 '아래쪽 아치'를 만드는 클리퍼
class _BottomArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final topY = size.height * 0.28;
    final midDrop = size.height * 0.08;

    final path = Path()..lineTo(0, topY);
    final control = Offset(size.width / 2, topY + midDrop);
    final end = Offset(size.width, topY);
    path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _BottomArcClipper oldClipper) => false;
}
