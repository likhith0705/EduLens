
import 'package:flutter/material.dart';

import 'classroom_recognition_screen.dart';

import 'attendance_management_screen.dart';

class TeacherDashboardScreen extends StatelessWidget {
  final String userName;
  final String email;
  final String? photoUrl;
  final String idToken;
  final Future<void> Function(BuildContext) onLogout;

  const TeacherDashboardScreen({
    super.key,
    required this.userName,
    required this.email,
    required this.photoUrl,
    required this.idToken,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EduLens Teacher'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => onLogout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 38,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? const Icon(Icons.person, size: 40)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome, $userName',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            email,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Card(
            child: ListTile(
              leading: const Icon(Icons.face_retouching_natural),
              title: const Text('Classroom Face Recognition'),
              subtitle: const Text(
                'Recognize registered students in a classroom image.',
              ),
              
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClassroomRecognitionScreen(
                      idToken: idToken,
                    ),
                  ),
                );
              },

            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Attendance Management'),
              subtitle: const Text(
                'Review and manage class attendance.',
              ),
              onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AttendanceManagementScreen(
        idToken: idToken,
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
