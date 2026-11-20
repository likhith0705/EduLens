
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  final String email;

  const AttendanceScreen({
    super.key,
    required this.email,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loading = true;
  String? _error;

  double _overallPercentage = 0;
  List<dynamic> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await ApiService.getAttendance(widget.email);

      if (!mounted) return;

      final subjects = data['subjects'] is List
          ? List<dynamic>.from(data['subjects'] as List)
          : <dynamic>[];

      setState(() {
        _subjects = subjects;

        // Use the backend value if it is valid.
        // Otherwise calculate the average from the subjects.
        final backendOverall = _toDouble(
          data['overall_percentage'],
        );

        _overallPercentage = backendOverall ??
            _calculateOverallPercentage(subjects);

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim());
    }

    return null;
  }

  double _calculatePercentage(
    int attendedClasses,
    int totalClasses,
  ) {
    if (totalClasses <= 0) return 0;

    return (attendedClasses / totalClasses) * 100.0;
  }

  double _calculateOverallPercentage(List<dynamic> subjects) {
    if (subjects.isEmpty) return 0;

    var totalAttended = 0;
    var totalConducted = 0;

    for (final item in subjects) {
      if (item is! Map) continue;

      final attended = _toInt(item['attendedClasses']);
      final total = _toInt(item['totalClasses']);

      if (total > 0) {
        totalAttended += attended;
        totalConducted += total;
      }
    }

    if (totalConducted == 0) return 0;

    return (totalAttended / totalConducted) * 100.0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim()) ??
          double.tryParse(value.trim())?.toInt() ??
          0;
    }

    return 0;
  }

  String _formatPercentage(double value) {
    // Show whole numbers without decimals; retain decimals otherwise.
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh attendance',
            onPressed: _loading ? null : _loadAttendance,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.red,
              ),
              const SizedBox(height: 15),
              const Text(
                'Failed to load attendance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadAttendance,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          // Overall attendance
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.calendar_month,
                  size: 45,
                  color: Colors.blue,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Overall Attendance',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatPercentage(_overallPercentage)}%',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _overallPercentage >= 75
                      ? 'Good attendance! Keep it up.'
                      : 'Attendance is below 75%.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            'Subject-wise Attendance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          if (_subjects.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No attendance records available.'),
                ),
              ),
            ),

          ..._subjects.map(_attendanceCard),
        ],
      ),
    );
  }

  Widget _attendanceCard(dynamic subject) {
    if (subject is! Map) {
      return const SizedBox.shrink();
    }

    final name =
        subject['name']?.toString() ?? 'Unknown Subject';

    final attendedClasses =
        _toInt(subject['attendedClasses']);

    final totalClasses =
        _toInt(subject['totalClasses']);

    // Prefer a valid stored percentage, including decimal strings.
    // Calculate it from the counts if the stored value is missing.
    final storedPercentage = _toDouble(subject['percentage']);

    final percentage = storedPercentage ??
        _calculatePercentage(
          attendedClasses,
          totalClasses,
        );

    final progress = (percentage / 100.0).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              '$attendedClasses / $totalClasses classes',
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  '${_formatPercentage(percentage)}%',
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
