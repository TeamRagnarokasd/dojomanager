import 'package:supabase_flutter/supabase_flutter.dart';

/// "Registra presenza fuori calendario" reason keys, in menu order, and
/// their Italian labels.
const List<String> kWorkPresenceReasonKeys = [
  'lezione',
  'supervisione_tecnica',
  'stage',
  'gara',
  'altro',
];

const Map<String, String> kWorkPresenceReasonLabels = {
  'lezione': 'Lezione',
  'supervisione_tecnica': 'Supervisione tecnica',
  'stage': 'Stage',
  'gara': 'Gara',
  'altro': 'Altro',
};

String workPresenceReasonLabel(String key) => kWorkPresenceReasonLabels[key] ?? key;

/// `work_settings` rows, minus `work_instructor_user_id` (never shown or
/// editable from the app).
class WorkSettings {
  const WorkSettings({
    required this.annualLimit,
    required this.incomeBeforeContract,
    required this.incomeBeforeContractYear,
    required this.mealVoucherValue,
    required this.kmRoundTrip,
    required this.kmRate,
    this.aciUrl,
    this.vehicle,
    this.routeFrom,
    this.routeTo,
  });

  final double annualLimit;
  final double incomeBeforeContract;
  final int incomeBeforeContractYear;
  final double mealVoucherValue;
  final double kmRoundTrip;
  final double kmRate;
  final String? aciUrl;
  final String? vehicle;
  final String? routeFrom;
  final String? routeTo;

  factory WorkSettings.fromMap(Map<String, String> map) {
    double parseNum(String key) => double.tryParse(map[key] ?? '') ?? 0;
    int parseInt(String key) => int.tryParse(map[key] ?? '') ?? DateTime.now().year;
    return WorkSettings(
      annualLimit: parseNum('work_annual_limit'),
      incomeBeforeContract: parseNum('work_income_before_contract'),
      incomeBeforeContractYear: parseInt('work_income_before_contract_year'),
      mealVoucherValue: parseNum('work_meal_voucher_value'),
      kmRoundTrip: parseNum('work_km_round_trip'),
      kmRate: parseNum('work_km_rate'),
      aciUrl: map['work_aci_url'],
      vehicle: map['work_vehicle'],
      routeFrom: map['work_route_from'],
      routeTo: map['work_route_to'],
    );
  }
}

/// One row of `work_rate_periods` — valid from its date until the next
/// period's date (or forever, if it's the last one). Never changes the past.
class WorkRatePeriod {
  const WorkRatePeriod({
    required this.validFrom,
    required this.hourlyRate,
    required this.paidLessonsPerWeek,
    required this.hoursPerLesson,
    this.note,
  });

  final DateTime validFrom;
  final double hourlyRate;
  final int paidLessonsPerWeek;
  final double hoursPerLesson;
  final String? note;

  factory WorkRatePeriod.fromMap(Map<String, dynamic> map) => WorkRatePeriod(
        validFrom: DateTime.parse(map['valid_from'] as String),
        hourlyRate: (map['hourly_rate'] as num).toDouble(),
        paidLessonsPerWeek: (map['paid_lessons_per_week'] as num).toInt(),
        hoursPerLesson: (map['hours_per_lesson'] as num).toDouble(),
        note: map['note'] as String?,
      );
}

/// One entry of `work_compensation_summary`'s `monthly` array.
class WorkMonthlyAmount {
  const WorkMonthlyAmount({
    required this.month,
    required this.lessons,
    required this.amount,
  });

  final int month;
  final int lessons;
  final double amount;

  factory WorkMonthlyAmount.fromMap(Map<String, dynamic> map) => WorkMonthlyAmount(
        month: (map['month'] as num).toInt(),
        lessons: (map['lessons'] as num).toInt(),
        amount: (map['amount'] as num).toDouble(),
      );
}

/// Everything `work_compensation_summary(p_year)` returns — every number
/// here is computed server-side from the authorization (paid lessons/week
/// x hours x the rate in force), never recomputed in the app.
class WorkCompensationSummary {
  const WorkCompensationSummary({
    required this.year,
    required this.hourlyRate,
    required this.paidLessonsPerWeek,
    required this.hoursPerLesson,
    required this.periods,
    required this.annualLimit,
    required this.alreadyReceivedBeforeContract,
    required this.accruedLessons,
    required this.accruedAmount,
    required this.totalToDate,
    required this.plannedLessons,
    required this.plannedAmount,
    required this.projectedYearEnd,
    required this.remainingToLimitNow,
    required this.marginAtYearEnd,
    this.calendarCoversUntil,
    required this.weeksLeftWithLessons,
    required this.monthly,
  });

