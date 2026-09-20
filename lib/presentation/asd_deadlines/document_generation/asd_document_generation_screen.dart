import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/asd_deadlines_service.dart';
import '../../../services/asd_governance_service.dart';
import '../../../services/italian_receipt_service.dart';

const List<String> _kItalianMonthNamesLower = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

const List<String> _kTrimestreOptions = [
  '1° trimestre (gennaio-marzo)',
  '2° trimestre (aprile-giugno)',
  '3° trimestre (luglio-settembre)',
  '4° trimestre (ottobre-dicembre)',
];

const Set<String> _kDateGroupKeys = {'data', 'giorno', 'mese', 'anno'};

/// Draft-document generator: builds a form from the `{{placeholder}}` tokens
/// found in [template].body, fills them in, produces an A4 PDF (Helvetica,
/// no €, first lines centered/bold) and shares it via Printing.sharePdf.
/// No attachment is ever uploaded to Supabase — the reminder shown after
/// generation tells the admin to sign the printed document and upload it to
/// the shared Drive folder by hand.
class AsdDocumentGenerationScreen extends StatefulWidget {
  const AsdDocumentGenerationScreen({
    Key? key,
    required this.template,
    this.sourceDeadline,
  }) : super(key: key);

  final AsdDocumentTemplate template;
  final AsdDeadline? sourceDeadline;

  @override
  State<AsdDocumentGenerationScreen> createState() =>
      _AsdDocumentGenerationScreenState();
}

enum _AttendanceStatus { none, present, absent }

