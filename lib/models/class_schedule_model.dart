/// Model class for schedule instances from Supabase
class ClassScheduleModel {
  final String id;
  final String discipline;
  final String disciplineDisplayName;
  final String disciplineColor;
  final String instructorName;
  final String instructorEmail;
  final String instructorBio;
  final String timeRange;
  final String dateFormatted;
  final int capacity;
  final int enrolled;
  final bool isBooked;
  final int? waitlistPosition;
  final String description;
  final String location;
  final bool isCancelled;
  final String? cancellationReason;
  final bool isHolidayAffected;
  final bool isModified;
  final String? updatedAt;
  final String startTime;
  final String endTime;
  final String classDate;
  final bool isFromTemplate;
  final String? templateId;

  ClassScheduleModel({
    required this.id,
    required this.discipline,
    required this.disciplineDisplayName,
    this.disciplineColor = '#757575',
    required this.instructorName,
    required this.instructorEmail,
    required this.instructorBio,
    required this.timeRange,
    required this.dateFormatted,
    required this.capacity,
    required this.enrolled,
    required this.isBooked,
    this.waitlistPosition,
    required this.description,
    required this.location,
    required this.isCancelled,
    this.cancellationReason,
    required this.isHolidayAffected,
    required this.isModified,
    this.updatedAt,
    required this.startTime,
    required this.endTime,
    required this.classDate,
    this.isFromTemplate = false,
    this.templateId,
  });

  bool get hasAvailableSpots => enrolled < capacity && !isCancelled;
  bool get isFull => enrolled >= capacity && !isCancelled;
  int get availableSpots => capacity - enrolled;

  // Helper to determine if class has admin modifications
  bool get hasAdminModifications =>
      isCancelled || isHolidayAffected || isModified;

