import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class InstructorCardWidget extends StatelessWidget {
  final Map<String, dynamic> instructor;
  final VoidCallback onTap;
  final bool canEdit;
  final VoidCallback? onEdit;

  const InstructorCardWidget({
    super.key,
    required this.instructor,
    required this.onTap,
    required this.canEdit,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final primaryDiscipline = instructor['primaryDiscipline'] as String;
    final disciplineColor = _getDisciplineColor(primaryDiscipline);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: disciplineColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile image with discipline indicator
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CustomImageWidget(
                    imageUrl: instructor['profileImage'],
                    height: 20.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 3.w,
                  right: 3.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.w),
                    decoration: BoxDecoration(
                      color: disciplineColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      primaryDiscipline,
                      style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (canEdit && onEdit != null)
                  Positioned(
                    top: 3.w,
                    left: 3.w,
                    child: GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: CustomIconWidget(
                          iconName: 'edit',
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Instructor information
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(3.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      instructor['name'],
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1.w),

                    // Experience
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'star',
                          color: Colors.amber,
                          size: 14,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          instructor['experience'],
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.w),

                    // Disciplines chips
                    Wrap(
                      spacing: 1.w,
                      runSpacing: 1.w,
                      children: (instructor['disciplines'] as List<String>)
                          .take(3)
                          .map((discipline) => Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 2.w,
                                  vertical: 0.5.w,
                                ),
                                decoration: BoxDecoration(
                                  color: _getDisciplineColor(discipline)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getDisciplineColor(discipline)
                                        .withValues(alpha: 0.5),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  discipline,
                                  style: AppTheme
                                      .lightTheme.textTheme.labelSmall
                                      ?.copyWith(
                                    color: _getDisciplineColor(discipline),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),

                    const Spacer(),

                    // Specializations
                    Text(
                      (instructor['specializations'] as List<String>)
                          .take(2)
                          .join(' • '),
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.w),

                    // View profile indicator
                    Row(
                      children: [
                        Text(
                          'Visualizza Profilo',
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFFF0000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        CustomIconWidget(
                          iconName: 'arrow_forward_ios',
                          color: const Color(0xFFFF0000),
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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