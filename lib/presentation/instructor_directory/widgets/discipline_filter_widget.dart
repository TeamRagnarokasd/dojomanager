import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class DisciplineFilterWidget extends StatelessWidget {
  final List<String> disciplines;
  final List<String> selectedDisciplines;
  final Function(List<String>) onSelectionChanged;

  const DisciplineFilterWidget({
    super.key,
    required this.disciplines,
    required this.selectedDisciplines,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: disciplines.map((discipline) {
          final isSelected = selectedDisciplines.contains(discipline);
          final disciplineColor = _getDisciplineColor(discipline);

          return Container(
            margin: EdgeInsets.only(right: 2.w),
            child: GestureDetector(
              onTap: () {
                final newSelection = List<String>.from(selectedDisciplines);
                if (isSelected) {
                  newSelection.remove(discipline);
                } else {
                  newSelection.add(discipline);
                }
                onSelectionChanged(newSelection);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.w),
                decoration: BoxDecoration(
                  color: isSelected ? disciplineColor : Colors.grey[800],
                  borderRadius: BorderRadius.circular(25),
                  border:
                      isSelected ? null : Border.all(color: Colors.grey[700]!),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: disciplineColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      CustomIconWidget(
                        iconName: 'check',
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 1.w),
                    ],
                    Text(
                      discipline,
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: isSelected ? Colors.white : Colors.grey[300],
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getDisciplineColor(String discipline) {
    switch (discipline) {
      case 'BJJ':
        return const Color(0xFF2196F3);
      case 'MMA':
        return const Color(0xFFFF5722);
      case 'SAMBO':
        return const Color(0xFF4CAF50);
      case 'Grappling':
        return const Color(0xFF9C27B0);
      default:
        return Colors.grey;
    }
  }
}
