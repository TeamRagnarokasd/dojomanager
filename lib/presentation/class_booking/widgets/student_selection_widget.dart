import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class StudentSelectionWidget extends StatelessWidget {
  final String? selectedStudentId;
  final Function(String) onStudentSelected;

  const StudentSelectionWidget({
    Key? key,
    required this.selectedStudentId,
    required this.onStudentSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock student data
    final students = [
      {'id': 'student1', 'name': 'Mario Rossi', 'level': 'Intermedio'},
      {'id': 'student2', 'name': 'Giulia Bianchi', 'level': 'Principiante'},
    ];

    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seleziona Studente',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16.h),
          ...students.map((student) => _buildStudentOption(student)),
        ],
      ),
    );
  }

  Widget _buildStudentOption(Map<String, dynamic> student) {
    final isSelected = selectedStudentId == student['id'];

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      child: RadioListTile<String>(
        value: student['id'],
        groupValue: selectedStudentId,
        onChanged: (value) => onStudentSelected(value!),
        title: Text(
          student['name'],
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          'Livello: ${student['level']}',
          style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey[400]),
        ),
        activeColor: Colors.red,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
