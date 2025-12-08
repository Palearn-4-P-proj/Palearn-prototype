import 'package:flutter/material.dart';
import '../data/api_service.dart';

const _blue = Color(0xFF7DB2FF);
const _blueLight = Color(0xFFE7F0FF);
const _ink = Color(0xFF0E3E3E);
const _green = Color(0xFF4CAF50);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = false;
  List<Map<String, dynamic>> _allPlans = [];
  List<_SearchResult> _results = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPlans();
    // 화면 진입 시 자동 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await PlanService.getMyPlans();
      setState(() {
        _allPlans = plans;
      });
    } catch (e) {
      debugPrint('Error loading plans: $e');
    }
  }

  void _search(String query) {
    setState(() {
      _query = query.trim().toLowerCase();
      _loading = true;
    });

    if (_query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }

    final results = <_SearchResult>[];

    for (final plan in _allPlans) {
      final planName = plan['plan_name']?.toString() ?? '';
      final schedule = plan['daily_schedule'] as List? ?? [];

      // 계획 이름 검색
      if (planName.toLowerCase().contains(_query)) {
        results.add(_SearchResult(
          type: _SearchResultType.plan,
          title: planName,
          subtitle: '학습 계획',
          plan: plan,
        ));
      }

      // 태스크 검색
      for (final day in schedule) {
        final tasks = day['tasks'] as List? ?? [];
        final date = day['date']?.toString() ?? '';

        for (final task in tasks) {
          final title = task['title']?.toString() ?? '';
          final description = task['description']?.toString() ?? '';

          if (title.toLowerCase().contains(_query) ||
              description.toLowerCase().contains(_query)) {
            results.add(_SearchResult(
              type: _SearchResultType.task,
              title: title,
              subtitle: '$planName · $date',
              task: task,
              plan: plan,
              date: date,
              completed: task['completed'] == true,
            ));
          }
        }
      }
    }

    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      body: SafeArea(
        child: Column(
          children: [
            // 검색 헤더
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _blueLight,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onChanged: _search,
                        decoration: InputDecoration(
                          hintText: '학습 계획, 과제 검색...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.search, color: _blue),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _search('');
                                  },
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 검색 결과
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _query.isEmpty
                      ? _buildEmptyState()
                      : _results.isEmpty
                          ? _buildNoResults()
                          : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '검색어를 입력하세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '학습 계획, 과제명으로 검색할 수 있습니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '"$_query"에 대한 결과가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 검색어로 시도해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    // 타입별로 그룹핑
    final planResults = _results.where((r) => r.type == _SearchResultType.plan).toList();
    final taskResults = _results.where((r) => r.type == _SearchResultType.task).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 결과 개수
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${_results.length}개의 검색 결과',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),

        // 학습 계획 결과
        if (planResults.isNotEmpty) ...[
          _buildSectionHeader('학습 계획', Icons.menu_book, planResults.length),
          const SizedBox(height: 8),
          ...planResults.map(_buildPlanResult),
          const SizedBox(height: 20),
        ],

        // 과제 결과
        if (taskResults.isNotEmpty) ...[
          _buildSectionHeader('과제', Icons.task_alt, taskResults.length),
          const SizedBox(height: 8),
          ...taskResults.map(_buildTaskResult),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, color: _blue, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _blueLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              color: _blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanResult(_SearchResult result) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/plan_detail', arguments: result.plan);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _blueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book, color: _blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _highlightText(result.title, _query),
                  const SizedBox(height: 4),
                  Text(
                    result.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskResult(_SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.completed ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: result.completed
            ? Border.all(color: _green.withAlpha(100), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: result.completed ? _green : _blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              result.completed ? Icons.check : Icons.task_alt,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _highlightText(result.title, _query),
                const SizedBox(height: 4),
                Text(
                  result.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (result.completed)
            const Icon(Icons.check_circle, color: _green, size: 22),
        ],
      ),
    );
  }

  Widget _highlightText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      );
    }

    final endIndex = startIndex + query.length;
    final before = text.substring(0, startIndex);
    final match = text.substring(startIndex, endIndex);
    final after = text.substring(endIndex);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: _ink,
          fontSize: 15,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              backgroundColor: Color(0xFFFFEB3B),
              color: _ink,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

enum _SearchResultType { plan, task }

class _SearchResult {
  final _SearchResultType type;
  final String title;
  final String subtitle;
  final Map<String, dynamic>? plan;
  final Map<String, dynamic>? task;
  final String? date;
  final bool completed;

  _SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.plan,
    this.task,
    this.date,
    this.completed = false,
  });
}
