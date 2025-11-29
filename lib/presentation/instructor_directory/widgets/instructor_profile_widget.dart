import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/instructor_service.dart';
import '../../../theme/app_theme.dart';

class InstructorProfileWidget extends StatelessWidget {
  final InstructorProfile instructor;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback onClose;

  const InstructorProfileWidget({
    super.key,
    required this.instructor,
    this.canEdit = false,
    this.onEdit,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90.h,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header with close button
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Profilo Istruttore',
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                if (canEdit && onEdit != null) ...[
                  IconButton(
                    icon: Icon(Icons.edit, color: const Color(0xFFFF0000)),
                    onPressed: onEdit,
                  ),
                  SizedBox(width: 2.w),
                ],
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image and Basic Info
                  _buildHeaderSection(),
                  SizedBox(height: 3.h),

                  // Bio Section
                  if (instructor.bio != null) ...[
                    _buildBioSection(),
                    SizedBox(height: 3.h),
                  ],

                  // Disciplines and Specializations
                  _buildSkillsSection(),
                  SizedBox(height: 3.h),

                  // Combined Results, Recognitions and Certifications Section
                  if (instructor.certifications.isNotEmpty ||
                      instructor.achievements.isNotEmpty) ...[
                    _buildCombinedAchievementsAndCertificationsSection(),
                    SizedBox(height: 3.h),
                  ],

                  // Languages
                  if (instructor.languages.isNotEmpty) ...[
                    _buildLanguagesSection(),
                    SizedBox(height: 3.h),
                  ],

                  // Contact Info
                  if (instructor.contactInfo != null &&
                      instructor.contactInfo!.isNotEmpty) ...[
                    _buildContactSection(),
                    SizedBox(height: 3.h),
                  ],

                  // Student Testimonials
                  if (instructor.studentTestimonials != null &&
                      instructor.studentTestimonials!.isNotEmpty) ...[
                    _buildTestimonialsSection(),
                    SizedBox(height: 3.h),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Image
        Container(
          width: 25.w,
          height: 25.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF0000).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: instructor.displayImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: instructor.displayImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFFFF0000)),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[800],
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                  ),
          ),
        ),

        SizedBox(width: 4.w),

        // Basic Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instructor.fullName ?? 'Nome non disponibile',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 1.h),

              if (instructor.yearsExperience != null)
                Text(
                  instructor.experienceText,
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFFF0000),
                    fontWeight: FontWeight.w600,
                  ),
                ),

              SizedBox(height: 1.h),

              // Primary Discipline
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  instructor.primaryDiscipline.toUpperCase(),
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFF0000),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (instructor.joinDate != null) ...[
                SizedBox(height: 1.h),
                Text(
                  'Dal ${instructor.joinDate!.day}/${instructor.joinDate!.month}/${instructor.joinDate!.year}',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],

              // Activity Status
              if (!instructor.isActive) ...[
                SizedBox(height: 1.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'NON ATTIVO',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection() {
    return _buildSection(
      title: 'Biografia',
      icon: Icons.person_outline,
      child: Text(
        instructor.bio!,
        style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
          color: Colors.grey[300],
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    return _buildSection(
      title: 'Discipline e Specializzazioni',
      icon: Icons.sports_martial_arts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // All Disciplines
          Text(
            'Discipline:',
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: instructor.disciplines.map((discipline) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  discipline.toUpperCase(),
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFF0000),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),

          if (instructor.specializations.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              'Specializzazioni:',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            ...instructor.specializations.map((specialization) {
              return Padding(
                padding: EdgeInsets.only(bottom: 0.5.h),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        specialization,
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildCombinedAchievementsAndCertificationsSection() {
    return _buildSection(
      title: 'Risultati Riconoscimenti e Certificazioni',
      icon: Icons.emoji_events,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Achievements section
          if (instructor.achievements.isNotEmpty) ...[
            Text(
              'Risultati e Riconoscimenti:',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            ...instructor.achievements.map((achievement) {
              return Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 16,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        achievement,
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],

          // Spacing between sections if both exist
          if (instructor.achievements.isNotEmpty &&
              instructor.certifications.isNotEmpty) ...[
            SizedBox(height: 2.h),
          ],

          // Certifications section
          if (instructor.certifications.isNotEmpty) ...[
            Text(
              'Certificazioni:',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            ...instructor.certifications.map((certification) {
              return Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 16,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        certification,
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguagesSection() {
    return _buildSection(
      title: 'Lingue',
      icon: Icons.language,
      child: Text(
        instructor.languagesText,
        style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
          color: Colors.grey[300],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return _buildSection(
      title: 'Informazioni di Contatto',
      icon: Icons.contact_mail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: instructor.contactInfo!.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: 1.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.key}:',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${entry.value}',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTestimonialsSection() {
    return _buildSection(
      title: 'Testimonianze Studenti',
      icon: Icons.format_quote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: instructor.studentTestimonials!.map((testimonial) {
          final testimon = Map<String, dynamic>.from(testimonial);
          return Container(
            margin: EdgeInsets.only(bottom: 2.h),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      testimon['student'] ?? '',
                      style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Row(
                      children: List.generate(5, (index) {
                        final rating = testimon['rating'] ?? 0;
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  testimon['comment'] ?? '',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[300],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFFFF0000),
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                title,
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          child,
        ],
      ),
    );
  }
}
