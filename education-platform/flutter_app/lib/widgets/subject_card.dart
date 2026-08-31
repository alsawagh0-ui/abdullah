import 'package:flutter/material.dart';

import '../models/subject_model.dart';

/// بطاقة تعرض مادة دراسية واحدة داخل لوحة التحكم: الأيقونة، الاسم،
/// اسم المعلّم، عدد الدروس، وشريط تقدّم بصري لنسبة إنجاز الطالب فيها.
class SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onTap;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _SubjectIcon(icon: subject.icon, color: subject.color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject.teacherName,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    _ProgressRow(subject: subject),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SubjectIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final SubjectModel subject;

  const _ProgressRow({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: subject.progress,
              minHeight: 6,
              backgroundColor: subject.color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(subject.color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(subject.progress * 100).round()}%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subject.color),
        ),
      ],
    );
  }
}
