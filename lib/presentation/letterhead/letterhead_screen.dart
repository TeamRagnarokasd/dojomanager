import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../models/receipt_model.dart' show OrganizationInfo;
import '../../services/asd_governance_service.dart';
import '../../services/asd_letterhead_service.dart';
import '../../services/italian_receipt_service.dart';

const String _kLogoAsset = 'assets/images/146804-1764638363594.jpg';

/// Sentinel per la sede legale predefinita (indirizzo di
/// ItalianReceiptService.getOrganizationInfo) — sempre la prima scelta e
/// preselezionata.
const String _kDefaultAddressId = '__default__';

/// Sentinel per un indirizzo inserito al volo e non salvato ("Salva per le
/// prossime volte" deselezionata) — vale solo per il documento corrente.
const String _kTransientAddressId = '__transient__';

/// Una voce del selettore "Sede": la sede legale predefinita, una sede
/// salvata in asd_letterhead_addresses, oppure quella inserita al volo.
class _AddressChoice {
  const _AddressChoice({
    required this.id,
    required this.label,
    required this.address,
  });

  final String id;
  final String label;
  final String address;
}

/// "Carta intestata": genera un documento Word (.docx, predefinito) o PDF con
/// la stessa intestazione/piè di pagina usati per le ricevute — logo, nome,
/// indirizzo, C.F., telefono ed email di [ItalianReceiptService.getOrganizationInfo].
///
/// Due scelte: pagina vuota, oppure con già scritto il paragrafo di apertura
/// per il presidente/legale rappresentante (letto da asd_board_members +
/// user_profiles — vedi [_buildLegalRepParagraph]). Nessun dato è scritto a
/// mano nel codice: un campo mancante diventa una riga "______" da compilare.
class LetterheadScreen extends StatefulWidget {
  const LetterheadScreen({Key? key}) : super(key: key);

  @override
  State<LetterheadScreen> createState() => _LetterheadScreenState();
}

class _LetterheadScreenState extends State<LetterheadScreen> {
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _loadError;

  OrganizationInfo? _orgInfo;
  Map<String, dynamic>? _legalRepProfile;

  String _selectedType = 'simple'; // 'simple' | 'legal_rep'
  String _selectedFormat = 'docx'; // 'docx' | 'pdf'

  List<AsdLetterheadAddress> _savedAddresses = [];
  _AddressChoice? _transientChoice;
  String _selectedAddressId = _kDefaultAddressId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orgInfo = await ItalianReceiptService().getOrganizationInfo();

      Map<String, dynamic>? legalRepProfile;
      try {
        final members = await AsdGovernanceService.instance.getBoardMembers(
          onlyActive: true,
        );
        AsdBoardMember? president;
        for (final member in members) {
          if (member.role == 'presidente') {
            president = member;
            break;
          }
        }
        if (president != null && president.fullName.trim().isNotEmpty) {
          final row = await Supabase.instance.client
              .from('user_profiles')
              .select(
                'first_name, last_name, birth_place, birth_date, '
                'codice_fiscale, tax_code, address_line, city, province, cap',
              )
              .ilike('full_name', president.fullName.trim())
              .maybeSingle();
          if (row != null) legalRepProfile = Map<String, dynamic>.from(row);
        }
      } catch (_) {
        // Best-effort: senza questi dati il paragrafo userà solo righe da
        // compilare a mano, ma la schermata resta comunque utilizzabile.
      }

      List<AsdLetterheadAddress> savedAddresses = [];
      try {
        savedAddresses = await AsdLetterheadService.instance.getAddresses();
      } catch (_) {
        // Best-effort: senza le sedi salvate resta comunque selezionabile
        // la sede legale predefinita e "Aggiungi nuova sede".
      }

