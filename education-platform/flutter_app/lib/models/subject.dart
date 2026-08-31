class Subject {
  final String id;
  final String name;
  final String gradeLevel;

  Subject({required this.id, required this.name, required this.gradeLevel});

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      gradeLevel: json['grade_level'] as String,
    );
  }
}

class LessonSummary {
  final String id;
  final String title;
  final String status; // pending | processing | ready | failed

  LessonSummary({required this.id, required this.title, required this.status});

  factory LessonSummary.fromJson(Map<String, dynamic> json) {
    return LessonSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
    );
  }
}
