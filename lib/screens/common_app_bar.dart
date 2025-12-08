import 'package:flutter/material.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color background;
  final bool autoBack; // 뒤로가기 버튼 넣을지 여부

  const CommonAppBar({
    super.key,
    required this.title,
    this.background = Colors.white,
    this.autoBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: background,
      elevation: 0,
      centerTitle: true,
      leading: autoBack
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
        onPressed: () {
          Navigator.pop(context);
        },
      )
          : null, // 홈화면처럼 root 페이지는 뒤로가기 안 넣을 수 있음
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
