class AttendanceSubject {
  final String name;
  final int attendedClasses;
  final int totalClasses;

  const AttendanceSubject({
    required this.name,
    required this.attendedClasses,
    required this.totalClasses,
  });

  int get percentage {
    return ((attendedClasses / totalClasses) * 100).round();
  }
}