import '../models/student_data.dart';
import '../models/attendance_subject.dart';
import '../models/performance_subject.dart';

const StudentData student = StudentData(
  name: 'Likhith M',
  email: 'likhith.0037@gmail.com',
  usn: '1VA23CD044',
  department: 'Computer Science and Data Science',
  semester: 6,
  attendancePercentage: 85,
  performancePercentage: 78,
);

const List<AttendanceSubject> attendanceSubjects = [
  AttendanceSubject(
    name: 'Mathematics',
    attendedClasses: 34,
    totalClasses: 40,
  ),
  AttendanceSubject(
    name: 'Data Structures',
    attendedClasses: 36,
    totalClasses: 40,
  ),
  AttendanceSubject(
    name: 'Database Management',
    attendedClasses: 30,
    totalClasses: 40,
  ),
  AttendanceSubject(
    name: 'Computer Networks',
    attendedClasses: 32,
    totalClasses: 40,
  ),
];

const List<PerformanceSubject> performanceSubjects = [
  PerformanceSubject(
    name: 'Mathematics',
    marksObtained: 78,
    totalMarks: 100,
  ),
  PerformanceSubject(
    name: 'Data Structures',
    marksObtained: 85,
    totalMarks: 100,
  ),
  PerformanceSubject(
    name: 'Database Management',
    marksObtained: 72,
    totalMarks: 100,
  ),
  PerformanceSubject(
    name: 'Computer Networks',
    marksObtained: 77,
    totalMarks: 100,
  ),
];