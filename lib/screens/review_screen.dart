import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../core/widgets.dart';

const _blueLight = Color(0xFFE7F0FF);
const _ink = Color(0xFF0E3E3E);

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _reviewItems = [];

  @override
  void initState() {
    super.initState();
    _loadReviewItems();
  }

  Future<void> _loadReviewItems() async {
    try {
      final data = await ReviewService.getYesterdayMaterials();
      if (mounted) {
        setState(() {
          _reviewItems = data;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading review items: $e');
      if (mounted) {
        setState(() {
          _reviewItems = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 헤더 (SafeArea 밖, 상단에 완전히 붙음)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF7DB2FF),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '어제 했던 것 복습',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                  // 콘텐츠 리스트
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      children: [
                        if (_reviewItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              '복습할 항목이 없습니다.',
                              style: TextStyle(color: Colors.black54, fontSize: 16),
                            ),
                          )
                        else
                          ..._reviewItems.map((item) => _ReviewCard(
                                title: item['type']?.toString() ?? '',
                                subtitle: item['title']?.toString() ?? '',
                              )),
                      ],
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: const CommonBottomNav(currentItem: NavItem.home),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ReviewCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: _blueLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              )),
        ],
      ),
    );
  }
}