  factory ClassScheduleModel.fromJson(Map<String, dynamic> json) {
    // Extract instructor name with explicit logging
    final instructorNameFromJson =
        json['instructor_name'] ?? json['instructorName'];
    final finalInstructorName =
        instructorNameFromJson ?? 'Istruttore Disponibile';

    // Debug logging
    if (instructorNameFromJson == null ||
        instructorNameFromJson == 'Istruttore Disponibile') {
      print(
        '⚠️ Warning: No instructor assigned for class ${json['id']} (${json['discipline']})',
      );
      print('   instructor_name field: ${json['instructor_name']}');
      print('   instructorName field: ${json['instructorName']}');
    }

    return ClassScheduleModel(
      id: json['id'] ?? '',
      discipline: json['discipline'] ?? 'bjj',
      disciplineDisplayName:
          (json['discipline_display_name']?.toString().trim().isNotEmpty == true
              ? json['discipline_display_name'].toString().trim()
              : null) ??
          (json['disciplineDisplayName']?.toString().trim().isNotEmpty == true
              ? json['disciplineDisplayName'].toString().trim()
              : null) ??
          _mapDbValueToUI(json['discipline'] ?? 'bjj'),
      disciplineColor:
          (json['discipline_color']?.toString().trim().isNotEmpty == true
              ? json['discipline_color'].toString().trim()
              : null) ??
          _getDefaultColor(json['discipline'] ?? 'bjj'),
      instructorName: finalInstructorName,
      instructorEmail:
          json['instructor_email'] ?? json['instructorEmail'] ?? '',
      instructorBio:
          json['instructor_bio'] ??
          json['instructorBio'] ??
          'Istruttore esperto con anni di esperienza',
      timeRange:
          json['time_range'] ??
          json['timeRange'] ??
          '${json['start_time'] ?? '00:00'} - ${json['end_time'] ?? '01:00'}',
      dateFormatted:
          json['date_formatted'] ??
          json['dateFormatted'] ??
          _formatDate(json['class_date'] ?? DateTime.now().toIso8601String()),
      capacity: json['capacity'] ?? json['max_capacity'] ?? 20,
      enrolled: json['enrolled'] ?? 0,
      isBooked: json['is_booked'] ?? json['isBooked'] ?? false,
      waitlistPosition: json['waitlist_position'] ?? json['waitlistPosition'],
      description: json['description'] ?? 'Classe di allenamento',
      location: json['location'] ?? 'Palestra',
      isCancelled: json['is_cancelled'] ?? json['isCancelled'] ?? false,
      cancellationReason:
          json['cancellation_reason'] ?? json['cancellationReason'],
      isHolidayAffected:
          json['is_holiday_affected'] ?? json['isHolidayAffected'] ?? false,
      isModified: json['is_modified'] ?? json['isModified'] ?? false,
      updatedAt: json['updated_at'] ?? json['updatedAt'],
      startTime: json['start_time'] ?? json['startTime'] ?? '00:00',
      endTime: json['end_time'] ?? json['endTime'] ?? '01:00',
      classDate:
          json['class_date'] ??
          json['classDate'] ??
          DateTime.now().toIso8601String().split('T')[0],
      isFromTemplate:
          json['is_from_template'] ?? json['isFromTemplate'] ?? false,
      templateId: json['template_id'] ?? json['templateId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'discipline': discipline,
      'disciplineDisplayName': disciplineDisplayName,
      'discipline_color': disciplineColor,
      'instructor_name': instructorName,
      'instructor_email': instructorEmail,
      'instructor_bio': instructorBio,
      'time_range': timeRange,
      'date_formatted': dateFormatted,
      'capacity': capacity,
      'enrolled': enrolled,
      'is_booked': isBooked,
      'waitlist_position': waitlistPosition,
      'description': description,
      'location': location,
      'is_cancelled': isCancelled,
      'cancellation_reason': cancellationReason,
      'is_holiday_affected': isHolidayAffected,
      'is_modified': isModified,
      'updated_at': updatedAt,
      'start_time': startTime,
      'end_time': endTime,
      'class_date': classDate,
      'is_from_template': isFromTemplate,
      'template_id': templateId,
    };
  }

  ClassScheduleModel copyWith({
    String? id,
    String? discipline,
    String? disciplineDisplayName,
    String? disciplineColor,
    String? instructorName,
    String? instructorEmail,
    String? instructorBio,
    String? timeRange,
    String? dateFormatted,
    int? capacity,
    int? enrolled,
    bool? isBooked,
    int? waitlistPosition,
    String? description,
    String? location,
    bool? isCancelled,
    String? cancellationReason,
    bool? isHolidayAffected,
    bool? isModified,
    String? updatedAt,
    String? startTime,
    String? endTime,
    String? classDate,
    bool? isFromTemplate,
    String? templateId,
  }) {
    return ClassScheduleModel(
      id: id ?? this.id,
      discipline: discipline ?? this.discipline,
      disciplineDisplayName:
          disciplineDisplayName ?? this.disciplineDisplayName,
      disciplineColor: disciplineColor ?? this.disciplineColor,
      instructorName: instructorName ?? this.instructorName,
      instructorEmail: instructorEmail ?? this.instructorEmail,
      instructorBio: instructorBio ?? this.instructorBio,
      timeRange: timeRange ?? this.timeRange,
      dateFormatted: dateFormatted ?? this.dateFormatted,
      capacity: capacity ?? this.capacity,
      enrolled: enrolled ?? this.enrolled,
      isBooked: isBooked ?? this.isBooked,
      waitlistPosition: waitlistPosition ?? this.waitlistPosition,
      description: description ?? this.description,
      location: location ?? this.location,
      isCancelled: isCancelled ?? this.isCancelled,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isHolidayAffected: isHolidayAffected ?? this.isHolidayAffected,
      isModified: isModified ?? this.isModified,
      updatedAt: updatedAt ?? this.updatedAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      classDate: classDate ?? this.classDate,
      isFromTemplate: isFromTemplate ?? this.isFromTemplate,
      templateId: templateId ?? this.templateId,
    );
  }

  static String _mapDbValueToUI(String dbDiscipline) {
    switch (dbDiscipline.toLowerCase()) {
      case 'bjj':
        return 'BJJ';
      case 'mma':
        return 'MMA';
      case 'sambo':
        return 'Sambo';
      case 'grappling':
        return 'Grappling';
      case 'fitness':
        return 'Prep. Atletica';
      default:
        return dbDiscipline;
    }
  }

  static String _getDefaultColor(String dbDiscipline) {
    switch (dbDiscipline.toLowerCase()) {
      case 'bjj':
        return '#1565C0';
      case 'mma':
        return '#D32F2F';
      case 'sambo':
        return '#1976D2';
      case 'grappling':
        return '#7B1FA2';
      case 'fitness':
        return '#E65100';
      default:
        return '#757575';
    }
  }

  static String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
