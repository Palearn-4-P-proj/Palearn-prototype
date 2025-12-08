import 'package:flutter/material.dart';

class ALaunch extends StatelessWidget {
  const ALaunch({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 402,
          height: 874,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: const Color(0xFF7DB2FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40),
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                left: 92,
                top: 408,
                child: Text(
                  ' Palearn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52.14,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    height: 1.10,
                  ),
                ),
              ),
              Positioned(
                left: 83,
                top: 508,
                child: SizedBox(
                  width: 236,
                  child: const Text(
                    '우리들의 AI 공부 트레이너',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE0E6F6),
                      fontSize: 14,
                      fontFamily: 'League Spartan',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 128,
                top: 231,
                child: Container(
                  width: 173,
                  height: 173,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/logo.png'),
                      fit: BoxFit.contain, // 로고라 contain이 자연스러움
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
