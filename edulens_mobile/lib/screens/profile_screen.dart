
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final Future<void> Function(BuildContext) onLogout;
  final Map<String, dynamic> studentData;

  const ProfileScreen({
    super.key,
    required this.onLogout,
    required this.studentData,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _faceImage;

  bool _capturing = false;
  bool _loadingFaceStatus = false;

  String? _faceStatus;
  String? _faceStatusError;

  @override
  void initState() {
    super.initState();
    _loadFaceStatus();
  }

  String get _email =>
      (widget.studentData['email'] ?? '').toString().trim();

  Future<void> _loadFaceStatus() async {
    if (_email.isEmpty) {
      if (!mounted) return;

      setState(() {
        _faceStatusError = 'Student email is missing.';
      });
      return;
    }

    setState(() {
      _loadingFaceStatus = true;
      _faceStatusError = null;
    });

    try {
      final result = await ApiService.getFaceStatus(_email);

      if (!mounted) return;

      setState(() {
        _faceStatus = result['embedding_status']?.toString() ??
            'not_registered';
        _faceStatusError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _faceStatusError = 'Could not load face registration status.';
      });

      debugPrint('Face status error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingFaceStatus = false;
        });
      }
    }
  }

  Future<void> _captureFace() async {
    if (_capturing) return;

    if (_email.isEmpty) {
      _showMessage('Student email is missing.');
      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );

      if (image == null) return;
      if (!mounted) return;

      setState(() {
        _faceImage = image;
      });

      _showMessage(
        'Uploading photo and generating face embedding...',
      );

      final result = await ApiService.registerFace(_email, image);

      if (!mounted) return;

      setState(() {
        _faceStatus =
            result['embedding_status']?.toString() ?? 'completed';
        _faceStatusError = null;
      });

      _showMessage(
        result['message']?.toString() ??
            'Face registered successfully.',
      );

      // Confirm the latest status from the backend.
      await _loadFaceStatus();
    } catch (e) {
      if (!mounted) return;

      _showMessage('Face registration failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _faceStatusLabel {
    switch (_faceStatus) {
      case 'completed':
        return 'Face registered successfully';
      case 'pending':
        return 'Face image registered; embedding pending';
      case 'not_registered':
        return 'Face not registered';
      default:
        return 'Face registration status unavailable';
    }
  }

  IconData get _faceStatusIcon {
    switch (_faceStatus) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.hourglass_top;
      case 'not_registered':
        return Icons.face_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _faceStatusColor(BuildContext context) {
    switch (_faceStatus) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'not_registered':
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.studentData['name'] ?? 'Student';
    final email = widget.studentData['email'] ?? '';
    final profilePhotoUrl = widget.studentData['profile_photo_url'];
    final usn = widget.studentData['usn'] ?? '';
    final department = widget.studentData['department'] ?? '';
    final semester = widget.studentData['semester']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: profilePhotoUrl != null
                  ? NetworkImage(profilePhotoUrl)
                  : null,
              child: profilePhotoUrl == null
                  ? const Icon(Icons.person, size: 55)
                  : null,
            ),

            const SizedBox(height: 15),

            Text(
              name.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              email.toString(),
              style: const TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            _infoCard(
              icon: Icons.badge_outlined,
              title: 'USN',
              value: usn.toString(),
            ),

            _infoCard(
              icon: Icons.account_tree_outlined,
              title: 'Department',
              value: department.toString(),
            ),

            _infoCard(
              icon: Icons.school_outlined,
              title: 'Semester',
              value: 'Semester $semester',
            ),

            const SizedBox(height: 20),

            Card(
              child: ListTile(
                leading: _loadingFaceStatus
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _faceStatusIcon,
                        color: _faceStatusColor(context),
                      ),
                title: Text(
                  _loadingFaceStatus
                      ? 'Checking face registration...'
                      : _faceStatusLabel,
                ),
                subtitle: _faceStatusError != null
                    ? Text(_faceStatusError!)
                    : _faceStatus == 'completed'
                        ? const Text(
                            'Your face embedding is registered.',
                          )
                        : null,
                trailing: IconButton(
                  tooltip: 'Refresh status',
                  onPressed:
                      _loadingFaceStatus ? null : _loadFaceStatus,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),

            if (_faceImage != null) ...[
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Latest photo captured'),
                  subtitle: Text(_faceImage!.name),
                ),
              ),
            ],

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (_capturing || _loadingFaceStatus)
                        ? null
                        : _captureFace,
                icon: _capturing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.face),
                label: Text(
                  _capturing
                      ? 'Processing and registering...'
                      : _faceStatus == 'completed'
                          ? 'Update Face Registration'
                          : 'Register Face',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _capturing
                    ? null
                    : () => widget.onLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
