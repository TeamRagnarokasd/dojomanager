import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

const String kAsdDocumentSourceGenerated = 'generated';
const String kAsdDocumentSourceUploaded = 'uploaded';

/// One row of `asd_document_categories`.
class AsdDocumentCategory {
  const AsdDocumentCategory({
    required this.key,
    required this.label,
    required this.sortOrder,
  });

  final String key;
  final String label;
  final int sortOrder;

  factory AsdDocumentCategory.fromMap(Map<String, dynamic> map) =>
      AsdDocumentCategory(
        key: map['key'] as String,
        label: map['label'] as String,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}

/// One row of `asd_documents` — a generated draft or an uploaded scan/photo,
/// filed under a category and (optionally) linked to a Scadenzario entry.
class AsdDocument {
  const AsdDocument({
    required this.id,
    this.deadlineId,
    this.dueDate,
    this.templateKey,
    required this.title,
    required this.storagePath,
    this.createdBy,
    required this.createdAt,
    required this.driveUploaded,
    this.driveUploadedAt,
    required this.category,
    this.subject,
    required this.docDate,
    required this.source,
    this.fileName,
    this.mimeType,
  });

  final String id;
  final String? deadlineId;
  final DateTime? dueDate;
  final String? templateKey;
  final String title;
  final String storagePath;
  final String? createdBy;
  final DateTime createdAt;
  final bool driveUploaded;
  final DateTime? driveUploadedAt;
  final String category;
  final String? subject;
  final DateTime docDate;

  /// 'generated' (from a template) or 'uploaded' (added by hand).
  final String source;
  final String? fileName;
  final String? mimeType;

  bool get isPdf =>
      mimeType == 'application/pdf' ||
      (fileName?.toLowerCase().endsWith('.pdf') ?? false) ||
      storagePath.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      (mimeType?.startsWith('image/') ?? false) ||
      RegExp(r'\.(jpg|jpeg|png|webp|gif|heic)$', caseSensitive: false)
          .hasMatch(fileName ?? storagePath);

  factory AsdDocument.fromMap(Map<String, dynamic> map) => AsdDocument(
        id: map['id'] as String,
        deadlineId: map['deadline_id'] as String?,
        dueDate: map['due_date'] == null
            ? null
            : DateTime.parse(map['due_date'] as String),
        templateKey: map['template_key'] as String?,
        title: map['title'] as String,
        storagePath: map['storage_path'] as String,
        createdBy: map['created_by'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        driveUploaded: map['drive_uploaded'] as bool? ?? false,
        driveUploadedAt: map['drive_uploaded_at'] == null
            ? null
            : DateTime.parse(map['drive_uploaded_at'] as String),
        category: map['category'] as String? ?? 'altro',
        subject: map['subject'] as String?,
        docDate: DateTime.parse(map['doc_date'] as String),
        source: map['source'] as String? ?? kAsdDocumentSourceGenerated,
        fileName: map['file_name'] as String?,
        mimeType: map['mime_type'] as String?,
      );
}

/// Client for `asd_documents` / `asd_document_categories` and the private
/// `asd-deadline-docs` storage bucket. Additive and isolated: touches only
/// these new tables and their bucket — nothing here changes payments,
/// bookings, subscriptions, receipts, the Registro di Cassa or any
/// student-facing screen. RLS is already scoped to
/// can_access_admin_section('deadlines' | 'documents_archive') on both
/// tables and the bucket, so no RPCs are needed for reads/writes/deletes.
class AsdDocumentsService {
  AsdDocumentsService._();
  static final AsdDocumentsService instance = AsdDocumentsService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const String _table = 'asd_documents';
  static const String _categoriesTable = 'asd_document_categories';
  static const String _bucket = 'asd-deadline-docs';

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const Map<String, String> _accentMap = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
    'À': 'A', 'Á': 'A', 'Â': 'A', 'Ä': 'A', 'Ã': 'A', 'Å': 'A',
    'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
    'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
    'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Ö': 'O', 'Õ': 'O',
    'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
    'Ç': 'C', 'Ñ': 'N',
  };

