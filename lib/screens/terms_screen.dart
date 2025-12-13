import 'package:flutter/material.dart';

const _blue = Color(0xFF7DB2FF);

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    '이용약관',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const Spacer(),
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

            // 내용
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Palearn 서비스 이용약관',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '''제1조 (목적)
이 약관은 Palearn(이하 "회사")이 제공하는 AI 기반 학습 계획 서비스(이하 "서비스")의 이용조건 및 절차, 회사와 이용자의 권리, 의무 및 책임사항 등을 규정함을 목적으로 합니다.

제2조 (정의)
1. "서비스"란 회사가 제공하는 AI 기반 맞춤형 학습 계획 생성 및 관리 서비스를 말합니다.
2. "이용자"란 본 약관에 따라 회사가 제공하는 서비스를 이용하는 자를 말합니다.
3. "학습 계획"이란 AI가 생성한 맞춤형 학습 일정 및 콘텐츠를 말합니다.

제3조 (약관의 효력과 변경)
1. 본 약관은 서비스를 이용하고자 하는 모든 이용자에게 적용됩니다.
2. 회사는 필요한 경우 약관을 변경할 수 있으며, 변경된 약관은 서비스 내 공지사항을 통해 공지합니다.

제4조 (서비스의 제공)
회사는 다음의 서비스를 제공합니다:
1. AI 기반 맞춤형 학습 계획 생성
2. 학습 진도 추적 및 통계
3. 강좌 추천 서비스
4. 친구 연동 및 학습 현황 공유

제5조 (이용자의 의무)
이용자는 다음 행위를 하여서는 안 됩니다:
1. 타인의 정보 도용
2. 서비스의 정상적인 운영을 방해하는 행위
3. 서비스를 이용한 영리 목적의 활동
4. 기타 관련 법령에 위배되는 행위

제6조 (면책조항)
1. 회사는 천재지변 등 불가항력으로 인한 서비스 제공 불능에 대해 책임을 지지 않습니다.
2. AI가 생성한 학습 계획은 참고용이며, 학습 결과에 대한 책임은 이용자에게 있습니다.

시행일: 2024년 1월 1일''',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.8,
                          color: Colors.black87,
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
    );
  }
}