class _AsdDocumentGenerationScreenState
    extends State<AsdDocumentGenerationScreen> {
  final _governanceService = AsdGovernanceService.instance;

  bool _isLoading = true;
  bool _isGenerating = false;
  List<AsdBoardMember> _activeMembers = [];
  late List<String> _fieldOrder;
  late List<String> _placeholders;

  final Map<String, TextEditingController> _textControllers = {};
  DateTime? _dataValue;
  TimeOfDay? _oraValue;
  String _convocazione = 'prima';
  DateTime? _dataPrima;
  TimeOfDay? _oraPrima;
  DateTime? _dataSeconda;
  TimeOfDay? _oraSeconda;
  String _modalita = 'in presenza';
  String _trimestre = _kTrimestreOptions.first;

  final Map<String, _AttendanceStatus> _memberAttendance = {};
  final List<String> _customPresent = [];
  final List<String> _customAbsent = [];
  final _addNameController = TextEditingController();

  bool get _needsElectionWarning {
    final text = '${widget.template.title} ${widget.template.body}'.toLowerCase();
    return text.contains('elezione delle cariche');
  }

  @override
  void initState() {
    super.initState();
    _placeholders = _extractPlaceholders(widget.template.body);
    _buildFieldOrder();
    _prefillDefaults();
    _load();
  }

  List<String> _extractPlaceholders(String body) {
    final matches = RegExp(r'\{\{(.*?)\}\}').allMatches(body);
    final seen = <String>{};
    final result = <String>[];
    for (final match in matches) {
      final key = match.group(1)?.trim() ?? '';
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(key);
    }
    return result;
  }

  void _buildFieldOrder() {
    final order = <String>[];
    var dateGroupAdded = false;
    var attendanceGroupAdded = false;
    for (final key in _placeholders) {
      if (_kDateGroupKeys.contains(key)) {
        if (!dateGroupAdded) {
          order.add('data');
          dateGroupAdded = true;
        }
        continue;
      }
      if (key == 'presenti' || key == 'assenti') {
        if (!attendanceGroupAdded) {
          order.add('presenti');
          attendanceGroupAdded = true;
        }
        continue;
      }
      if (key == 'luogo_data') continue;
      order.add(key);
    }
    _fieldOrder = order;
  }

  void _prefillDefaults() {
    _textControllers['luogo'] =
        TextEditingController(text: 'la sede sociale di Longiano (FC), via Fratta 319');
    _textControllers['ordine_del_giorno'] =
        TextEditingController(text: widget.sourceDeadline?.documentAgenda ?? '');
  }

  Future<void> _load() async {
    try {
      final orgInfo = await _governanceService.getOrganizationInfo();
      final members = await _governanceService.getBoardMembers(onlyActive: true);
      if (!mounted) return;
      setState(() {
        _activeMembers = members;
        _textControllers['sede_legale'] = TextEditingController(text: orgInfo.address);
        _textControllers['codice_fiscale'] = TextEditingController(text: orgInfo.taxCode);
        _textControllers['presidente'] = TextEditingController(
          text: _firstMemberNameForRole('presidente'),
        );
        _textControllers['segretario'] = TextEditingController(
          text: _firstMemberNameForRole('segretario'),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _textControllers['sede_legale'] ??= TextEditingController();
        _textControllers['codice_fiscale'] ??= TextEditingController();
        _textControllers['presidente'] ??= TextEditingController();
        _textControllers['segretario'] ??= TextEditingController();
        _isLoading = false;
      });
    }
  }

  String _firstMemberNameForRole(String role) {
    for (final member in _activeMembers) {
      if (member.role == role) return member.fullName;
    }
    return '';
  }

  TextEditingController _controllerFor(String key) {
    return _textControllers.putIfAbsent(key, () => TextEditingController());
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _addNameController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) {
    return showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
  }

  String _formatDate(DateTime? date) =>
      date == null ? '' : DateFormat('dd/MM/yyyy').format(date);

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _addCustomName(bool present) {
    final name = _addNameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      if (present) {
        _customPresent.add(name);
      } else {
        _customAbsent.add(name);
      }
      _addNameController.clear();
    });
  }

  String _presentiValue() {
    final names = [
      for (final m in _activeMembers)
        if (_memberAttendance[m.id] == _AttendanceStatus.present) m.fullName,
      ..._customPresent,
    ];
    return names.join(', ');
  }

  String _assentiValue() {
    final names = [
      for (final m in _activeMembers)
        if (_memberAttendance[m.id] == _AttendanceStatus.absent) m.fullName,
      ..._customAbsent,
    ];
    return names.join(', ');
  }

  String _resolveValue(String key) {
    switch (key) {
      case 'data':
        return _formatDate(_dataValue);
      case 'giorno':
        return _dataValue == null ? '' : _dataValue!.day.toString();
      case 'mese':
        return _dataValue == null ? '' : _kItalianMonthNamesLower[_dataValue!.month - 1];
      case 'anno':
        return _dataValue == null ? '' : _dataValue!.year.toString();
      case 'ora':
        return _formatTime(_oraValue);
      case 'presenti':
        return _presentiValue();
      case 'assenti':
        return _assentiValue();
      case 'convocazione':
        return _convocazione;
      case 'data_prima':
        return _formatDate(_dataPrima);
      case 'ora_prima':
        return _formatTime(_oraPrima);
      case 'data_seconda':
        return _formatDate(_dataSeconda);
      case 'ora_seconda':
        return _formatTime(_oraSeconda);
      case 'modalita':
        return _modalita;
      case 'luogo_data':
        return 'Longiano, ${_formatDate(DateTime.now())}';
      case 'trimestre':
        return _trimestre;
      default:
        return _textControllers[key]?.text.trim() ?? '';
    }
  }

  String _fillTemplate(String body, Map<String, String> values) {
    var filled = body.replaceAllMapped(RegExp(r'\{\{(.*?)\}\}'), (match) {
      final key = match.group(1)?.trim() ?? '';
      final value = values[key] ?? '';
      return value.isEmpty ? '______________' : value;
    });
    filled = filled.replaceAll('€', 'euro');
    return filled;
  }

  /// Two tokens separated by 3+ spaces (e.g. "Il Segretario     Il
  /// Presidente") render as a left/right pair instead of literal spaces;
  /// anything else renders as-is, so underscore fill-in lines stay intact.
  pw.Widget _buildBodyLine(String line, pw.TextStyle style) {
    final parts = line
        .split(RegExp(r' {3,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 2) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(parts[0], style: style),
            pw.Text(parts[1], style: style),
          ],
        ),
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(line, style: style),
    );
  }

  /// Same red-header layout as ItalianReceiptService.generateBeautifulReceiptPDF
  /// (logo + organization info), reused here rather than duplicated with new
  /// styling — that file itself is left untouched.
  Future<pw.Document> _buildPdf(String title, String body) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    final orgInfo = await ItalianReceiptService().getOrganizationInfo();
    final logoBytes = await rootBundle.load('assets/images/146804-1764638363594.jpg');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final lines = body.split('\n');
    final docTitle = lines.isNotEmpty ? lines.first : title;
    final bodyLines = lines.length > 1 ? lines.sublist(1) : const <String>[];

    const bodyStyle = pw.TextStyle(fontSize: 11);
    final titleStyle = pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              'Team Ragnarok ASD - documento generato dall\'app il '
              '${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Pagina ${context.pageNumber} di ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.red700,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 60, height: 60, child: pw.Image(logoImage)),
                pw.SizedBox(width: 15),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        orgInfo.name,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        orgInfo.address,
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                      ),
                      pw.Text(
                        'c.f. ${orgInfo.taxCode}',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                      ),
                      if (orgInfo.pec != null && orgInfo.pec!.isNotEmpty)
                        pw.Text(
                          'PEC: ${orgInfo.pec}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                        ),
                      if (orgInfo.phone != null && orgInfo.phone!.isNotEmpty)
                        pw.Text(
                          'Tel: ${orgInfo.phone}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                        ),
                      if (orgInfo.email != null && orgInfo.email!.isNotEmpty)
                        pw.Text(
                          'Email: ${orgInfo.email}',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(docTitle, style: titleStyle, textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 16),
          for (final line in bodyLines)
            line.trim().isEmpty ? pw.SizedBox(height: 10) : _buildBodyLine(line, bodyStyle),
        ],
      ),
    );
    return pdf;
  }

  String _buildFilename() {
    final sanitizedTitle = widget.template.title
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${sanitizedTitle}_$dateStr.pdf';
  }

  Future<void> _generate() async {
    if (_placeholders.contains('data_prima') &&
        _placeholders.contains('data_seconda') &&
        _dataPrima != null &&
        _dataSeconda != null &&
        _dataPrima!.year == _dataSeconda!.year &&
        _dataPrima!.month == _dataSeconda!.month &&
        _dataPrima!.day == _dataSeconda!.day) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La seconda data deve essere diversa dalla prima.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final values = <String, String>{
        for (final key in _placeholders) key: _resolveValue(key),
        if (_placeholders.contains('luogo_data'))
          'luogo_data': 'Longiano, ${_formatDate(DateTime.now())}',
      };
      final filledBody = _fillTemplate(widget.template.body, values);
      final pdf = await _buildPdf(widget.template.title, filledBody);
      final bytes = await pdf.save();
      final filename = _buildFilename();

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: filename,
          format: PdfPageFormat.a4,
        );
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }

      if (!mounted) return;
      setState(() => _isGenerating = false);
      await _showDriveReminderDialog();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la generazione del PDF: $e')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _showDriveReminderDialog() async {
    var driveUrl = widget.sourceDeadline?.driveUrl;
    if (driveUrl == null || driveUrl.isEmpty) {
      try {
        driveUrl = await _governanceService.getDriveFolderUrl();
      } catch (_) {
        driveUrl = null;
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Documento generato'),
        content: const Text(
          'Stampa, compila e firma il documento, poi caricalo nella cartella Drive.',
        ),
        actions: [
          if (driveUrl != null)
            TextButton.icon(
              onPressed: () => _openUrl(driveUrl!),
              icon: const Icon(Icons.folder_shared_outlined),
              label: const Text('Apri la cartella Drive'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value == null ? 'Non impostata' : _formatDate(value)),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: () async {
        final picked = await _pickDate(value);
        if (picked != null) onChanged(picked);
      },
    );
  }

  Widget _buildTimeField(String label, TimeOfDay? value, ValueChanged<TimeOfDay?> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value == null ? 'Non impostata' : _formatTime(value)),
      trailing: const Icon(Icons.access_time_outlined),
      onTap: () async {
        final picked = await _pickTime(value);
        if (picked != null) onChanged(picked);
      },
    );
  }

  Widget _buildField(String key) {
    switch (key) {
      case 'sede_legale':
        return TextFormField(
          controller: _controllerFor('sede_legale'),
          decoration: const InputDecoration(labelText: 'Sede legale'),
        );
      case 'codice_fiscale':
        return TextFormField(
          controller: _controllerFor('codice_fiscale'),
          decoration: const InputDecoration(labelText: 'Codice fiscale'),
        );
      case 'presidente':
        return _buildNamePickerField('Presidente', 'presidente');
      case 'segretario':
        return _buildNamePickerField('Segretario', 'segretario');
      case 'presenti':
        return _buildAttendanceSection();
      case 'data':
        return _buildDateField('Data', _dataValue, (d) => setState(() => _dataValue = d));
      case 'ora':
        return _buildTimeField('Ora', _oraValue, (t) => setState(() => _oraValue = t));
      case 'luogo':
        return TextFormField(
          controller: _controllerFor('luogo'),
          decoration: const InputDecoration(labelText: 'Luogo'),
        );
      case 'ordine_del_giorno':
        return TextFormField(
          controller: _controllerFor('ordine_del_giorno'),
          decoration: const InputDecoration(labelText: 'Ordine del giorno'),
          maxLines: 5,
        );
      case 'convocazione':
        return DropdownButtonFormField<String>(
          initialValue: _convocazione,
          decoration: const InputDecoration(labelText: 'Convocazione'),
          items: const [
            DropdownMenuItem(value: 'prima', child: Text('Prima convocazione')),
            DropdownMenuItem(value: 'seconda', child: Text('Seconda convocazione')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _convocazione = value);
          },
        );
      case 'data_prima':
        return _buildDateField('Data prima convocazione', _dataPrima,
            (d) => setState(() => _dataPrima = d));
      case 'ora_prima':
        return _buildTimeField('Ora prima convocazione', _oraPrima,
            (t) => setState(() => _oraPrima = t));
      case 'data_seconda':
        return _buildDateField('Data seconda convocazione', _dataSeconda,
            (d) => setState(() => _dataSeconda = d));
      case 'ora_seconda':
        return _buildTimeField('Ora seconda convocazione', _oraSeconda,
            (t) => setState(() => _oraSeconda = t));
      case 'modalita':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_needsElectionWarning)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Attenzione: l\'elezione delle cariche si svolge in presenza.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _modalita,
              decoration: const InputDecoration(labelText: 'Modalità'),
              items: const [
                DropdownMenuItem(value: 'in presenza', child: Text('In presenza')),
                DropdownMenuItem(value: 'a distanza', child: Text('A distanza')),
                DropdownMenuItem(value: 'mista', child: Text('Mista')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _modalita = value);
              },
            ),
          ],
        );
      case 'trimestre':
        return DropdownButtonFormField<String>(
          initialValue: _trimestre,
          decoration: const InputDecoration(labelText: 'Trimestre'),
          items: _kTrimestreOptions
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _trimestre = value);
          },
        );
      default:
        return TextFormField(
          controller: _controllerFor(key),
          decoration: InputDecoration(labelText: key.replaceAll('_', ' ')),
          maxLines: 2,
        );
    }
  }

  Widget _buildNamePickerField(String label, String role) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextFormField(
            controller: _controllerFor(role),
            decoration: InputDecoration(labelText: label),
          ),
        ),
        if (_activeMembers.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_search_outlined),
            tooltip: 'Scegli tra i membri del consiglio',
            onSelected: (name) => setState(() => _controllerFor(role).text = name),
            itemBuilder: (context) => _activeMembers
                .map((m) => PopupMenuItem(value: m.fullName, child: Text(m.fullName)))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildAttendanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Presenti e assenti', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        ..._activeMembers.map((member) {
          final status = _memberAttendance[member.id] ?? _AttendanceStatus.none;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(member.fullName)),
                Checkbox(
                  value: status == _AttendanceStatus.present,
                  onChanged: (checked) {
                    setState(() {
                      _memberAttendance[member.id] =
                          checked == true ? _AttendanceStatus.present : _AttendanceStatus.none;
                    });
                  },
                ),
                const Text('Presente', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Checkbox(
                  value: status == _AttendanceStatus.absent,
                  onChanged: (checked) {
                    setState(() {
                      _memberAttendance[member.id] =
                          checked == true ? _AttendanceStatus.absent : _AttendanceStatus.none;
                    });
                  },
                ),
                const Text('Assente', style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _addNameController,
                decoration: const InputDecoration(labelText: 'Aggiungi un nome'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Aggiungi tra i presenti',
              onPressed: () => _addCustomName(true),
            ),
            IconButton(
              icon: const Icon(Icons.person_off_outlined),
              tooltip: 'Aggiungi tra gli assenti',
              onPressed: () => _addCustomName(false),
            ),
          ],
        ),
        if (_customPresent.isNotEmpty || _customAbsent.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in _customPresent)
                Chip(
                  label: Text('$name (presente)'),
                  onDeleted: () => setState(() => _customPresent.remove(name)),
                ),
              for (final name in _customAbsent)
                Chip(
                  label: Text('$name (assente)'),
                  onDeleted: () => setState(() => _customAbsent.remove(name)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.title),
        actions: [
          TextButton(
            onPressed: _isGenerating || _isLoading ? null : _generate,
            child: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Genera PDF', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.template.description != null &&
                    widget.template.description!.trim().isNotEmpty) ...[
                  Text(
                    widget.template.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
                for (final key in _fieldOrder) ...[
                  _buildField(key),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}
