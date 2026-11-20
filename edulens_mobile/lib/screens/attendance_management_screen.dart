
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AttendanceManagementScreen extends StatefulWidget {
  final String idToken;

  const AttendanceManagementScreen({
    super.key,
    required this.idToken,
  });

  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  static const _departments = [
    'All departments',
    'Data Science',
    'Computer Science',
    'Information Science',
  ];

  static const _sections = ['All sections', 'A', 'B'];

  String _department = 'All departments';
  String _section = 'All sections';
  int? _semester;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getAttendanceSessions(
        idToken: widget.idToken,
        department: _department == 'All departments'
            ? null
            : _department,
        semester: _semester,
        section: _section == 'All sections' ? null : _section,
      );

      final rawSessions = result['sessions'] as List? ?? [];

      if (!mounted) return;

      setState(() {
        _sessions = rawSessions
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openSession(
    Map<String, dynamic> session,
  ) async {
    final records = (session['records'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
      ..sort((a, b) => (a['name'] ?? '')
          .toString()
          .compareTo((b['name'] ?? '').toString()));

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AttendanceSessionDetailScreen(
          session: session,
          records: records,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadSessions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _department,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                  items: _departments
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _department = value);
                    _loadSessions();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _semester,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('All semesters'),
                        items: [
                          for (var i = 1; i <= 8; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text('Semester $i'),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() => _semester = value);
                          _loadSessions();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _section,
                        decoration: const InputDecoration(
                          labelText: 'Section',
                          border: OutlineInputBorder(),
                        ),
                        items: _sections
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _section = value);
                          _loadSessions();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadSessions,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSessions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.event_note, size: 56),
            SizedBox(height: 16),
            Center(
              child: Text('No attendance sessions found.'),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Confirmed classes will appear here.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final subject = session['subject']?.toString() ?? 'Subject';
          final date = session['class_date']?.toString() ?? '';
          final hour = session['hour']?.toString() ?? '-';
          final present = session['present_count'] ?? 0;
          final absent = session['absent_count'] ?? 0;
          final total = session['total_students'] ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                child: Icon(Icons.fact_check_outlined),
              ),
              title: Text(
                subject,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$date • Hour $hour'),
                    const SizedBox(height: 4),
                    Text(
                      '${session['department'] ?? ''} • '
                      'Sem ${session['semester'] ?? '-'} • '
                      'Section ${session['section'] ?? '-'}',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        Text('Present: $present'),
                        Text('Absent: $absent'),
                        Text('Total: $total'),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSession(session),
            ),
          );
        },
      ),
    );
  }
}

class _AttendanceSessionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  final List<Map<String, dynamic>> records;

  const _AttendanceSessionDetailScreen({
    required this.session,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Attendance'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session['subject']?.toString() ?? 'Subject',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Date: ${session['class_date'] ?? '-'}'),
                  Text('Hour: ${session['hour'] ?? '-'}'),
                  Text(
                    'Class: ${session['department'] ?? ''}, '
                    'Semester ${session['semester'] ?? '-'}, '
                    'Section ${session['section'] ?? '-'}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Present: ${session['present_count'] ?? 0}   '
                    'Absent: ${session['absent_count'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Student register',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text('${records.length} students'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: records.isEmpty
                ? const Center(
                    child: Text('No student records in this session.'),
                  )
                : ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final isPresent =
                          record['status'] == 'Present';

                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            isPresent
                                ? Icons.check
                                : Icons.close,
                            color: isPresent
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        title: Text(
                          record['name']?.toString() ?? 'Student',
                        ),
                        subtitle: Text(
                          record['email']?.toString() ?? '',
                        ),
                        trailing: Text(
                          record['status']?.toString() ?? '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isPresent
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
