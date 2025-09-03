import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class InstructorProfileWidget extends StatefulWidget {
  final Map<String, dynamic> instructor;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback onClose;

  const InstructorProfileWidget({
    super.key,
    required this.instructor,
    required this.canEdit,
    this.onEdit,
    required this.onClose,
  });

  @override
  State<InstructorProfileWidget> createState() =>
      _InstructorProfileWidgetState();
}

class _InstructorProfileWidgetState extends State<InstructorProfileWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90.h,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header with profile image and basic info
          _buildProfileHeader(),

          // Tab navigation
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[800]!, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFFF0000),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[400],
              tabs: const [
                Tab(text: 'Profilo'),
                Tab(text: 'Orari'),
                Tab(text: 'Recensioni'),
                Tab(text: 'Contatti'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildScheduleTab(),
                _buildReviewsTab(),
                _buildContactTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final primaryDiscipline = widget.instructor['primaryDiscipline'] as String;
    final disciplineColor = _getDisciplineColor(primaryDiscipline);

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            disciplineColor.withValues(alpha: 0.3),
            Colors.black,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Close button and edit button
          Row(
            children: [
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    shape: BoxShape.circle,
                  ),
                  child: CustomIconWidget(
                    iconName: 'close',
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.canEdit && widget.onEdit != null)
                GestureDetector(
                  onTap: widget.onEdit,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: 'edit',
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          'Modifica',
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 3.h),

          // Profile image and basic info
          Row(
            children: [
              // Profile image
              Container(
                width: 25.w,
                height: 25.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: disciplineColor,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: disciplineColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CustomImageWidget(
                    imageUrl: widget.instructor['profileImage'],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 4.w),

              // Name and basic info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.instructor['name'],
                      style:
                          AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.w),
                    Text(
                      'Istruttore ${widget.instructor['primaryDiscipline']}',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: disciplineColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 1.w),
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'star',
                          color: Colors.amber,
                          size: 16,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          widget.instructor['experience'],
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            color: Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),

          // Disciplines
          Wrap(
            spacing: 2.w,
            runSpacing: 1.w,
            children: (widget.instructor['disciplines'] as List<String>)
                .map((discipline) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 1.w,
                      ),
                      decoration: BoxDecoration(
                        color: _getDisciplineColor(discipline),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _getDisciplineColor(discipline)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        discipline,
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio section
          _buildSection(
            'Biografia',
            widget.instructor['bio'],
            Icons.person,
          ),
          SizedBox(height: 3.h),

          // Achievements section
          _buildListSection(
            'Risultati',
            widget.instructor['achievements'],
            Icons.emoji_events,
          ),
          SizedBox(height: 3.h),

          // Certifications section
          _buildListSection(
            'Certificazioni',
            widget.instructor['certifications'],
            Icons.military_tech,
          ),
          SizedBox(height: 3.h),

          // Specializations section
          _buildChipsSection(
            'Specializzazioni',
            widget.instructor['specializations'],
            Icons.psychology,
          ),
          SizedBox(height: 3.h),

          // Languages section
          _buildChipsSection(
            'Lingue',
            widget.instructor['languages'],
            Icons.language,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    final schedule = widget.instructor['schedule'] as Map<String, List<String>>;

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orario Settimanale',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          ...schedule.entries.map((entry) {
            final day = entry.key;
            final classes = entry.value;

            return Container(
              margin: EdgeInsets.only(bottom: 3.h),
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day,
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFFF0000),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  ...classes
                      .map((classInfo) => Container(
                            margin: EdgeInsets.only(bottom: 1.h),
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                CustomIconWidget(
                                  iconName: 'schedule',
                                  color: Colors.grey[400]!,
                                  size: 16,
                                ),
                                SizedBox(width: 2.w),
                                Text(
                                  classInfo,
                                  style: AppTheme
                                      .lightTheme.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    final testimonials =
        widget.instructor['studentTestimonials'] as List<Map<String, dynamic>>;

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recensioni Studenti',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          if (testimonials.isEmpty)
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Nessuna recensione disponibile',
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
              ),
            )
          else
            ...testimonials
                .map((testimonial) => Container(
                      margin: EdgeInsets.only(bottom: 3.h),
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                testimonial['student'],
                                style: AppTheme.lightTheme.textTheme.titleSmall
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: List.generate(
                                    5,
                                    (index) => Icon(
                                          index < testimonial['rating']
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 16,
                                        )),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.w),
                          Text(
                            testimonial['comment'],
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    final contactInfo = widget.instructor['contactInfo'] as Map<String, String>;
    final socialMedia = widget.instructor['socialMedia'] as Map<String, String>;

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informazioni di Contatto',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),

          // Contact info
          ...contactInfo.entries
              .map((entry) => Container(
                    margin: EdgeInsets.only(bottom: 2.h),
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: _getContactIcon(entry.key),
                          color: const Color(0xFFFF0000),
                          size: 20,
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getContactLabel(entry.key),
                                style: AppTheme.lightTheme.textTheme.bodySmall
                                    ?.copyWith(
                                  color: Colors.grey[400],
                                ),
                              ),
                              Text(
                                entry.value,
                                style: AppTheme.lightTheme.textTheme.bodyMedium
                                    ?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),

          SizedBox(height: 2.h),

          // Social media
          if (socialMedia.isNotEmpty) ...[
            Text(
              'Social Media',
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            ...socialMedia.entries
                .map((entry) => Container(
                      margin: EdgeInsets.only(bottom: 2.h),
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Row(
                        children: [
                          CustomIconWidget(
                            iconName: _getSocialIcon(entry.key),
                            color: _getSocialColor(entry.key),
                            size: 20,
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key.toUpperCase(),
                                  style: AppTheme.lightTheme.textTheme.bodySmall
                                      ?.copyWith(
                                    color: Colors.grey[400],
                                  ),
                                ),
                                Text(
                                  entry.value,
                                  style: AppTheme
                                      .lightTheme.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CustomIconWidget(
              iconName: 'person',
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
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Text(
            content,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[300],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(String title, List<String> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CustomIconWidget(
              iconName: title == 'Risultati' ? 'emoji_events' : 'military_tech',
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
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map((item) => Container(
                      margin: EdgeInsets.only(bottom: 1.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 1.w),
                            width: 1.5.w,
                            height: 1.5.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF0000),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Text(
                              item,
                              style: AppTheme.lightTheme.textTheme.bodyMedium
                                  ?.copyWith(
                                color: Colors.grey[300],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChipsSection(String title, List<String> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CustomIconWidget(
              iconName: title == 'Specializzazioni' ? 'psychology' : 'language',
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
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Wrap(
            spacing: 2.w,
            runSpacing: 2.w,
            children: items
                .map((item) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 1.5.w,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF0000).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        item,
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFF0000),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
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

  String _getContactIcon(String key) {
    switch (key) {
      case 'phone':
        return 'phone';
      case 'email':
        return 'email';
      case 'availability':
        return 'schedule';
      case 'seminars':
        return 'event_note';
      default:
        return 'info';
    }
  }

  String _getContactLabel(String key) {
    switch (key) {
      case 'phone':
        return 'Telefono';
      case 'email':
        return 'Email';
      case 'availability':
        return 'Disponibilità';
      case 'seminars':
        return 'Seminari';
      default:
        return key;
    }
  }

  String _getSocialIcon(String platform) {
    switch (platform) {
      case 'instagram':
        return 'camera_alt';
      case 'facebook':
        return 'facebook';
      case 'youtube':
        return 'play_circle';
      default:
        return 'link';
    }
  }

  Color _getSocialColor(String platform) {
    switch (platform) {
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'youtube':
        return const Color(0xFFFF0000);
      default:
        return Colors.grey;
    }
  }
}