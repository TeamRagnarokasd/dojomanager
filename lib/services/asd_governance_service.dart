import 'package:supabase_flutter/supabase_flutter.dart';

/// Board member role keys in display order, and their Italian labels.
const List<String> kAsdBoardRoleKeys = [
  'presidente',
  'vicepresidente',
  'segretario',
  'consigliere',
];

const Map<String, String> kAsdBoardRoleLabels = {
  'presidente': 'Presidente',
  'vicepresidente': 'Vicepresidente',
  'segretario': 'Segretario',
  'consigliere': 'Consigliere',
};

String asdBoardRoleLabel(String key) => kAsdBoardRoleLabels[key] ?? key;

/// One row of `asd_board_members`.
class AsdBoardMember {
  const AsdBoardMember({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String fullName;
  final String role; // 'presidente' | 'vicepresidente' | 'segretario' | 'consigliere'
  final bool isActive;
  final int sortOrder;

  factory AsdBoardMember.fromMap(Map<String, dynamic> map) => AsdBoardMember(
        id: map['id'] as String,
        fullName: map['full_name'] as String,
        role: map['role'] as String,
        isActive: map['is_active'] as bool? ?? true,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}

/// One row of `asd_document_templates`.
class AsdDocumentTemplate {
  const AsdDocumentTemplate({
    required this.key,
    required this.title,
    this.description,
    required this.body,
  });

  final String key;
  final String title;
  final String? description;
  final String body;

  factory AsdDocumentTemplate.fromMap(Map<String, dynamic> map) =>
      AsdDocumentTemplate(
        key: map['key'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        body: map['body'] as String,
      );
}

/// Minimal read of `organization_info`, just the fields the document
/// placeholders need — kept separate from ItalianReceiptService's own
/// (unmodified) copy of this data to avoid any coupling to receipt code.
class AsdOrganizationInfo {
  const AsdOrganizationInfo({required this.address, required this.taxCode});

  final String address;
  final String taxCode;
}

/// Board members, document templates and ASD settings (the shared Drive
/// folder link) — governance data used by the Scadenzario's guide sheets
/// and document generator. Additive and isolated: touches only
/// asd_board_members / asd_document_templates / asd_settings and,
/// read-only, organization_info. RLS already scopes reads/writes to
/// can_access_admin_section('deadlines' or 'drive_documents'); writing
/// asd_settings is restricted server-side to the principal admin.
class AsdGovernanceService {
  AsdGovernanceService._();
  static final AsdGovernanceService instance = AsdGovernanceService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const String _boardTable = 'asd_board_members';
  static const String _templatesTable = 'asd_document_templates';
  static const String _settingsTable = 'asd_settings';

  Future<List<AsdBoardMember>> getBoardMembers({bool onlyActive = false}) async {
    var query = _client.from(_boardTable).select('*');
    if (onlyActive) query = query.eq('is_active', true);
    final rows = await query.order('sort_order', ascending: true);
    return (rows as List)
        .map((row) => AsdBoardMember.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addBoardMember({
    required String fullName,
    required String role,
    int sortOrder = 0,
  }) async {
    await _client.from(_boardTable).insert({
      'full_name': fullName,
      'role': role,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateBoardMember(
    String id, {
    String? fullName,
    String? role,
    bool? isActive,
    int? sortOrder,
  }) async {
    final values = <String, dynamic>{};
    if (fullName != null) values['full_name'] = fullName;
    if (role != null) values['role'] = role;
    if (isActive != null) values['is_active'] = isActive;
    if (sortOrder != null) values['sort_order'] = sortOrder;
    if (values.isEmpty) return;
    await _client.from(_boardTable).update(values).eq('id', id);
  }

  Future<void> deleteBoardMember(String id) async {
    await _client.from(_boardTable).delete().eq('id', id);
  }

  Future<List<AsdDocumentTemplate>> getDocumentTemplates() async {
    final rows = await _client
        .from(_templatesTable)
        .select('*')
        .order('title', ascending: true);
    return (rows as List)
        .map((row) => AsdDocumentTemplate.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AsdDocumentTemplate>> getTemplatesByKeys(List<String> keys) async {
    if (keys.isEmpty) return const [];
    final rows =
        await _client.from(_templatesTable).select('*').inFilter('key', keys);
    return (rows as List)
        .map((row) => AsdDocumentTemplate.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<String?> getDriveFolderUrl() async {
    final row = await _client
        .from(_settingsTable)
        .select('value')
        .eq('key', 'drive_folder_url')
        .maybeSingle();
    final url = row?['value'] as String?;
    return (url == null || url.trim().isEmpty) ? null : url.trim();
  }

  /// Principal admin only — enforced server-side (RLS on asd_settings).
  Future<void> setDriveFolderUrl(String url) async {
    await _client.from(_settingsTable).upsert({
      'key': 'drive_folder_url',
      'value': url.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<AsdOrganizationInfo> getOrganizationInfo() async {
    final row = await _client
        .from('organization_info')
        .select('address, tax_code')
        .limit(1)
        .maybeSingle();
    return AsdOrganizationInfo(
      address: row?['address'] as String? ?? '',
      taxCode: row?['tax_code'] as String? ?? '',
    );
  }
}
