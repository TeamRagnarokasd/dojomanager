import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/instructor_service.dart';

class InstructorCardWidget extends StatelessWidget {
  final InstructorProfile instructor;
  final VoidCallback onTap;
  final bool canEdit;
  final VoidCallback? onEdit;

  const InstructorCardWidget({
    super.key,
    required this.instructor,
    required this.onTap,
    this.canEdit = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: instructor.isActive
                ? const Color(0xFFFF0000).withValues(alpha: 0.3)
                : Colors.grey[800]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image Section
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  color: Colors.grey[800],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Profile Image
                      instructor.displayImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: instructor.displayImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[800],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      const Color(0xFFFF0000),
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildPlaceholderImage(),
                            )
                          : _buildPlaceholderImage(),

                      // Active/Inactive Overlay
                      if (!instructor.isActive)
                        Container(
                          color: Colors.black.withValues(alpha: 0.7),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pause_circle_outline,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  'Non Attivo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Edit Button (Admin Only)
                      if (canEdit && onEdit != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onEdit,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Content Section — fixed height, never expands
            SizedBox(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Role Title
                    if (instructor.roleTitle != null &&
                        instructor.roleTitle!.isNotEmpty)
                      Text(
                        instructor.roleTitle!,
                        style: const TextStyle(
                          color: Color(0xFFFF0000),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Name
                    Text(
                      instructor.fullName ?? 'Nome non disponibile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Experience
                    if (instructor.yearsExperience != null)
                      Text(
                        instructor.experienceText,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 4),

                    // First discipline chip
                    if (instructor.disciplines.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                const Color(0xFFFF0000).withValues(alpha: 0.5),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          instructor.disciplines.first.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFFF0000),
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 40, color: Colors.grey[600]),
          SizedBox(height: 1.h),
          Text(
            'Foto non\ndisponibile',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}
