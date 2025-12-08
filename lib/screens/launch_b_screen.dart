import 'package:flutter/material.dart';
import '../generated/b_launch.dart';

class LaunchBScreen extends StatelessWidget {
  const LaunchBScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // 🔥 추가된 AppBar — 디자인 깨지지 않도록 투명 + 뒤로가기
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // ------------------------------------------

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              child: BLaunch(
                onTapLogin: () => Navigator.pushNamed(context, '/login'),
                onTapSignUp: () => Navigator.pushNamed(context, '/signup'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