  final int year;

  /// The rate period in force (today, or at year end if the year is over).
  final double hourlyRate;
  final int paidLessonsPerWeek;
  final double hoursPerLesson;
  final List<WorkRatePeriod> periods;

  final double annualLimit;
  final double alreadyReceivedBeforeContract;
  final int accruedLessons;
  final double accruedAmount;
  final double totalToDate;
  final int plannedLessons;
  final double plannedAmount;
  final double projectedYearEnd;
  final double remainingToLimitNow;
  final double marginAtYearEnd;
  final DateTime? calendarCoversUntil;
  final int weeksLeftWithLessons;
  final List<WorkMonthlyAmount> monthly;

  bool get isOverLimitAtYearEnd => marginAtYearEnd < 0;

  factory WorkCompensationSummary.fromMap(Map<String, dynamic> map) {
    double asDouble(String key) => (map[key] as num?)?.toDouble() ?? 0;
    int asInt(String key) => (map[key] as num?)?.toInt() ?? 0;
    return WorkCompensationSummary(
      year: asInt('year'),
      hourlyRate: asDouble('hourly_rate'),
      paidLessonsPerWeek: asInt('paid_lessons_per_week'),
      hoursPerLesson: asDouble('hours_per_lesson'),
      periods: ((map['periods'] as List?) ?? const [])
          .map((e) => WorkRatePeriod.fromMap(e as Map<String, dynamic>))
          .toList(),
      annualLimit: asDouble('annual_limit'),
      alreadyReceivedBeforeContract: asDouble('already_received_before_contract'),
      accruedLessons: asInt('accrued_lessons'),
      accruedAmount: asDouble('accrued_amount'),
      totalToDate: asDouble('total_to_date'),
      plannedLessons: asInt('planned_lessons'),
      plannedAmount: asDouble('planned_amount'),
      projectedYearEnd: asDouble('projected_year_end'),
      remainingToLimitNow: asDouble('remaining_to_limit_now'),
      marginAtYearEnd: asDouble('margin_at_year_end'),
      calendarCoversUntil: map['calendar_covers_until'] == null
          ? null
          : DateTime.parse(map['calendar_covers_until'] as String),
      weeksLeftWithLessons: asInt('weeks_left_with_lessons'),
      monthly: ((map['monthly'] as List?) ?? const [])
          .map((e) => WorkMonthlyAmount.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Everything `work_presence_summary(p_year)` returns — one meal voucher
/// and one km reimbursement per DAY with at least one confirmed presence,
/// computed server-side.
class WorkPresenceSummary {
  const WorkPresenceSummary({
    required this.year,
    required this.days,
    required this.voucherValue,
    required this.voucherTotal,
    required this.kmRoundTrip,
    required this.kmTotal,
    required this.kmRate,
    required this.kmAmount,
  });

  final int year;
  final int days;
  final double voucherValue;
  final double voucherTotal;
  final double kmRoundTrip;
  final double kmTotal;
  final double kmRate;
  final double kmAmount;

  factory WorkPresenceSummary.fromMap(Map<String, dynamic> map) {
    double asDouble(String key) => (map[key] as num?)?.toDouble() ?? 0;
    int asInt(String key) => (map[key] as num?)?.toInt() ?? 0;
    return WorkPresenceSummary(
      year: asInt('year'),
      days: asInt('days'),
      voucherValue: asDouble('voucher_value'),
      voucherTotal: asDouble('voucher_total'),
      kmRoundTrip: asDouble('km_round_trip'),
      kmTotal: asDouble('km_total'),
      kmRate: asDouble('km_rate'),
      kmAmount: asDouble('km_amount'),
    );
  }
}

/// One row of `instructor_presences`, for the recorded-presences list.
class WorkPresenceEntry {
  const WorkPresenceEntry({
    required this.id,
    required this.presenceDate,
    required this.status,
    required this.source,
    this.reason,
    this.notes,
    this.scheduleInstanceId,
  });

  final String id;
  final DateTime presenceDate;

  /// 'confirmed' | 'declined'.
  final String status;

  /// 'calendar' | 'manual'.
  final String source;
  final String? reason;
  final String? notes;
  final String? scheduleInstanceId;

  factory WorkPresenceEntry.fromMap(Map<String, dynamic> map) => WorkPresenceEntry(
        id: map['id'] as String,
        presenceDate: DateTime.parse(map['presence_date'] as String),
        status: map['status'] as String,
        source: map['source'] as String,
        reason: map['reason'] as String?,
        notes: map['notes'] as String?,
        scheduleInstanceId: map['schedule_instance_id'] as String?,
      );
}

/// One `schedule_instances` lesson not yet confirmed/declined in
/// `instructor_presences` — what "Lezioni da confermare" lists.
class WorkPendingLesson {
  const WorkPendingLesson({
    required this.id,
    required this.classDate,
    this.startTime,
    this.endTime,
    required this.discipline,
  });

  final String id;
  final DateTime classDate;
  final String? startTime;
  final String? endTime;
  final String discipline;

  factory WorkPendingLesson.fromMap(Map<String, dynamic> map) => WorkPendingLesson(
        id: map['id'] as String,
        classDate: DateTime.parse(map['class_date'] as String),
        startTime: map['start_time'] as String?,
        endTime: map['end_time'] as String?,
        discipline: map['discipline'] as String? ?? '',
      );
}

/// Client for the "Presenze e compensi" tables (`work_settings`,
/// `work_rate_periods`, `instructor_presences`) and their two summary RPCs,
/// plus the read-only `schedule_instances` lookup for pending lessons.
/// Additive and isolated: touches only these tables — nothing here changes
/// payments, bookings, subscriptions, receipts, the Registro di Cassa, the
/// Scadenzario or the documents archive. All compensation numbers come
/// from the server-side RPCs; nothing here recomputes them. RLS already
/// scopes reads to can_access_admin_section('attendance_compensation') and
/// writes to the principal admin only, so no extra checks are needed here
/// beyond what the UI does for its own affordances.
class WorkAttendanceService {
  WorkAttendanceService._();
  static final WorkAttendanceService instance = WorkAttendanceService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const String _settingsTable = 'work_settings';
  static const String _periodsTable = 'work_rate_periods';
  static const String _presencesTable = 'instructor_presences';

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<WorkSettings> getSettings() async {
    final rows = await _client.from(_settingsTable).select('key, value');
    final map = <String, String>{
      for (final row in (rows as List))
        (row as Map<String, dynamic>)['key'] as String: row['value'] as String,
    };
    return WorkSettings.fromMap(map);
  }

  /// Principal admin only (RLS). Upserts each key/value pair given.
  Future<void> updateSettings(Map<String, String> values) async {
    final rows = values.entries.map((e) => {'key': e.key, 'value': e.value}).toList();
    await _client.from(_settingsTable).upsert(rows);
  }

  Future<List<WorkRatePeriod>> getRatePeriods() async {
    final rows = await _client
        .from(_periodsTable)
        .select('*')
        .order('valid_from', ascending: false);
    return (rows as List)
        .map((row) => WorkRatePeriod.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Principal admin only (RLS).
  Future<void> addRatePeriod({
    required DateTime validFrom,
    required double hourlyRate,
    required int paidLessonsPerWeek,
    required double hoursPerLesson,
    String? note,
  }) async {
    await _client.from(_periodsTable).insert({
      'valid_from': _dateStr(validFrom),
      'hourly_rate': hourlyRate,
      'paid_lessons_per_week': paidLessonsPerWeek,
      'hours_per_lesson': hoursPerLesson,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
  }

  /// Principal admin only (RLS).
  Future<void> updateRatePeriod({
    required DateTime originalValidFrom,
    required DateTime validFrom,
    required double hourlyRate,
    required int paidLessonsPerWeek,
    required double hoursPerLesson,
    String? note,
  }) async {
    await _client.from(_periodsTable).update({
      'valid_from': _dateStr(validFrom),
      'hourly_rate': hourlyRate,
      'paid_lessons_per_week': paidLessonsPerWeek,
      'hours_per_lesson': hoursPerLesson,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    }).eq('valid_from', _dateStr(originalValidFrom));
  }

  /// Principal admin only (RLS). Throws if this is the only period left.
  Future<void> deleteRatePeriod(DateTime validFrom) async {
    final rows = await _client.from(_periodsTable).select('valid_from');
    if ((rows as List).length <= 1) {
      throw Exception('Non è possibile eliminare l\'unico periodo rimasto.');
    }
    await _client.from(_periodsTable).delete().eq('valid_from', _dateStr(validFrom));
  }

  Future<WorkCompensationSummary> getCompensationSummary(int year) async {
    final result = await _client.rpc('work_compensation_summary', params: {'p_year': year});
    return WorkCompensationSummary.fromMap(result as Map<String, dynamic>);
  }

  Future<WorkPresenceSummary> getPresenceSummary(int year) async {
    final result = await _client.rpc('work_presence_summary', params: {'p_year': year});
    return WorkPresenceSummary.fromMap(result as Map<String, dynamic>);
  }

  /// schedule_instances for the current user, not cancelled, from the
  /// first rate period's date through today, with no instructor_presences
  /// row yet — principal admin only in practice (RLS lets any admin with
  /// section access read schedule_instances, but only the principal admin
  /// can act on what this returns).
  Future<List<WorkPendingLesson>> getPendingLessons() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];

    final periodRows = await _client
        .from(_periodsTable)
        .select('valid_from')
        .order('valid_from', ascending: true)
        .limit(1);
    if ((periodRows as List).isEmpty) return const [];
    final firstValidFrom = (periodRows.first as Map<String, dynamic>)['valid_from'] as String;
    final today = _dateStr(DateTime.now());

    final lessonRows = await _client
        .from('schedule_instances')
        .select('id, class_date, start_time, end_time, discipline, is_cancelled')
        .eq('instructor_id', userId)
        .gte('class_date', firstValidFrom)
        .lte('class_date', today)
        .order('class_date', ascending: true);

    final existingRows = await _client
        .from(_presencesTable)
        .select('schedule_instance_id')
        .eq('user_id', userId)
        .not('schedule_instance_id', 'is', null);
    final existingIds = (existingRows as List)
        .map((row) => (row as Map<String, dynamic>)['schedule_instance_id'] as String?)
        .whereType<String>()
        .toSet();

    return (lessonRows as List)
        .cast<Map<String, dynamic>>()
        .where((row) => row['is_cancelled'] != true)
        .map(WorkPendingLesson.fromMap)
        .where((lesson) => !existingIds.contains(lesson.id))
        .toList();
  }

  /// Principal admin only (RLS). Duplicates (same unique schedule_instance_id
  /// already answered) are ignored.
  Future<void> confirmLesson(WorkPendingLesson lesson) async {
    try {
      await _client.from(_presencesTable).insert({
        'presence_date': _dateStr(lesson.classDate),
        'status': 'confirmed',
        'source': 'calendar',
        'schedule_instance_id': lesson.id,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  /// Principal admin only (RLS).
  Future<void> declineLesson(WorkPendingLesson lesson) async {
    try {
      await _client.from(_presencesTable).insert({
        'presence_date': _dateStr(lesson.classDate),
        'status': 'declined',
        'source': 'calendar',
        'schedule_instance_id': lesson.id,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  /// Principal admin only (RLS).
  Future<void> addManualPresence({
    required DateTime date,
    required String reason,
    String? notes,
  }) async {
    await _client.from(_presencesTable).insert({
      'presence_date': _dateStr(date),
      'status': 'confirmed',
      'source': 'manual',
      'reason': reason,
      'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
    });
  }

  /// Confirmed presences, most recent first.
  Future<List<WorkPresenceEntry>> getPresences({int limit = 50}) async {
    final rows = await _client
        .from(_presencesTable)
        .select('*')
        .eq('status', 'confirmed')
        .order('presence_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((row) => WorkPresenceEntry.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Principal admin only (RLS).
  Future<void> deletePresence(String id) async {
    await _client.from(_presencesTable).delete().eq('id', id);
  }

  /// `work_settings.work_instructor_user_id`, read only to identify whose
  /// presences/name the PDF prospetti use — never shown or editable as a
  /// raw id in the UI (see [WorkSettings], which deliberately omits it).
  Future<String?> getInstructorUserId() async {
    final rows = await _client
        .from(_settingsTable)
        .select('value')
        .eq('key', 'work_instructor_user_id')
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return (rows.first as Map<String, dynamic>)['value'] as String?;
  }

  /// `user_profiles.full_name` for [userId], for the "Nome del
  /// collaboratore" line on the PDF prospetti.
  Future<String> getUserFullName(String userId) async {
    final row = await _client
        .from('user_profiles')
        .select('full_name')
        .eq('id', userId)
        .single();
    return row['full_name'] as String? ?? '';
  }

  /// Distinct dates with a confirmed presence for [userId] within
  /// [start]..[end] (inclusive), ascending — the basis for the buoni pasto
  /// and rimborso km prospetti (one voucher/reimbursement per day with
  /// effective service, never per lesson).
  Future<List<DateTime>> getConfirmedPresenceDays({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _client
        .from(_presencesTable)
        .select('presence_date')
        .eq('user_id', userId)
        .eq('status', 'confirmed')
        .gte('presence_date', _dateStr(start))
        .lte('presence_date', _dateStr(end));
    final days = (rows as List)
        .map((row) => (row as Map<String, dynamic>)['presence_date'] as String)
        .toSet()
        .map(DateTime.parse)
        .toList()
      ..sort();
    return days;
  }
}