      if (!mounted) return;
      setState(() {
        _orgInfo = orgInfo;
        _legalRepProfile = legalRepProfile;
        _savedAddresses = savedAddresses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Impossibile caricare i dati ASD: $e';
      });
    }
  }

  /// Tutte le voci del selettore "Sede", nell'ordine in cui vanno mostrate:
  /// sede legale predefinita, sedi salvate (per sort_order), e infine
  /// l'eventuale sede inserita al volo per questo solo documento.
  List<_AddressChoice> get _addressChoices => [
        _AddressChoice(
          id: _kDefaultAddressId,
          label: 'Sede legale (predefinita)',
          address: _orgInfo?.address ?? '',
        ),
        for (final saved in _savedAddresses)
          _AddressChoice(id: saved.id, label: saved.label, address: saved.address),
        if (_transientChoice != null) _transientChoice!,
      ];

  /// L'indirizzo effettivo da usare nel documento, in base alla sede
  /// scelta in [_selectedAddressId] — la sede legale predefinita se non è
  /// (più) tra le scelte disponibili (es. sede salvata eliminata altrove).
  String _resolveSelectedAddress() {
    for (final choice in _addressChoices) {
      if (choice.id == _selectedAddressId) return choice.address;
    }
    return _orgInfo?.address ?? '';
  }

  /// L'organizzazione con l'indirizzo sostituito dalla sede scelta nel
  /// selettore — C.F., telefono ed email restano sempre quelli reali
  /// dell'ASD, solo l'indirizzo cambia in intestazione, piè di pagina e
  /// nella frase del legale rappresentante.
  OrganizationInfo _effectiveOrgInfo() {
    final org = _orgInfo!;
    final address = _resolveSelectedAddress();
    if (address == org.address) return org;
    return OrganizationInfo(
      id: org.id,
      name: org.name,
      address: address,
      taxCode: org.taxCode,
      phone: org.phone,
      email: org.email,
      pec: org.pec,
    );
  }

  /// Riga vuota da compilare a mano quando un dato manca — stessa convenzione
  /// già usata in AsdDocumentGenerationScreen._fillTemplate.
  static const String _blank = '______________';

  String _orBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? _blank : trimmed;
  }

  /// "Il sottoscritto {nome} {cognome}, nato a {luogo} il {data}, codice
  /// fiscale {cf}, residente a {città} ({provincia}), {indirizzo}, in
  /// qualità di presidente e legale rappresentante di {ASD}, codice fiscale
  /// {C.F. ASD}, con sede in {indirizzo ASD},"
  ///
  /// Genere non adattabile: user_profiles non ha un campo sesso/genere per
  /// gli adulti (solo i profili bambino ce l'hanno), quindi resta sempre la
  /// forma maschile "Il sottoscritto" — nessun dato in più da cui dedurlo.
  ///
  /// [orgInfo] è già quello con l'indirizzo della sede scelta nel
  /// selettore (vedi _effectiveOrgInfo) — "con sede in ..." segue sempre la
  /// sede selezionata, non necessariamente quella legale.
  String _buildLegalRepParagraph(OrganizationInfo orgInfo) {
    final profile = _legalRepProfile;
    final firstName = _orBlank(profile?['first_name'] as String?);
    final lastName = _orBlank(profile?['last_name'] as String?);
    final birthPlace = _orBlank(profile?['birth_place'] as String?);

    final birthDateRaw = profile?['birth_date'] as String?;
    String birthDate = _blank;
    if (birthDateRaw != null && birthDateRaw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(birthDateRaw);
      if (parsed != null) birthDate = DateFormat('dd/MM/yyyy').format(parsed);
    }

    final codiceFiscale = _orBlank(
      (profile?['codice_fiscale'] as String?) ?? (profile?['tax_code'] as String?),
    );
    final city = _orBlank(profile?['city'] as String?);
    final province = _orBlank(profile?['province'] as String?);
    final addressLine = _orBlank(profile?['address_line'] as String?);

    final orgName = _orBlank(orgInfo.name);
    final orgTaxCode = _orBlank(orgInfo.taxCode);
    final orgAddress = _orBlank(orgInfo.address);

    return 'Il sottoscritto $firstName $lastName, nato a $birthPlace il $birthDate, '
        'codice fiscale $codiceFiscale, residente a $city ($province), $addressLine, '
        'in qualità di presidente e legale rappresentante di $orgName, codice '
        'fiscale $orgTaxCode, con sede in $orgAddress,';
  }

  // ───────────────────────────── PDF ─────────────────────────────

  Future<Uint8List> _buildPdfBytes({
    required bool includeLegalRepParagraph,
    required OrganizationInfo orgInfo,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    final logoBytes = await rootBundle.load(_kLogoAsset);
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final bodyText = includeLegalRepParagraph
        ? _buildLegalRepParagraph(orgInfo).replaceAll('€', 'euro')
        : '';

    final footerParts = <String>[
      if (orgInfo.address.isNotEmpty) orgInfo.address,
      if (orgInfo.taxCode.isNotEmpty) 'C.F. ${orgInfo.taxCode}',
      if (orgInfo.phone != null && orgInfo.phone!.isNotEmpty)
        'Tel. ${orgInfo.phone}',
      if (orgInfo.email != null && orgInfo.email!.isNotEmpty) orgInfo.email!,
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
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
                  pw.Container(
                    width: 60,
                    height: 60,
                    child: pw.Image(logoImage),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          orgInfo.name,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        if (orgInfo.address.isNotEmpty)
                          pw.Text(
                            orgInfo.address,
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
                          ),
                        if (orgInfo.taxCode.isNotEmpty)
                          pw.Text(
                            'C.F. ${orgInfo.taxCode}',
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 36),
            if (bodyText.isNotEmpty)
              pw.Text(
                bodyText,
                style: const pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.justify,
              ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Center(
              child: pw.Text(
                footerParts.join('   ·   '),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  // ──────────────────────────── DOCX ─────────────────────────────
  //
  // Costruito a mano con `archive` (già dipendenza transitiva di pdf/excel,
  // dichiarata esplicitamente in pubspec.yaml) invece di aggiungere una
  // libreria .docx pesante: un file .docx è semplicemente uno zip con questa
  // struttura minima OOXML, sufficiente perché Word e Google Docs lo aprano
  // senza errori.

  String _xmlEscape(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _docxContentTypesXml() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="jpeg" ContentType="image/jpeg"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
      '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
      '</Types>';

  String _docxRootRelsXml() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';

  String _docxDocumentRelsXml() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>'
      '</Relationships>';

  String _docxHeaderRelsXml() => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.jpeg"/>'
      '</Relationships>';

  String _docxHeaderXml(OrganizationInfo orgInfo) {
    final contactParts = <String>[
      if (orgInfo.taxCode.isNotEmpty) 'C.F. ${orgInfo.taxCode}',
      if (orgInfo.phone != null && orgInfo.phone!.isNotEmpty) 'Tel. ${orgInfo.phone}',
      if (orgInfo.email != null && orgInfo.email!.isNotEmpty) orgInfo.email!,
    ];
    final addressParagraph = orgInfo.address.isNotEmpty
        ? '<w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="666666"/></w:rPr>'
            '<w:t xml:space="preserve">${_xmlEscape(orgInfo.address)}</w:t></w:r></w:p>'
        : '';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<w:p><w:r><w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="720000" cy="720000"/>'
        '<wp:docPr id="1" name="Logo"/>'
        '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic>'
        '<pic:nvPicPr><pic:cNvPr id="0" name="Logo"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="720000" cy="720000"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic>'
        '</a:graphicData></a:graphic>'
        '</wp:inline>'
        '</w:drawing></w:r></w:p>'
        '<w:p><w:pPr><w:spacing w:before="120"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="28"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEscape(orgInfo.name)}</w:t></w:r></w:p>'
        '$addressParagraph'
        '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="4" w:color="CC0000"/></w:pBdr>'
        '<w:spacing w:after="120"/></w:pPr><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="666666"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEscape(contactParts.join('   ·   '))}</w:t></w:r></w:p>'
        '</w:hdr>';
  }

  String _docxFooterXml(OrganizationInfo orgInfo) {
    final line2Parts = <String>[
      if (orgInfo.taxCode.isNotEmpty) 'C.F. ${orgInfo.taxCode}',
      if (orgInfo.phone != null && orgInfo.phone!.isNotEmpty) 'Tel. ${orgInfo.phone}',
      if (orgInfo.email != null && orgInfo.email!.isNotEmpty) orgInfo.email!,
    ];
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:p><w:pPr><w:pBdr><w:top w:val="single" w:sz="6" w:space="4" w:color="999999"/></w:pBdr>'
        '<w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:sz w:val="16"/><w:color w:val="666666"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEscape(orgInfo.address)}</w:t></w:r></w:p>'
        '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:sz w:val="16"/><w:color w:val="666666"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEscape(line2Parts.join('   ·   '))}</w:t></w:r></w:p>'
        '</w:ftr>';
  }

  String _docxDocumentXml(bool includeLegalRepParagraph, OrganizationInfo orgInfo) {
    final body = StringBuffer();
    if (includeLegalRepParagraph) {
      final text = _buildLegalRepParagraph(orgInfo).replaceAll('€', 'euro');
      body.write(
        '<w:p><w:pPr><w:jc w:val="both"/></w:pPr><w:r><w:rPr><w:sz w:val="22"/></w:rPr>'
        '<w:t xml:space="preserve">${_xmlEscape(text)}</w:t></w:r></w:p>',
      );
    }
    body.write('<w:p/>');
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:body>'
        '$body'
        '<w:sectPr>'
        '<w:headerReference w:type="default" r:id="rId1"/>'
        '<w:footerReference w:type="default" r:id="rId2"/>'
        '<w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="2268" w:right="1417" w:bottom="1417" w:left="1417" w:header="708" w:footer="708" w:gutter="0"/>'
        '</w:sectPr>'
        '</w:body>'
        '</w:document>';
  }

  Future<Uint8List> _buildDocxBytes({
    required bool includeLegalRepParagraph,
    required OrganizationInfo orgInfo,
  }) async {
    final logoData = (await rootBundle.load(_kLogoAsset)).buffer.asUint8List();

    final archive = Archive();
    void addText(String path, String content) {
      final data = Uint8List.fromList(utf8.encode(content));
      archive.addFile(ArchiveFile(path, data.length, data));
    }

    addText('[Content_Types].xml', _docxContentTypesXml());
    addText('_rels/.rels', _docxRootRelsXml());
    addText(
      'word/document.xml',
      _docxDocumentXml(includeLegalRepParagraph, orgInfo),
    );
    addText('word/_rels/document.xml.rels', _docxDocumentRelsXml());
    addText('word/header1.xml', _docxHeaderXml(orgInfo));
    addText('word/_rels/header1.xml.rels', _docxHeaderRelsXml());
    addText('word/footer1.xml', _docxFooterXml(orgInfo));
    archive.addFile(
      ArchiveFile('word/media/image1.jpeg', logoData.length, logoData),
    );

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Impossibile creare il file .docx');
    }
    return Uint8List.fromList(zipBytes);
  }

  // ─────────────────────── Condivisione/Download ───────────────────────

  Future<void> _shareOrDownload(
    Uint8List bytes,
    String filename,
    String mimeType, {
    required bool isPdf,
  }) async {
    if (kIsWeb) {
      if (isPdf) {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: filename,
          format: PdfPageFormat.a4,
        );
      } else {
        final blob = html.Blob([bytes], mimeType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } else {
      if (isPdf) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)]);
      }
    }
  }

  Future<void> _generate() async {
    if (_orgInfo == null) return;
    setState(() => _isGenerating = true);
    try {
      final isLegalRep = _selectedType == 'legal_rep';
      final baseName = isLegalRep
          ? 'carta_intestata_legale_rappresentante'
          : 'carta_intestata_semplice';
      final isPdf = _selectedFormat == 'pdf';
      final effectiveOrgInfo = _effectiveOrgInfo();

      final Uint8List bytes;
      final String filename;
      final String mimeType;
      if (isPdf) {
        bytes = await _buildPdfBytes(
          includeLegalRepParagraph: isLegalRep,
          orgInfo: effectiveOrgInfo,
        );
        filename = '$baseName.pdf';
        mimeType = 'application/pdf';
      } else {
        bytes = await _buildDocxBytes(
          includeLegalRepParagraph: isLegalRep,
          orgInfo: effectiveOrgInfo,
        );
        filename = '$baseName.docx';
        mimeType =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      }

      await _shareOrDownload(bytes, filename, mimeType, isPdf: isPdf);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la generazione: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ──────────────────────────── UI ────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carta intestata')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewPadding.bottom + 16,
              ),
              children: [
                if (_loadError != null) ...[
                  Text(
                    _loadError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Tipo di documento',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _buildTypeCard(
                  value: 'simple',
                  title: 'Carta intestata semplice',
                  subtitle: 'Pagina vuota con intestazione e piè di pagina.',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 8),
                _buildTypeCard(
                  value: 'legal_rep',
                  title: 'Con legale rappresentante',
                  subtitle:
                      'Stessa intestazione, con già scritto il paragrafo del legale rappresentante.',
                  icon: Icons.person_pin_outlined,
                ),
                const SizedBox(height: 24),
                Text(
                  'Formato',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Word (.docx)'),
                      selected: _selectedFormat == 'docx',
                      onSelected: (_) => setState(() => _selectedFormat = 'docx'),
                    ),
                    ChoiceChip(
                      label: const Text('PDF'),
                      selected: _selectedFormat == 'pdf',
                      onSelected: (_) => setState(() => _selectedFormat = 'pdf'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Sede',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tieni premuta una sede salvata per eliminarla.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in _addressChoices)
                      GestureDetector(
                        onLongPress: choice.id == _kDefaultAddressId
                            ? null
                            : () => _onAddressLongPress(choice),
                        child: ChoiceChip(
                          label: Text(choice.label),
                          selected: _selectedAddressId == choice.id,
                          onSelected: (_) =>
                              setState(() => _selectedAddressId = choice.id),
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Aggiungi nuova sede'),
                      onPressed: _showAddAddressDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating || _orgInfo == null ? null : _generate,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share),
                    label: Text(_isGenerating ? 'Generazione in corso…' : 'Genera'),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _onAddressLongPress(_AddressChoice choice) async {
    // La sede inserita al volo (non salvata) non è in asd_letterhead_addresses:
    // "eliminarla" significa solo smettere di usarla, senza chiamate al server.
    if (choice.id == _kTransientAddressId) {
      final confirmed = await _confirmDeleteDialog(choice);
      if (confirmed != true) return;
      setState(() {
        _transientChoice = null;
        if (_selectedAddressId == choice.id) {
          _selectedAddressId = _kDefaultAddressId;
        }
      });
      return;
    }

    AsdLetterheadAddress? saved;
    for (final s in _savedAddresses) {
      if (s.id == choice.id) {
        saved = s;
        break;
      }
    }
    if (saved == null) return;

    final confirmed = await _confirmDeleteDialog(choice);
    if (confirmed != true) return;

    try {
      await AsdLetterheadService.instance.deleteAddress(saved.id);
      if (!mounted) return;
      setState(() {
        _savedAddresses = _savedAddresses.where((a) => a.id != saved!.id).toList();
        if (_selectedAddressId == choice.id) {
          _selectedAddressId = _kDefaultAddressId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile eliminare la sede: $e')),
      );
    }
  }

  Future<bool?> _confirmDeleteDialog(_AddressChoice choice) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminare questa sede?'),
        content: Text('«${choice.label}»\n${choice.address}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAddressDialog() async {
    final addressController = TextEditingController();
    final labelController = TextEditingController();
    bool saveForNextTime = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Aggiungi nuova sede'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Indirizzo completo',
                    hintText: 'Via ..., CAP Città (Prov)',
                  ),
                  maxLines: 2,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Etichetta breve'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: saveForNextTime,
                  title: const Text('Salva per le prossime volte'),
                  onChanged: (value) => setDialogState(
                    () => saveForNextTime = value ?? saveForNextTime,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                final address = addressController.text.trim();
                if (address.isEmpty) return;
                Navigator.pop(dialogContext, {
                  'address': address,
                  'label': labelController.text.trim(),
                  'save': saveForNextTime,
                });
              },
              child: const Text('Aggiungi'),
            ),
          ],
        ),
      ),
    );
    addressController.dispose();
    labelController.dispose();
    if (result == null) return;

    final address = result['address'] as String;
    final rawLabel = result['label'] as String;
    final label = rawLabel.isNotEmpty
        ? rawLabel
        : (address.length > 30 ? '${address.substring(0, 30)}…' : address);
    final save = result['save'] as bool;

    if (!save) {
      setState(() {
        _transientChoice =
            _AddressChoice(id: _kTransientAddressId, label: label, address: address);
        _selectedAddressId = _kTransientAddressId;
      });
      return;
    }

    try {
      final nextSortOrder = _savedAddresses.isEmpty
          ? 1
          : _savedAddresses
                  .map((a) => a.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      final newAddress = await AsdLetterheadService.instance.addAddress(
        label: label,
        address: address,
        sortOrder: nextSortOrder,
      );
      if (!mounted) return;
      setState(() {
        _savedAddresses = [..._savedAddresses, newAddress];
        _selectedAddressId = newAddress.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _transientChoice =
            _AddressChoice(id: _kTransientAddressId, label: label, address: address);
        _selectedAddressId = _kTransientAddressId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Non salvata, usata solo per questo documento: $e'),
        ),
      );
    }
  }

  Widget _buildTypeCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _selectedType == value;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      color: selected ? colorScheme.primary.withValues(alpha: 0.08) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedType = value),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: selected ? colorScheme.primary : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Radio<String>(
                value: value,
                groupValue: _selectedType,
                onChanged: (v) => setState(() => _selectedType = v ?? _selectedType),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