  String removeAccents(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_accentMap[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Strips accents and replaces anything but letters/digits/`._-` with `_`.
  String sanitizeFileName(String name) {
    return removeAccents(name).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  /// `<timestamp>_<sanitized file name>`, safe to use as a storage object
  /// name (avoids collisions between drafts generated the same day).
  String timestampedFileName(String fileName) =>
      '${_timestamp()}_${sanitizeFileName(fileName)}';

  String generatedStoragePath({required String? deadlineId, required String fileName}) =>
      'generated/${deadlineId ?? 'generale'}/$fileName';

  String archiveStoragePath({required String category, required String fileName}) =>
      'archive/$category/$fileName';

  String _slugifyCategoryKey(String label) {
    final slug = removeAccents(label.trim().toLowerCase())
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'categoria' : slug;
  }

  Future<void> uploadBytes(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  Future<Uint8List> downloadBytes(String path) =>
      _client.storage.from(_bucket).download(path);

  Future<void> _removeFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove(paths);
    } catch (_) {
      // Best effort — a missing/already-removed file is not fatal.
    }
  }

  /// Best-effort bucket cleanup for every document filed under [deadlineId],
  /// meant to run right before the deadline row itself is deleted (its
  /// asd_documents rows cascade on delete, but their files in the bucket do
  /// not, so this must happen first).
  Future<void> deleteFilesForDeadline(String deadlineId) async {
    try {
      final rows = await _client
          .from(_table)
          .select('storage_path')
          .eq('deadline_id', deadlineId);
      final paths = (rows as List)
          .map((r) => r['storage_path'] as String?)
          .whereType<String>()
          .toList();
      await _removeFiles(paths);
    } catch (_) {
      // Best effort.
    }
  }

  Future<List<AsdDocumentCategory>> getCategories() async {
    final rows = await _client
        .from(_categoriesTable)
        .select('*')
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((row) => AsdDocumentCategory.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addCategory(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final key = _slugifyCategoryKey(trimmed);
    final rows = await _client
        .from(_categoriesTable)
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1);
    final maxSort = (rows as List).isEmpty
        ? 0
        : ((rows.first as Map<String, dynamic>)['sort_order'] as num?)?.toInt() ?? 0;
    await _client.from(_categoriesTable).insert({
      'key': key,
      'label': trimmed,
      'sort_order': maxSort + 1,
    });
  }

  /// Throws if the category still has documents filed under it.
  Future<void> deleteCategory(String key) async {
    final counts = await getCategoryCounts();
    if ((counts[key] ?? 0) > 0) {
      throw Exception('Non è possibile eliminare una categoria che contiene documenti.');
    }
    await _client.from(_categoriesTable).delete().eq('key', key);
  }

  Future<Map<String, int>> getCategoryCounts() async {
    final rows = await _client.from(_table).select('category');
    final counts = <String, int>{};
    for (final row in (rows as List)) {
      final category = (row as Map<String, dynamic>)['category'] as String? ?? 'altro';
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<AsdDocument>> getAllDocuments() async {
    final rows = await _client.from(_table).select('*').order('doc_date', ascending: false);
    return (rows as List)
        .map((row) => AsdDocument.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AsdDocument>> getDocumentsByCategory(String category) async {
    final rows = await _client
        .from(_table)
        .select('*')
        .eq('category', category)
        .order('doc_date', ascending: false);
    return (rows as List)
        .map((row) => AsdDocument.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AsdDocument>> getDocumentsForDeadline(String deadlineId) async {
    final rows = await _client
        .from(_table)
        .select('*')
        .eq('deadline_id', deadlineId)
        .order('doc_date', ascending: false);
    return (rows as List)
        .map((row) => AsdDocument.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AsdDocument>> searchDocuments(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getAllDocuments();
    final safe = trimmed.replaceAll(RegExp(r'[(),]'), ' ');
    final rows = await _client
        .from(_table)
        .select('*')
        .or('title.ilike.%$safe%,subject.ilike.%$safe%')
        .order('doc_date', ascending: false);
    return (rows as List)
        .map((row) => AsdDocument.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<AsdDocument> createDocument({
    String? deadlineId,
    DateTime? dueDate,
    String? templateKey,
    required String title,
    required String storagePath,
    String category = 'altro',
    String? subject,
    required DateTime docDate,
    required String source,
    String? fileName,
    String? mimeType,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'deadline_id': deadlineId,
          'due_date': dueDate == null ? null : _dateStr(dueDate),
          'template_key': templateKey,
          'title': title,
          'storage_path': storagePath,
          'category': category,
          'subject': (subject == null || subject.trim().isEmpty) ? null : subject.trim(),
          'doc_date': _dateStr(docDate),
          'source': source,
          'file_name': fileName,
          'mime_type': mimeType,
        })
        .select()
        .single();
    return AsdDocument.fromMap(row);
  }

  Future<void> updateDocument(
    String id, {
    String? title,
    String? category,
    String? subject,
    DateTime? docDate,
  }) async {
    final values = <String, dynamic>{};
    if (title != null) values['title'] = title;
    if (category != null) values['category'] = category;
    if (subject != null) {
      values['subject'] = subject.trim().isEmpty ? null : subject.trim();
    }
    if (docDate != null) values['doc_date'] = _dateStr(docDate);
    if (values.isEmpty) return;
    await _client.from(_table).update(values).eq('id', id);
  }

  Future<void> setDriveUploaded(String id, bool uploaded) async {
    await _client.from(_table).update({
      'drive_uploaded': uploaded,
      'drive_uploaded_at': uploaded ? DateTime.now().toIso8601String() : null,
    }).eq('id', id);
  }

  /// Removes the file from the bucket (best effort) then the row.
  Future<void> deleteDocument(AsdDocument document) async {
    await _removeFiles([document.storagePath]);
    await _client.from(_table).delete().eq('id', document.id);
  }
}
