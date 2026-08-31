import 'package:flutter/material.dart';

/// يمثّل مادة دراسية مقررة على الطالب، وتُعرض كبطاقة في لوحة التحكم.
class SubjectModel {
  final String id;
  final String name;
  final String teacherName;
  final int lessonsCount;
  final double progress; // من 0.0 إلى 1.0 — نسبة إنجاز الطالب في المادة
  final IconData icon;
  final Color color;

  const SubjectModel({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.lessonsCount,
    required this.progress,
    required this.icon,
    required this.color,
  });
}
