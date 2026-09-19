import 'package:supabase_flutter/supabase_flutter.dart';

/// Category keys in display order, and their Italian labels.
const List<String> kAsdDeadlineCategoryKeys = [
  'fiscale',
  'rasd',
  'lavoro_sportivo',
  'affiliazioni',
  'assemblea',
  'safeguarding',
  'altro',
];

const Map<String, String> kAsdDeadlineCategoryLabels = {
  'fiscale': 'Fiscale',
  'rasd': 'RASD',
  'lavoro_sportivo': 'Lavoro sportivo',
  'affiliazioni': 'Affiliazioni',
  'assemblea': 'Assemblea e bilancio',
  'safeguarding': 'Safeguarding',
  'altro': 'Altro',
};

String asdCategoryLabel(String key) => kAsdDeadlineCategoryLabels[key] ?? key;

/// One row of `asd_deadlines`.
class AsdDeadline {
  const AsdDeadline({
    required this.id,
    required this.title,
    required this.category,
    required this.dueMonth,
    required this.dueDay,
    this.dueYear,
    required this.repeatMonths,
    required this.noticeDays,
    this.notes,
    this.guideUrl,
    required this.needsConfirmation,
    required this.isActive,
    this.conditionNote,
    this.howTo,
    required this.legalRefs,
    required this.documentTemplates,
    this.documentAgenda,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final int dueMonth;
  final int dueDay;
  final int? dueYear;
  final int repeatMonths;
  final int noticeDays;
  final String? notes;
  final String? guideUrl;
  final bool needsConfirmation;
  final bool isActive;
  final String? conditionNote;
  final String? howTo;
  final List<AsdLegalRef> legalRefs;
  final List<String> documentTemplates;
  final String? documentAgenda;
  final DateTime createdAt;

  /// True for a "once only in that year" deadline (due_year set).
  bool get isOneTime => dueYear != null;

  factory AsdDeadline.fromMap(Map<String, dynamic> map) {
    return AsdDeadline(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String,
      dueMonth: (map['due_month'] as num).toInt(),
      dueDay: (map['due_day'] as num).toInt(),
      dueYear: (map['due_year'] as num?)?.toInt(),
      repeatMonths: (map['repeat_months'] as num?)?.toInt() ?? 12,
      noticeDays: (map['notice_days'] as num?)?.toInt() ?? 30,
      notes: map['notes'] as String?,
      guideUrl: map['guide_url'] as String?,
      needsConfirmation: map['needs_confirmation'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
      conditionNote: map['condition_note'] as String?,
      howTo: map['how_to'] as String?,
      legalRefs: AsdLegalRef.listFromJson(map['legal_refs']),
      documentTemplates: (map['document_templates'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      documentAgenda: map['document_agenda'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'title': title,
        'category': category,
        'due_month': dueMonth,
        'due_day': dueDay,
        'due_year': dueYear,
        'repeat_months': repeatMonths,
        'notice_days': noticeDays,
        'notes': notes,
        'guide_url': guideUrl,
        'needs_confirmation': needsConfirmation,
        'is_active': isActive,
        'condition_note': conditionNote,
        'how_to': howTo,
        'legal_refs': legalRefs.map((r) => r.toJson()).toList(),
        'document_templates': documentTemplates,
        'document_agenda': documentAgenda,
      };
}

/// One entry of `legal_refs` (jsonb array of {label, url}).
class AsdLegalRef {
  const AsdLegalRef({required this.label, required this.url});

  final String label;
  final String url;

  factory AsdLegalRef.fromJson(Map<String, dynamic> json) => AsdLegalRef(
        label: json['label'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'label': label, 'url': url};

  static List<AsdLegalRef> listFromJson(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(AsdLegalRef.fromJson)
        .toList();
  }
}

/// One row of `asd_deadline_completions`.
class AsdDeadlineCompletion {
  const AsdDeadlineCompletion({
    required this.id,
    required this.deadlineId,
    required this.dueDate,
    required this.completedAt,
    this.completedBy,
    this.completedByName,
    this.note,
  });

  final String id;
  final String deadlineId;
  final DateTime dueDate;
  final DateTime completedAt;
  final String? completedBy;
  final String? completedByName;
  final String? note;

  bool get isSkipped => note == 'Saltata';

  factory AsdDeadlineCompletion.fromMap(Map<String, dynamic> map) {
    return AsdDeadlineCompletion(
      id: map['id'] as String,
      deadlineId: map['deadline_id'] as String,
      dueDate: DateTime.parse(map['due_date'] as String),
      completedAt: DateTime.parse(map['completed_at'] as String),
      completedBy: map['completed_by'] as String?,
      note: map['note'] as String?,
    );
  }

  AsdDeadlineCompletion withCompletedByName(String? name) =>
      AsdDeadlineCompletion(
        id: id,
        deadlineId: deadlineId,
        dueDate: dueDate,
        completedAt: completedAt,
        completedBy: completedBy,
        completedByName: name,
        note: note,
      );
}

enum AsdDeadlineUrgency { normal, dueSoon, overdue }

/// The current, actionable occurrence of an active, not-yet-completed
/// deadline — what the "Da fare" group shows.
class AsdDeadlineOccurrence {
  const AsdDeadlineOccurrence({
    required this.deadline,
    required this.dueDate,
    required this.urgency,
  });

  final AsdDeadline deadline;
  final DateTime dueDate;
  final AsdDeadlineUrgency urgency;
}

/// One row for the read-only "Certificati medici" group.
class AsdMedicalCertificateAlert {
  const AsdMedicalCertificateAlert({
    required this.name,
    required this.expiry,
    required this.isOverdue,
  });

  final String name;
  final DateTime expiry;
  final bool isOverdue;
}

/// Result of [AsdDeadlinesService.getMedicalCertificateAlerts] — null from
/// that method itself means "not permitted", handled by the caller.
class AsdMedicalCertificateReport {
  const AsdMedicalCertificateReport({
    required this.alerts,
    required this.missingCount,
  });

  final List<AsdMedicalCertificateAlert> alerts;
  final int missingCount;
}

/// Everything the Scadenzario screen (and the section/dashboard badges) need
/// in one shot.
class AsdDeadlineSummary {
  const AsdDeadlineSummary({
    required this.dueOccurrences,
    required this.recentCompletions,
    required this.inactiveDeadlines,
    required this.medicalReport,
    required this.titlesByDeadlineId,
  });

  final List<AsdDeadlineOccurrence> dueOccurrences;
  final List<AsdDeadlineCompletion> recentCompletions;
  final List<AsdDeadline> inactiveDeadlines;
  final AsdMedicalCertificateReport? medicalReport;

  /// Every deadline's title by id (active or not), so the "Completate"
  /// group can show a title even for a deadline whose current occurrence
  /// has since moved on, or that was a one-time deadline now fully done.
  final Map<String, String> titlesByDeadlineId;

  int get overdueCount =>
      dueOccurrences.where((o) => o.urgency == AsdDeadlineUrgency.overdue).length +
      (medicalReport?.alerts.where((a) => a.isOverdue).length ?? 0);

  int get dueSoonCount =>
      dueOccurrences.where((o) => o.urgency == AsdDeadlineUrgency.dueSoon).length +
      (medicalReport?.alerts.where((a) => !a.isOverdue).length ?? 0);

  /// overdue + due-soon — what every badge (dashboard card, section row,
  /// notifications) counts.
  int get pendingCount => overdueCount + dueSoonCount;
}

/// Client for the Scadenzario ASD (`asd_deadlines`, `asd_deadline_completions`)
/// plus the read-only medical-certificate alerts already stored on
/// user/child profiles. Additive and isolated: touches only these new
/// tables and, read-only, the two existing certificate-expiry columns —
/// nothing here changes payments, bookings, subscriptions, receipts or the
/// Registro di Cassa. All writes rely on RLS already scoped to
/// can_access_admin_section('deadlines') — no RPCs needed, unlike the cash
/// register (that table's RLS is ALL-command, not SECURITY DEFINER-only).
class AsdDeadlinesService {
  AsdDeadlinesService._();
  static final AsdDeadlinesService instance = AsdDeadlinesService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const String _deadlinesTable = 'asd_deadlines';
  static const String _completionsTable = 'asd_deadline_completions';

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _addMonths(DateTime d, int months) =>
      DateTime(d.year, d.month + months, d.day);

  Future<List<AsdDeadline>> getAllDeadlines() async {
    final rows = await _client
        .from(_deadlinesTable)
        .select('*')
        .order('due_month', ascending: true)
        .order('due_day', ascending: true);
    return (rows as List)
        .map((row) => AsdDeadline.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<AsdDeadline> createDeadline(Map<String, dynamic> values) async {
    final row = await _client
        .from(_deadlinesTable)
        .insert(values)
        .select()
        .single();
    return AsdDeadline.fromMap(row);
  }

  Future<void> updateDeadline(String id, Map<String, dynamic> values) async {
    await _client.from(_deadlinesTable).update(values).eq('id', id);
  }

  Future<void> setDeadlineActive(String id, bool isActive) async {
    await _client
        .from(_deadlinesTable)
        .update({'is_active': isActive}).eq('id', id);
  }

  Future<void> deleteDeadline(String id) async {
    await _client.from(_deadlinesTable).delete().eq('id', id);
  }

  /// Every completion for [deadlineId], most recent first.
  Future<List<AsdDeadlineCompletion>> _getCompletions(String deadlineId) async {
    final rows = await _client
        .from(_completionsTable)
        .select('*')
        .eq('deadline_id', deadlineId)
        .order('due_date', ascending: false);
    return (rows as List)
        .map((row) => AsdDeadlineCompletion.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Records a completion for [deadline] on [dueDate]. Duplicates (same
  /// deadline_id + due_date) are ignored, matching the unique constraint.
  Future<void> completeOccurrence({
    required String deadlineId,
    required DateTime dueDate,
    String? note,
  }) async {
    try {
      await _client.from(_completionsTable).insert({
        'deadline_id': deadlineId,
        'due_date': _dateStr(dueDate),
        'completed_by': _client.auth.currentUser?.id,
        if (note != null) 'note': note,
      });
    } on PostgrestException catch (e) {
      // Unique violation (already completed) — treat as a no-op success.
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> undoCompletion(String completionId) async {
    await _client.from(_completionsTable).delete().eq('id', completionId);
  }

  /// Latest completions across all deadlines, joined with the completing
  /// admin's name, for the "Completate" group.
  Future<List<AsdDeadlineCompletion>> getRecentCompletions({int limit = 20}) async {
    final rows = await _client
        .from(_completionsTable)
        .select('*')
        .order('completed_at', ascending: false)
        .limit(limit);
    final completions = (rows as List)
        .map((row) => AsdDeadlineCompletion.fromMap(row as Map<String, dynamic>))
        .toList();

    final userIds = completions
        .map((c) => c.completedBy)
        .whereType<String>()
        .toSet()
        .toList();
    if (userIds.isEmpty) return completions;

    Map<String, String> namesById = {};
    try {
      final users = await _client
          .from('user_profiles')
          .select('id, full_name')
          .inFilter('id', userIds);
      namesById = {
        for (final u in (users as List))
          u['id'] as String: u['full_name'] as String? ?? '',
      };
    } catch (_) {
      // Leave names blank if this lookup fails — not critical.
    }

    return completions
        .map((c) => c.withCompletedByName(namesById[c.completedBy]))
        .toList();
  }

  /// The occurrence sequence anchor: due_month/due_day in created_at's
  /// year, advanced by repeat_months until it's not before created_at.
  DateTime _firstOccurrenceOnOrAfterCreation(AsdDeadline d) {
    var occurrence = DateTime(d.createdAt.year, d.dueMonth, d.dueDay);
    final createdDate = _dateOnly(d.createdAt);
    while (occurrence.isBefore(createdDate)) {
      occurrence = _addMonths(occurrence, d.repeatMonths);
    }
    return occurrence;
  }

  /// The due date of the current (first not-completed) occurrence of an
  /// active recurring/one-time deadline, or null if fully completed
  /// (one-time only) or inactive.
  DateTime? _currentOccurrenceDueDate(
    AsdDeadline d,
    Set<DateTime> completedDueDates,
  ) {
    if (!d.isActive) return null;

    if (d.isOneTime) {
      final due = DateTime(d.dueYear!, d.dueMonth, d.dueDay);
      return completedDueDates.contains(due) ? null : due;
    }

    var occurrence = _firstOccurrenceOnOrAfterCreation(d);
    var guard = 0;
    while (completedDueDates.contains(occurrence) && guard < 1000) {
      occurrence = _addMonths(occurrence, d.repeatMonths);
      guard++;
    }
    return occurrence;
  }

  AsdDeadlineUrgency _classify(DateTime dueDate, int noticeDays, DateTime today) {
    final daysUntil = _dateOnly(dueDate).difference(_dateOnly(today)).inDays;
    if (daysUntil < 0) return AsdDeadlineUrgency.overdue;
    if (daysUntil < noticeDays) return AsdDeadlineUrgency.dueSoon;
    return AsdDeadlineUrgency.normal;
  }

  /// All active deadlines' current occurrences (whatever their urgency —
  /// the screen itself decides what to color/highlight), in date order.
  Future<List<AsdDeadlineOccurrence>> getDueOccurrences(
    List<AsdDeadline> allDeadlines,
  ) async {
    final active = allDeadlines.where((d) => d.isActive).toList();
    if (active.isEmpty) return const [];

    final rows = await _client
        .from(_completionsTable)
        .select('deadline_id, due_date')
        .inFilter('deadline_id', active.map((d) => d.id).toList());

    final completedByDeadline = <String, Set<DateTime>>{};
    for (final row in (rows as List)) {
      final id = row['deadline_id'] as String;
      final due = DateTime.parse(row['due_date'] as String);
      completedByDeadline.putIfAbsent(id, () => {}).add(due);
    }

    final today = DateTime.now();
    final occurrences = <AsdDeadlineOccurrence>[];
    for (final deadline in active) {
      final dueDate = _currentOccurrenceDueDate(
        deadline,
        completedByDeadline[deadline.id] ?? const {},
      );
      if (dueDate == null) continue; // one-time, already completed
      occurrences.add(
        AsdDeadlineOccurrence(
          deadline: deadline,
          dueDate: dueDate,
          urgency: _classify(dueDate, deadline.noticeDays, today),
        ),
      );
    }
    occurrences.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return occurrences;
  }

  /// Adults (user_profiles) and minors (child_profiles) whose medical
  /// certificate is expired or expiring within 30 days, plus a count of
  /// profiles with no certificate date at all. Returns null if the
  /// underlying reads aren't permitted — the caller hides the group then.
  Future<AsdMedicalCertificateReport?> getMedicalCertificateAlerts() async {
    try {
      final today = DateTime.now();
      final alerts = <AsdMedicalCertificateAlert>[];
      var missingCount = 0;

      final adults = await _client
          .from('user_profiles')
          .select('full_name, medical_certificate_expiry')
          .eq('is_active', true)
          .inFilter('role', ['student', 'instructor_student']);
      for (final row in (adults as List)) {
        final expiryRaw = row['medical_certificate_expiry'] as String?;
        final name = row['full_name'] as String? ?? '';
        if (expiryRaw == null) {
          missingCount++;
          continue;
        }
        final expiry = DateTime.parse(expiryRaw);
        final daysUntil = _dateOnly(expiry).difference(_dateOnly(today)).inDays;
        if (daysUntil < 0) {
          alerts.add(AsdMedicalCertificateAlert(
            name: name,
            expiry: expiry,
            isOverdue: true,
          ));
        } else if (daysUntil <= 30) {
          alerts.add(AsdMedicalCertificateAlert(
            name: name,
            expiry: expiry,
            isOverdue: false,
          ));
        }
      }

      final children =
          await _client.from('child_profiles').select('full_name, medical_certificate_expiry_date');
      for (final row in (children as List)) {
        final expiryRaw = row['medical_certificate_expiry_date'] as String?;
        final name = row['full_name'] as String? ?? '';
        if (expiryRaw == null) {
          missingCount++;
          continue;
        }
        final expiry = DateTime.parse(expiryRaw);
        final daysUntil = _dateOnly(expiry).difference(_dateOnly(today)).inDays;
        if (daysUntil < 0) {
          alerts.add(AsdMedicalCertificateAlert(
            name: name,
            expiry: expiry,
            isOverdue: true,
          ));
        } else if (daysUntil <= 30) {
          alerts.add(AsdMedicalCertificateAlert(
            name: name,
            expiry: expiry,
            isOverdue: false,
          ));
        }
      }

      alerts.sort((a, b) => a.expiry.compareTo(b.expiry));
      return AsdMedicalCertificateReport(alerts: alerts, missingCount: missingCount);
    } catch (_) {
      return null;
    }
  }

  /// Everything the Scadenzario screen and badges need, in one call.
  Future<AsdDeadlineSummary> getSummary() async {
    final all = await getAllDeadlines();
    final due = await getDueOccurrences(all);
    final recentCompletions = await getRecentCompletions();
    final inactive = all.where((d) => !d.isActive).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    final medicalReport = await getMedicalCertificateAlerts();

    return AsdDeadlineSummary(
      dueOccurrences: due,
      recentCompletions: recentCompletions,
      inactiveDeadlines: inactive,
      medicalReport: medicalReport,
      titlesByDeadlineId: {for (final d in all) d.id: d.title},
    );
  }

  /// Lightweight version of [getSummary] for badges/notifications — same
  /// counts, without the full completions/inactive lists.
  Future<AsdDeadlineSummary> getPendingSummary() async {
    final all = await getAllDeadlines();
    final due = await getDueOccurrences(all);
    final medicalReport = await getMedicalCertificateAlerts();
    return AsdDeadlineSummary(
      dueOccurrences: due,
      recentCompletions: const [],
      inactiveDeadlines: const [],
      medicalReport: medicalReport,
      titlesByDeadlineId: const {},
    );
  }
}
