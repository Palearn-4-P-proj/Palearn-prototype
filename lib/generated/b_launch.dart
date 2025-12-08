import 'package:flutter/material.dart';

class BLaunch extends StatelessWidget {
  const BLaunch({
    super.key,
    this.onTapLogin,
    this.onTapSignUp,
  });

  final VoidCallback? onTapLogin;
  final VoidCallback? onTapSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 402,
          height: 874,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                left: 99,
                top: 372,
                child: Text(
                  'Palearn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF7DB2FF),
                    fontSize: 52.14,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    height: 1.10,
                  ),
                ),
              ),
              Positioned(
                left: 82,
                top: 469,
                child: SizedBox(
                  width: 236,
                  child: const Text(
                    '우리들의 AI 공부 트레이너',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4B4544),
                      fontSize: 14,
                      fontFamily: 'League Spartan',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              // Log In 버튼 (터치)
              Positioned(
                left: 98,
                top: 515,
                child: GestureDetector(
                  onTap: onTapLogin,
                  child: SizedBox(
                    width: 207,
                    height: 45,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: ShapeDecoration(
                              color: const Color(0xFF7DB2FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: -7,
                          top: 11,
                          child: SizedBox(
                            width: 220,
                            child: Text(
                              'Log In',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFE0E6F6),
                                fontSize: 20,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                height: 1.10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Sign Up 버튼 (터치)
              Positioned(
                left: 98,
                top: 572,
                child: GestureDetector(
                  onTap: onTapSignUp,
                  child: SizedBox(
                    width: 207,
                    height: 45,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: ShapeDecoration(
                              color: const Color(0xFFD4E5FD),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: -1,
                          top: 11,
                          child: SizedBox(
                            width: 208,
                            child: Text(
                              'Sign Up',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF0E3E3E),
                                fontSize: 20,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                height: 1.10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 로고 (원래 네 코드대로 두면 됨; 필요시 AssetImage로 교체)
              Positioned(
                left: 129,
                top: 199,
                child: Container(
                  width: 173,
                  height: 173,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
