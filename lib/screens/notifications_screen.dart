import 'package:flutter/material.dart';
import '../data/api_service.dart';

const _blue = Color(0xFF7DB2FF);
const _ink = Color(0xFF0E3E3E);

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _loading = true;

  // ▶ 서버에서 받아올 데이터
  List<String> _newAlerts = [];
  List<String> _oldAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await NotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _newAlerts = (data['new_alerts'] as List?)
              ?.map((e) => e.toString())
              .toList() ?? [];
          _oldAlerts = (data['old_alerts'] as List?)
              ?.map((e) => e.toString())
              .toList() ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _newAlerts = [];
          _oldAlerts = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FD);
    final textColor = isDark ? const Color(0xFFE5E5E5) : _ink;
    final subTextColor = isDark ? const Color(0xFFB0B0B0) : Colors.black54;
    final dividerColor = isDark ? Colors.white24 : Colors.black45;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // 상단 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: const BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '알림',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // 알림 목록
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // 새로운 알림
                  Row(
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          color: textColor),
                      const SizedBox(width: 6),
                      Text(
                        '새로운 알림',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 24, color: dividerColor),

                  if (_newAlerts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('새로운 알림이 없습니다.',
                          style: TextStyle(color: subTextColor)),
                    )
                  else
                    ..._newAlerts.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          e,
                          style: TextStyle(color: textColor, fontSize: 15),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  Divider(height: 32, color: dividerColor),

                  // 이전 알림
                  Row(
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: textColor),
                      const SizedBox(width: 6),
                      Text(
                        '이전 알림',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 24, color: dividerColor),

                  if (_oldAlerts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('이전 알림이 없습니다.',
                          style: TextStyle(color: subTextColor)),
                    )
                  else
                    ..._oldAlerts.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          e,
                          style: TextStyle(color: subTextColor),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
