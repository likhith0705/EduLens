
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'attendance_screen.dart';
import 'performance_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String email;
  final String? photoUrl;
  final Map<String, dynamic> studentData;
  final Future<void> Function(BuildContext) onLogout;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.email,
    this.photoUrl,
    required this.studentData,
    required this.onLogout,
  });

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _attendanceFuture;
  late Future<Map<String, dynamic>> _performanceFuture;

  @override
  void initState() {
    super.initState();
    _loadAcademicData();
  }

  void _loadAcademicData() {
    final email =
        (widget.studentData['email'] ?? widget.email).toString();

    _attendanceFuture = ApiService.getAttendance(email);
    _performanceFuture = ApiService.getPerformance(email);
  }

  Future<void> _refreshAcademicData() async {
    setState(_loadAcademicData);
    await Future.wait([
      _attendanceFuture,
      _performanceFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final studentData = widget.studentData;
    final name = studentData['name'] ?? widget.userName;
    final studentEmail = studentData['email'] ?? widget.email;
    final photoUrl =
        studentData['profile_photo_url'] ?? widget.photoUrl;
    final usn = studentData['usn'] ?? '';
    final department = studentData['department'] ?? '';
    final semester = studentData['semester']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduLens'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      studentData: studentData,
                      onLogout: widget.onLogout,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                backgroundImage: photoUrl != null &&
                        photoUrl.toString().isNotEmpty
                    ? NetworkImage(photoUrl.toString())
                    : null,
                child: photoUrl == null ||
                        photoUrl.toString().isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAcademicData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name 👋',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                studentEmail.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              Card(
                elevation: 0,
                color: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _StudentInfoRow(
                        icon: Icons.badge_outlined,
                        title: 'USN',
                        value: usn.toString(),
                      ),
                      const SizedBox(height: 12),
                      _StudentInfoRow(
                        icon: Icons.account_tree_outlined,
                        title: 'Department',
                        value: department.toString(),
                      ),
                      const SizedBox(height: 12),
                      _StudentInfoRow(
                        icon: Icons.school_outlined,
                        title: 'Semester',
                        value: 'Semester $semester',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              const Text(
                'Academic Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _LiveAcademicCard(
                      title: 'Attendance',
                      icon: Icons.calendar_month,
                      future: _attendanceFuture,
                      field: 'overall_percentage',
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _LiveAcademicCard(
                      title: 'Performance',
                      icon: Icons.trending_up,
                      future: _performanceFuture,
                      field: 'overall_percentage',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              const Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.grey.shade200,
    ),
  ),
  child: ListTile(
    leading: Icon(
      Icons.fact_check,
      color: Colors.blueGrey.shade700,
    ),
    title: const Text(
      'Attendance',
      style: TextStyle(
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: const Text(
      'View subject-wise attendance',
    ),
    trailing: Icon(
      Icons.arrow_forward_ios,
      size: 18,
      color: Colors.grey.shade600,
    ),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AttendanceScreen(
            email: studentEmail.toString(),
          ),
        ),
      );
    },
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
),

              const SizedBox(height: 12),

              Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.grey.shade200,
    ),
  ),
  child: ListTile(
    leading: Icon(
      Icons.bar_chart,
      color: Colors.blueGrey.shade700,
    ),
    title: const Text(
      'Performance',
      style: TextStyle(
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: const Text(
      'View marks and academic progress',
    ),
    trailing: Icon(
      Icons.arrow_forward_ios,
      size: 18,
      color: Colors.grey.shade600,
    ),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PerformanceScreen(
            email: studentEmail.toString(),
          ),
        ),
      );
    },
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveAcademicCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Future<Map<String, dynamic>> future;
  final String field;

  const _LiveAcademicCard({
    required this.title,
    required this.icon,
    required this.future,
    required this.field,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        String value = '...';

        if (snapshot.hasData) {
          final result = snapshot.data![field];
          if (result is num) {
            value = '${result.toStringAsFixed(0)}%';
          } else {
            value = '0%';
          }
        } else if (snapshot.hasError) {
          value = 'N/A';
        }

        return _DashboardCard(
          title: title,
          value: value,
          icon: icon,
        );
      },
    );
  }
}

class _StudentInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StudentInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 30,
            color: Colors.blueGrey.shade700,
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202124),
            ),
          ),
        ],
      ),
    );
  }
}