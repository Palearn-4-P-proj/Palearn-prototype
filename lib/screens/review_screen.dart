import 'package:flutter/material.dart';
import '../data/api_service.dart';

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
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
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
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
      bottomNavigationBar: Container(
        height: 84,
        decoration: const BoxDecoration(
          color: Color(0xFFE3EEFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            Icon(Icons.home, size: 28, color: _ink),
            Icon(Icons.insights_outlined, size: 28, color: _ink),
            Icon(Icons.sync_alt, size: 28, color: _ink),
            Icon(Icons.layers_outlined, size: 28, color: _ink),
            Icon(Icons.person_outline, size: 28, color: _ink),
          ],
        ),
      ),
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
