
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class PerformanceScreen extends StatefulWidget {
  final String email;

  const PerformanceScreen({
    super.key,
    required this.email,
  });

  @override
  State<PerformanceScreen> createState() =>
      _PerformanceScreenState();
}

class _PerformanceScreenState
    extends State<PerformanceScreen> {
  late Future<Map<String, dynamic>> _performanceFuture;

  @override
  void initState() {
    super.initState();
    _performanceFuture =
        ApiService.getPerformance(widget.email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _performanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load performance:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('No performance data available.'),
            );
          }

          final data = snapshot.data!;
          final overall =
              (data['overall_percentage'] as num?)?.toDouble() ?? 0;
          final subjects =
              (data['subjects'] as List<dynamic>?) ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        size: 45,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Overall Performance',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${overall.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Good progress! Keep improving.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Subject-wise Performance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                if (subjects.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No subject performance data available.',
                      ),
                    ),
                  ),
                ...subjects.map((item) {
                  final subject =
                      Map<String, dynamic>.from(item as Map);

                  final name = subject['name']?.toString() ?? '';
                  final obtained = subject['marksObtained'] ?? 0;
                  final total = subject['totalMarks'] ?? 0;
                  final percentage =
                      (subject['percentage'] as num?)?.toDouble() ?? 0;
                  final grade = subject['grade']?.toString() ?? '-';

                  return _performanceCard(
                    name,
                    '$obtained / $total',
                    percentage,
                    grade,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _performanceCard(
    String subject,
    String marks,
    double percentage,
    String grade,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    grade,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              marks,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
