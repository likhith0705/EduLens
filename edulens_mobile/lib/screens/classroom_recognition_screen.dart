
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class ClassroomRecognitionScreen extends StatefulWidget {
  final String idToken;

  const ClassroomRecognitionScreen({
    super.key,
    required this.idToken,
  });

  @override
  State<ClassroomRecognitionScreen> createState() =>
      _ClassroomRecognitionScreenState();
}

class _ClassroomRecognitionScreenState
    extends State<ClassroomRecognitionScreen> {
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _hourController =
      TextEditingController(text: '5');

  final ScrollController _scrollController = ScrollController();

  // Update these lists as your college's classes are added.
  static const List<String> _departments = [
    'Data Science',
    'Computer Science',
    'Information Science',
  ];

  static const List<String> _subjects = [
    'Data Structures',
    'Computer Networks',
    'Database Management Systems',
    'Operating Systems',
    'Design and Analysis of Algorithms',
    'Machine Learning',
    'Natural Language Processing',
    'Big Data Analytics',
  ];

  static const List<String> _sections = ['A', 'B'];

  static const int _semester = 7;

  String _selectedDepartment = 'Data Science';
  String _selectedSubject = 'Data Structures';
  String _selectedSection = 'A';

  XFile? _image;
  Map<String, dynamic>? _result;

  List<Map<String, dynamic>> _roster = [];
  List<dynamic> _matches = [];

  final Set<String> _selectedEmails = {};

  bool _loading = false;
  bool _saving = false;
  String? _error;

  DateTime _classDate = DateTime.now();

  @override
  void dispose() {
    _hourController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  

  Future<void> _pickImage(ImageSource source) async {
    FocusScope.of(context).unfocus();

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (image == null || !mounted) return;

      setState(() {
        _image = image;
        _result = null;
        _roster = [];
        _matches = [];
        _selectedEmails.clear();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not select image: $e';
      });
    }
  }

  Future<void> _recognize() async {
    FocusScope.of(context).unfocus();

    if (_image == null) {
      setState(() {
        _error = 'Capture or select a classroom image first.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _roster = [];
      _matches = [];
      _selectedEmails.clear();
    });

    try {
      // Load students belonging to the selected class.
      final rosterResponse = await ApiService.getClassRoster(
        idToken: widget.idToken,
        department: _selectedDepartment,
        semester: _semester,
        section: _selectedSection,
      );

      final rawStudents =
          rosterResponse['students'] as List<dynamic>? ?? [];

      final students = rawStudents
          .whereType<Map>()
          .map((student) => Map<String, dynamic>.from(student))
          .where((student) => student['email'] is String)
          .toList();

      if (students.isEmpty) {
        throw Exception(
          'No students found for $_selectedDepartment, '
          'semester $_semester, section $_selectedSection. '
          'Check the student records in Firestore.',
        );
      }

      // Run face recognition on the selected classroom image.
      final result = await ApiService.recognizeClassroom(
        widget.idToken,
        _image!,
      );

      final matches = result['matches'] as List<dynamic>? ?? [];

      final rosterEmails = students
          .map((student) => student['email'].toString().toLowerCase())
          .toSet();

      final recognized = <String>{};

      for (final item in matches) {
        if (item is Map &&
            item['status'] == 'matched' &&
            item['email'] is String) {
          final email = item['email'].toString().toLowerCase();

          // Only preselect recognized students from this roster.
          if (rosterEmails.contains(email)) {
            recognized.add(email);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _roster = students;
        _matches = matches;
        _result = result;
        _selectedEmails.addAll(recognized);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _chooseDate() async {
    FocusScope.of(context).unfocus();

    final chosen = await showDatePicker(
      context: context,
      initialDate: _classDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (chosen != null && mounted) {
      setState(() {
        _classDate = chosen;
      });
    }
  }

  void _setAllPresent(bool present) {
    setState(() {
      _selectedEmails.clear();

      if (present) {
        for (final student in _roster) {
          _selectedEmails.add(
            student['email'].toString().toLowerCase(),
          );
        }
      }
    });
  }

  Future<void> _confirmAttendance() async {
    FocusScope.of(context).unfocus();

    final subject = _selectedSubject;
    final section = _selectedSection;
    final department = _selectedDepartment;
    final hour = int.tryParse(_hourController.text.trim());

    if (hour == null || hour < 1 || hour > 12) {
      setState(() {
        _error = 'Enter a valid class hour between 1 and 12.';
      });
      return;
    }

    if (_result == null || _roster.isEmpty) {
      setState(() {
        _error = 'Load the roster and recognize students first.';
      });
      return;
    }

    final dateString =
        '${_classDate.year.toString().padLeft(4, '0')}-'
        '${_classDate.month.toString().padLeft(2, '0')}-'
        '${_classDate.day.toString().padLeft(2, '0')}';

    final presentCount = _selectedEmails.length;
    final absentCount = _roster.length - presentCount;

    // Send every student, including those marked absent.
    final attendanceRecords = _roster.map((student) {
      final email = student['email'].toString().toLowerCase();

      return <String, String>{
        'email': email,
        'status': _selectedEmails.contains(email)
            ? 'Present'
            : 'Absent',
      };
    }).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Attendance'),
        content: SingleChildScrollView(
          child: Text(
            'Review the attendance register before saving.\n\n'
            'Department: $department\n'
            'Semester: $_semester\n'
            'Subject: $subject\n'
            'Hour: $hour\n'
            'Section: $section\n'
            'Date: $dateString\n\n'
            'Present: $presentCount\n'
            'Absent: $absentCount\n'
            'Total students: ${_roster.length}\n\n'
            'Continue only if these attendance statuses are correct.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final response = await ApiService.confirmAttendance(
        idToken: widget.idToken,
        subject: subject,
        hour: hour,
        classDate: dateString,
        section: section,
        department: department,
        semester: _semester,
        attendanceRecords: attendanceRecords,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Attendance Saved'),
          content: Text(
            'Attendance was saved successfully.\n\n'
            'Department: $department\n'
            'Subject: ${response['subject']}\n'
            'Hour: ${response['hour']}\n'
            'Section: ${response['section']}\n'
            'Date: ${response['class_date']}\n\n'
            'Present: ${response['present_count']}\n'
            'Absent: ${response['absent_count']}\n'
            'Total: ${response['total_students']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildStudentTile(Map<String, dynamic> student) {
    final email = student['email'].toString().toLowerCase();
    final isPresent = _selectedEmails.contains(email);
    final faceRegistered = student['face_registered'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isPresent,
        onChanged: _saving
            ? null
            : (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedEmails.add(email);
                  } else {
                    _selectedEmails.remove(email);
                  }
                });
              },
        controlAffinity: ListTileControlAffinity.leading,
        secondary: Icon(
          isPresent ? Icons.check_circle : Icons.cancel_outlined,
          color: isPresent ? Colors.green : Colors.grey,
        ),
        title: Text(student['name']?.toString() ?? 'Student'),
        subtitle: Text(
          '${student['usn'] ?? 'USN unavailable'}\n'
          '$email\n'
          '${faceRegistered ? 'Face registered' : 'Face not registered'}',
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateString =
        '${_classDate.day.toString().padLeft(2, '0')}/'
        '${_classDate.month.toString().padLeft(2, '0')}/'
        '${_classDate.year}';

    final presentCount = _selectedEmails.length;
    final absentCount = _roster.length - presentCount;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Classroom Recognition'),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            controller: _scrollController,
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Class Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              // Department dropdown.
              DropdownButtonFormField<String>(
                initialValue: _selectedDepartment,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: _departments.map((department) {
                  return DropdownMenuItem<String>(
                    value: department,
                    child: Text(department),
                  );
                }).toList(),
                onChanged: _loading || _saving
                    ? null
                    : (value) {
                        if (value == null ||
                            value == _selectedDepartment) {
                          return;
                        }

                        setState(() {
                          _selectedDepartment = value;
                          _result = null;
                          _roster = [];
                          _matches = [];
                          _selectedEmails.clear();
                          _error = null;
                        });
                      },
              ),
              const SizedBox(height: 12),

              // Semester is fixed to 7 for the current demo.
              TextFormField(
                initialValue: '$_semester',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Semester',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Subject dropdown.
              DropdownButtonFormField<String>(
                initialValue: _selectedSubject,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book_outlined),
                ),
                items: _subjects.map((subject) {
                  return DropdownMenuItem<String>(
                    value: subject,
                    child: Text(subject),
                  );
                }).toList(),
                onChanged: _loading || _saving
                    ? null
                    : (value) {
                        if (value == null ||
                            value == _selectedSubject) {
                          return;
                        }

                        setState(() {
                          _selectedSubject = value;
                          _result = null;
                          _roster = [];
                          _matches = [];
                          _selectedEmails.clear();
                          _error = null;
                        });
                      },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _hourController,
                enabled: !_loading && !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: const InputDecoration(
                  labelText: 'Class Hour',
                  hintText: 'e.g. 5',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule),
                ),
              ),
              const SizedBox(height: 12),

              // Section dropdown.
              DropdownButtonFormField<String>(
                initialValue: _selectedSection,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: _sections.map((section) {
                  return DropdownMenuItem<String>(
                    value: section,
                    child: Text('Section $section'),
                  );
                }).toList(),
                onChanged: _loading || _saving
                    ? null
                    : (value) {
                        if (value == null ||
                            value == _selectedSection) {
                          return;
                        }

                        setState(() {
                          _selectedSection = value;
                          _result = null;
                          _roster = [];
                          _matches = [];
                          _selectedEmails.clear();
                          _error = null;
                        });
                      },
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _loading || _saving ? null : _chooseDate,
                icon: const Icon(Icons.calendar_month),
                label: Text('Class Date: $dateString'),
              ),

              const SizedBox(height: 24),

              Text(
                'Classroom Photo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              if (_image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_image!.path),
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_outlined, size: 48),
                      SizedBox(height: 8),
                      Text('No classroom image selected'),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _loading || _saving
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Capture Photo'),
              ),

              OutlinedButton.icon(
                onPressed: _loading || _saving
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from Gallery'),
              ),

              const SizedBox(height: 8),

              FilledButton.icon(
                onPressed: _loading || _saving ? null : _recognize,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.face_retouching_natural),
                label: Text(
                  _loading
                      ? 'Loading roster and recognizing...'
                      : 'Load Roster & Recognize',
                ),
              ),

              if (_result != null) ...[
                const SizedBox(height: 28),

                Text(
                  'Recognition Summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),

                Text('Roster size: ${_roster.length}'),
                Text(
                  'Faces detected: '
                  '${_result!['faces_detected'] ?? _matches.length}',
                ),
                Text(
                  'Registered embeddings checked: '
                  '${_result!['registered_embeddings_checked'] ?? 0}',
                ),
                Text('Initially recognized in roster: '
                    '${_selectedEmails.length}'),

                const SizedBox(height: 20),

                Text(
                  'Review Complete Attendance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),

                const Text(
                  'Recognized students are selected as present by '
                  'default. Check or uncheck students to correct '
                  'the register. Unchecked students will be marked absent.',
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => _setAllPresent(true),
                      child: const Text('Mark All Present'),
                    ),
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => _setAllPresent(false),
                      child: const Text('Mark All Absent'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                for (final student in _roster)
                  _buildStudentTile(student),

                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Present')),
                            Text('$presentCount'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.cancel_outlined,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Absent')),
                            Text('$absentCount'),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Total students'),
                            ),
                            Text('${_roster.length}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving || _loading
                        ? null
                        : _confirmAttendance,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: Text(
                      _saving
                          ? 'Saving Attendance...'
                          : 'Confirm Attendance',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                SelectableText(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
