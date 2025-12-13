import 'package:flutter/material.dart';

const _blue = Color(0xFF7DB2FF);

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
                    '개인정보 처리방침',
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
                        'Palearn 개인정보 처리방침',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '''Palearn(이하 "회사")은 이용자의 개인정보를 중요시하며, 개인정보보호법 등 관련 법령을 준수합니다.

1. 수집하는 개인정보 항목
- 필수 항목: 이메일, 이름, 비밀번호
- 선택 항목: 생년월일, 프로필 사진
- 자동 수집 항목: 학습 기록, 서비스 이용 기록

2. 개인정보의 수집 및 이용 목적
- 회원 가입 및 관리
- 맞춤형 학습 계획 생성
- 학습 진도 추적 및 통계 제공
- 서비스 개선 및 신규 서비스 개발

3. 개인정보의 보유 및 이용 기간
- 회원 탈퇴 시까지 보유
- 관련 법령에 따라 보존이 필요한 경우 해당 기간 동안 보유

4. 개인정보의 제3자 제공
회사는 이용자의 개인정보를 원칙적으로 외부에 제공하지 않습니다. 다만, 아래의 경우에는 예외로 합니다:
- 이용자의 사전 동의가 있는 경우
- 법령의 규정에 의거하거나 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우

5. 개인정보의 파기
- 회원 탈퇴 시 지체 없이 파기
- 전자적 파일 형태: 복구 및 재생이 불가능한 방법으로 삭제
- 종이 문서: 분쇄기로 분쇄하거나 소각

6. 이용자의 권리
이용자는 언제든지 자신의 개인정보를 조회하거나 수정할 수 있으며, 회원 탈퇴를 통해 개인정보 삭제를 요청할 수 있습니다.

7. 개인정보 보호책임자
- 담당자: Palearn 개인정보보호팀
- 이메일: privacy@palearn.com

8. 개인정보 처리방침 변경
본 개인정보 처리방침은 법령 및 방침에 따라 변경될 수 있으며, 변경 시 서비스 내 공지사항을 통해 안내합니다.

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
