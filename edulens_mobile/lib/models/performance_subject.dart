class PerformanceSubject {
  final String name;
  final int marksObtained;
  final int totalMarks;

  const PerformanceSubject({
    required this.name,
    required this.marksObtained,
    required this.totalMarks,
  });

  int get percentage {
    return ((marksObtained / totalMarks) * 100).round();
  }

  String get grade {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    return 'F';
  }
}