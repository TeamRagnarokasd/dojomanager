import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;

/// Service to generate and save the terms acceptance document
/// when a user completes registration.
class TermsDocumentService {
  final SupabaseClient _client = Supabase.instance.client;
  final Dio _dio = Dio();

  static const String _termsText = '''MODULO DI ISCRIZIONE E REGOLAMENTO INTERNO
TEAM RAGNAROK A.S.D.
============================================================

1. ACCETTAZIONE DEL REGOLAMENTO E COMPORTAMENTO

Con la presente iscrizione, il sottoscritto (o il genitore/tutore legale per i minori) dichiara di aver preso visione e di accettare integralmente il regolamento interno del Team Ragnarok.

Il partecipante si impegna a mantenere un comportamento rispettoso e leale verso gli istruttori, i compagni di squadra, gli avversari e chiunque sia presente durante gli allenamenti, gli eventi e le competizioni.

E\' severamente vietato commettere atti che costituiscano reato o che siano contrari alla legge. Qualsiasi comportamento illegale o gravemente scorretto comportera\' l\'immediata espulsione dal team, senza diritto a rimborso.

Il partecipante si impegna a rispettare le attrezzature, le strutture di allenamento e le norme di sicurezza stabilite dagli istruttori.

------------------------------------------------------------

2. LIBERATORIA PER LA DIFFUSIONE DI IMMAGINI (FOTOGRAFIE E VIDEO)

Il sottoscritto acconsente alla ripresa e alla pubblicazione di proprie immagini, fotografie e/o video realizzati durante gli allenamenti, le competizioni, gli stage o qualsiasi altro evento ufficiale del Team Ragnarok.

Le immagini potranno essere pubblicate sui canali ufficiali del Team Ragnarok, inclusi sito web, profili social media, materiale promozionale e articoli di giornale.

------------------------------------------------------------

3. CONSENSO AL TRATTAMENTO DEI DATI PERSONALI (GDPR)

Con la presente, ai sensi del Regolamento UE 2016/679 (GDPR), si autorizza il Team Ragnarok al trattamento dei dati personali forniti in questo modulo per le finalita\' associative e di legge.

============================================================
DICHIARAZIONE DI ACCETTAZIONE

Il sottoscritto dichiara di aver letto, compreso e accettato integralmente:
[X] I Termini e Condizioni del Regolamento Interno
[X] Il trattamento dei dati personali (GDPR)
[X] La liberatoria per la diffusione di immagini
============================================================''';

  static const String _childTermsText =
      '''MODULO ISCRIZIONE MINORE (UNDER 14) E REGOLAMENTO INTERNO
TEAM RAGNAROK A.S.D.
============================================================

1. ACCETTAZIONE DEL REGOLAMENTO, CONDOTTA DEL MINORE E CODICE ETICO DEI GENITORI/TUTORI

Con la presente iscrizione, il genitore/tutore legale esercitante la responsabilita\' genitoriale sul minore dichiara di aver preso visione e di accettare integralmente il regolamento interno del Team Ragnarok A.S.D.

A) Condotta del Minore:
Il minore si impegna a mantenere un comportamento rispettoso, disciplinato e leale verso gli istruttori, i compagni di squadra, gli avversari e le strutture. E\' severamente vietato qualsiasi atto di bullismo, violenza verbale o fisica non sportiva, dentro e fuori dal campo di allenamento.

B) Codice di Comportamento dei Genitori e Tutori Legali:
I genitori/tutori si impegnano a sostenere il percorso sportivo del minore in modo sano e positivo. In particolare e\' fatto obbligo di:

- Rispettare sempre le decisioni tecniche degli istruttori e i giudizi arbitrali durante le gare e le competizioni.
- Mantenere un comportamento educato, corretto e decoroso sugli spalti e nelle aree di gara.
- Non interferire con le lezioni, gli allenamenti o la gestione dell\'atleta durante le gare.

N.B.: Il mancato rispetto del presente codice di comportamento da parte dei genitori potra\' comportare la sospensione o l\'espulsione immediata del minore dal team, a discrezione della direzione, senza diritto ad alcun rimborso.

------------------------------------------------------------

2. LIBERATORIA PER LA DIFFUSIONE DI IMMAGINI DI MINORI (FOTOGRAFIE E VIDEO)

Il genitore/tutore legale autorizza a titolo gratuito il Team Ragnarok A.S.D. alla ripresa, trasmissione e pubblicazione delle immagini ritraenti il minore durante gli allenamenti, i corsi, le competizioni, gli stage e ogni altro evento ufficiale del team.

------------------------------------------------------------

3. CONSENSO AL TRATTAMENTO DEI DATI PERSONALI DEL MINORE (GDPR UE 2016/679)

Ai sensi del Regolamento UE 2016/679 (GDPR), il genitore/tutore autorizza il Team Ragnarok A.S.D. al trattamento dei dati personali propri e del minore registrato per le finalita\' associative e di legge.

============================================================
DICHIARAZIONE DI ACCETTAZIONE

Il genitore/tutore legale dichiara di aver letto, compreso e accettato integralmente in nome e per conto del minore:
[X] I Termini e Condizioni, il Regolamento Minori e il Codice Etico Genitori
[X] Il trattamento dei dati personali (GDPR) del minore e del genitore
[X] La liberatoria per la diffusione di immagini e video del minore

============================================================
''';

  /// Fetches the public IP address of the user
  Future<String> _getPublicIpAddress() async {
    try {
      final response = await _dio.get(
        'https://api.ipify.org',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.statusCode == 200) {
        return response.data.toString().trim();
      }
    } catch (e) {
      debugPrint('Could not fetch IP address: $e');
    }
    return 'Non disponibile';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PDF GENERATION HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates a PDF document from plain text content
  Future<Uint8List> _generatePdfFromText(String title, String content) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          final paragraphs = content.split('\n');
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            ...paragraphs.map((line) {
              if (line.trim().isEmpty) {
                return pw.SizedBox(height: 6);
              }
              final isSeparator =
                  line.startsWith('===') || line.startsWith('---');
              final isHeader = line.startsWith('TEAM RAGNAROK') ||
                  RegExp(r'^\d+\.').hasMatch(line.trim()) ||
                  line.startsWith('A)') ||
                  line.startsWith('B)') ||
                  line.startsWith('N.B.:') ||
                  line.startsWith('DATI DI') ||
                  line.startsWith('DICHIARAZIONE') ||
                  line.startsWith('MODULO');
              if (isSeparator) {
                return pw.Divider(thickness: 0.5);
              }
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text(
                  line,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Downloads a PDF in the browser (web) or opens it externally (mobile)
  Future<void> downloadPdfBytes(Uint8List pdfBytes, String fileName) async {
    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // On mobile, upload to a temp signed URL and open
      // For simplicity, we open the stored document URL
      debugPrint('PDF download on mobile: $fileName');
    }
  }

  /// Generates and downloads the adult terms PDF for a given user document
  Future<void> downloadAdultTermsPdf({
    required String userName,
    required String userEmail,
    required DateTime acceptedAt,
    required String ipAddress,
  }) async {
    final italianMonths = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];

    final day = acceptedAt.day.toString().padLeft(2, '0');
    final month = italianMonths[acceptedAt.month - 1];
    final year = acceptedAt.year;
    final hour = acceptedAt.hour.toString().padLeft(2, '0');
    final minute = acceptedAt.minute.toString().padLeft(2, '0');
    final second = acceptedAt.second.toString().padLeft(2, '0');

    final footer = '''
DATI DI ACCETTAZIONE
============================================================
Utente:        $userName
Email:         $userEmail
Data:          $day $month $year
Ora:           $hour:$minute:$second (UTC)
Indirizzo IP:  $ipAddress
============================================================
Documento generato automaticamente dal sistema Team Ragnarok ASD
''';

    final fullContent = _termsText + footer;
    final pdfBytes = await _generatePdfFromText(
      'Modulo di Iscrizione e Regolamento Interno - Team Ragnarok ASD',
      fullContent,
    );
    await downloadPdfBytes(pdfBytes, 'termini_iscrizione_adulti.pdf');
  }

  /// Generates and downloads the child (under-14) terms PDF
  Future<void> downloadChildTermsPdf({
    required String guardianName,
    required String guardianEmail,
    required String childName,
    required DateTime acceptedAt,
    required String ipAddress,
    bool imageConsent = false,
  }) async {
    final italianMonths = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];

    final day = acceptedAt.day.toString().padLeft(2, '0');
    final month = italianMonths[acceptedAt.month - 1];
    final year = acceptedAt.year;
    final hour = acceptedAt.hour.toString().padLeft(2, '0');
    final minute = acceptedAt.minute.toString().padLeft(2, '0');
    final second = acceptedAt.second.toString().padLeft(2, '0');

    final imageConsentLine = imageConsent
        ? '[X] La liberatoria per la diffusione di immagini e video del minore'
        : '[ ] La liberatoria per la diffusione di immagini e video del minore (NON ACCETTATA)';

    final footer = '''
DATI DI ACCETTAZIONE
============================================================
Minore:        $childName
Genitore/Tutore: $guardianName
Email:         $guardianEmail
Data:          $day $month $year
Ora:           $hour:$minute:$second (UTC)
Indirizzo IP:  $ipAddress

RIEPILOGO CONSENSI:
[X] I Termini e Condizioni, il Regolamento Minori e il Codice Etico Genitori
[X] Il trattamento dei dati personali (GDPR) del minore e del genitore
$imageConsentLine
============================================================
Documento generato automaticamente dal sistema Team Ragnarok ASD
''';

    final fullContent = _childTermsText + footer;
    final pdfBytes = await _generatePdfFromText(
      'Modulo Iscrizione Minore (Under 14) - Team Ragnarok ASD',
      fullContent,
    );
    await downloadPdfBytes(pdfBytes, 'termini_iscrizione_minore_under14.pdf');
  }

  /// Generates and downloads the 14-17 minor terms PDF
  Future<void> downloadMinor1417TermsPdf({
    required String minorFullName,
    required String minorTaxCode,
    required String minorBirthDate,
    required String parentFullName,
    required String parentTaxCode,
    required String parentDocumentNumber,
    required String userEmail,
    required DateTime generatedAt,
    required String ipAddress,
  }) async {
    final italianMonths = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];

    final day = generatedAt.day.toString().padLeft(2, '0');
    final month = italianMonths[generatedAt.month - 1];
    final year = generatedAt.year;
    final hour = generatedAt.hour.toString().padLeft(2, '0');
    final minute = generatedAt.minute.toString().padLeft(2, '0');

    final dataSection =
        '''Minore: $minorFullName | C.F.: $minorTaxCode | Nato il: $minorBirthDate
Genitore/Tutore: $parentFullName | C.F.: $parentTaxCode | Doc. Identita\' N.: $parentDocumentNumber
Email: $userEmail
Data Generazione Documento: $day $month $year $hour:$minute UTC
Indirizzo IP: $ipAddress

Firma per esteso del Minore (14-17 anni): ____________________________________

Firma per esteso del Genitore / Tutore Legale: ____________________________________

(E\' obbligatorio allegare al presente modulo ricaricato nell\'app la copia del documento d\'identita\' del genitore/tutore legale in corso di validita\').

================================================================================
Documento generato automaticamente dall\'app Team Ragnarok ASD''';

    final fullContent = _minor1417TermsTemplate + dataSection;
    final pdfBytes = await _generatePdfFromText(
      'Modulo Iscrizione Minore (14-17 anni) - Team Ragnarok ASD',
      fullContent,
    );
    await downloadPdfBytes(pdfBytes, 'modulo_minore_14_17_anni.pdf');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DOCUMENT BYTES GENERATION (for storage upload)
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates the terms acceptance document content as plain text bytes
  Uint8List _generateDocumentBytes({
    required String userName,
    required String userEmail,
    required String ipAddress,
    required DateTime acceptedAt,
  }) {
    final italianMonths = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];

    final day = acceptedAt.day.toString().padLeft(2, '0');
    final month = italianMonths[acceptedAt.month - 1];
    final year = acceptedAt.year;
    final hour = acceptedAt.hour.toString().padLeft(2, '0');
    final minute = acceptedAt.minute.toString().padLeft(2, '0');
    final second = acceptedAt.second.toString().padLeft(2, '0');

    final footer = '''
DATI DI ACCETTAZIONE
============================================================
Utente:        $userName
Email:         $userEmail
Data:          $day $month $year
Ora:           $hour:$minute:$second (UTC)
Indirizzo IP:  $ipAddress
============================================================
Documento generato automaticamente dal sistema Team Ragnarok ASD
''';

    final fullContent = _termsText + footer;
    return Uint8List.fromList(utf8.encode(fullContent));
  }

  /// Generates and uploads the terms acceptance document for the given user.
  /// Must be called while the user is still authenticated (before signOut).
  Future<void> saveTermsAcceptanceDocument({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    try {
      final acceptedAt = DateTime.now().toUtc();
      final ipAddress = await _getPublicIpAddress();

      final documentBytes = _generateDocumentBytes(
        userName: userName,
        userEmail: userEmail,
        ipAddress: ipAddress,
        acceptedAt: acceptedAt,
      );

      final timestamp = acceptedAt.millisecondsSinceEpoch;
      final fileName = 'termini_accettati_$timestamp.txt';
      final filePath = '$userId/$fileName';

      await _client.storage.from('user_docs').uploadBinary(
            filePath,
            documentBytes,
            fileOptions: const FileOptions(
              contentType: 'text/plain; charset=utf-8',
              upsert: false,
            ),
          );

      final italianMonthsShort = [
        'gen',
        'feb',
        'mar',
        'apr',
        'mag',
        'giu',
        'lug',
        'ago',
        'set',
        'ott',
        'nov',
        'dic',
      ];
      final dateLabel =
          '${acceptedAt.day.toString().padLeft(2, '0')} ${italianMonthsShort[acceptedAt.month - 1]} ${acceptedAt.year}';

      // Use SECURITY DEFINER RPC to bypass RLS during registration
      await _client.rpc('save_registration_document', params: {
        'p_user_id': userId,
        'p_file_name': 'Termini e Condizioni Accettati',
        'p_file_url': filePath,
        'p_file_type': 'document',
        'p_document_type': 'terms_acceptance',
        'p_document_label': 'Termini accettati il $dateLabel',
      });

      debugPrint(
          'Terms acceptance document saved successfully for user $userId');
    } catch (e) {
      debugPrint('Warning: Could not save terms acceptance document: $e');
    }
  }

  /// Generates and uploads the child terms acceptance document.
  Future<void> saveChildTermsAcceptanceDocument({
    required String guardianUserId,
    required String guardianName,
    required String guardianEmail,
    required String childName,
    bool imageConsent = false,
  }) async {
    try {
      final acceptedAt = DateTime.now().toUtc();
      final ipAddress = await _getPublicIpAddress();

      final italianMonths = [
        'gennaio',
        'febbraio',
        'marzo',
        'aprile',
        'maggio',
        'giugno',
        'luglio',
        'agosto',
        'settembre',
        'ottobre',
        'novembre',
        'dicembre',
      ];

      final day = acceptedAt.day.toString().padLeft(2, '0');
      final month = italianMonths[acceptedAt.month - 1];
      final year = acceptedAt.year;
      final hour = acceptedAt.hour.toString().padLeft(2, '0');
      final minute = acceptedAt.minute.toString().padLeft(2, '0');
      final second = acceptedAt.second.toString().padLeft(2, '0');

      final imageConsentLine = imageConsent
          ? '[X] La liberatoria per la diffusione di immagini e video del minore'
          : '[ ] La liberatoria per la diffusione di immagini e video del minore (NON ACCETTATA)';

      final footer = '''
DATI DI ACCETTAZIONE
============================================================
Minore:        $childName
Genitore/Tutore: $guardianName
Email:         $guardianEmail
Data:          $day $month $year
Ora:           $hour:$minute:$second (UTC)
Indirizzo IP:  $ipAddress

RIEPILOGO CONSENSI:
[X] I Termini e Condizioni, il Regolamento Minori e il Codice Etico Genitori
[X] Il trattamento dei dati personali (GDPR) del minore e del genitore
$imageConsentLine
============================================================
Documento generato automaticamente dal sistema Team Ragnarok ASD
''';

      final fullContent = _childTermsText + footer;
      final documentBytes = Uint8List.fromList(utf8.encode(fullContent));

      final timestamp = acceptedAt.millisecondsSinceEpoch;
      final safeChildName =
          childName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final fileName = 'termini_minore_${safeChildName}_$timestamp.txt';
      final filePath = '$guardianUserId/$fileName';

      await _client.storage.from('user_docs').uploadBinary(
            filePath,
            documentBytes,
            fileOptions: const FileOptions(
              contentType: 'text/plain; charset=utf-8',
              upsert: false,
            ),
          );

      final italianMonthsShort = [
        'gen',
        'feb',
        'mar',
        'apr',
        'mag',
        'giu',
        'lug',
        'ago',
        'set',
        'ott',
        'nov',
        'dic',
      ];
      final dateLabel =
          '${acceptedAt.day.toString().padLeft(2, '0')} ${italianMonthsShort[acceptedAt.month - 1]} ${acceptedAt.year}';

      // Use SECURITY DEFINER RPC to bypass RLS during registration
      await _client.rpc('save_registration_document', params: {
        'p_user_id': guardianUserId,
        'p_file_name': 'Termini Minore - $childName',
        'p_file_url': filePath,
        'p_file_type': 'document',
        'p_document_type': 'child_terms_acceptance',
        'p_document_label':
            'Modulo iscrizione minore ($childName) - $dateLabel',
      });

      debugPrint(
          'Child terms acceptance document saved for guardian $guardianUserId, child: $childName');
    } catch (e) {
      debugPrint('Warning: Could not save child terms acceptance document: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 14-17 MINOR TERMS DOCUMENT
  // ─────────────────────────────────────────────────────────────────────────

  static const String _minor1417TermsTemplate =
      '''MODULO DI ISCRIZIONE MINORE (14-17 ANNI), REGOLAMENTO INTERNO E CONSENSO GENITORIALE

TEAM RAGNAROK A.S.D.

================================================================================



1. ACCETTAZIONE DEL REGOLAMENTO, CONDOTTA DEL MINORE E CODICE ETICO GENITORI/TUTORI



A) Condotta del Minore:

Il sottoscritto minore (di eta\' compresa tra i 14 e i 17 anni) dichiara di aver preso visione e di accettare integralmente il regolamento interno del Team Ragnarok A.S.D.

Il minore si impegna a mantenere un comportamento rispettoso, disciplinato e leale verso gli istruttori, i compagni di squadra, gli avversari e le strutture. E\' severamente vietato qualsiasi atto di bullismo, violenza verbale o fisica non sportiva, dentro e fuori dal campo di allenamento. E\' severamente vietato commettere atti che costituiscano reato o che siano contrari alla legge; qualsiasi comportamento illecito o gravemente scorretto comportera\' l\'immediata espulsione dal team, senza diritto a rimborso.



B) Autorizzazione, Manleva e Codice di Comportamento dei Genitori e Tutori Legali:

Il genitore/tutore legale esercitante la responsabilita\' genitoriale sul minore autorizza la richiesta di iscrizione e la partecipazione del minore alle attivita\' sportive e promozionali del Team Ragnarok A.S.D., assumendosi la responsabilita\' per le dichiarazioni rese e la veridicita\' dei dati forniti.

I genitori/tutori si impegnano a sostenere il percorso sportivo del minore in modo sano e positivo. In particolare e\' fatto obbligo di:

- Rispettare sempre le decisioni tecniche degli istruttori e i giudizi arbitrali durante le gare e le competizioni.

- Mantenere un comportamento educato, corretto e decoroso sugli spalti e nelle aree di gara, evitando qualsiasi tipo di insulto, protesta accesa, linguaggio volgare o condotta anti-sportiva verso arbitri, atleti, coach o altri genitori.

- Non interferire con le lezioni, gli allenamenti o la gestione dell\'atleta all\'angolo/bordo matassina/ring/gabbia durante le gare. I genitori devono stazionare esclusivamente nelle aree riservate al pubblico.



N.B.: Il mancato rispetto del presente codice di comportamento da parte dei genitori potra\' comportare la sospensione o l\'espulsione immediata del minore dal team, a discrezione della direzione, senza diritto ad alcun rimborso.



--------------------------------------------------------------------------------



2. LIBERATORIA PER LA DIFFUSIONE DI IMMAGINI DI MINORI (FOTOGRAFIE E VIDEO)



I sottoscritti (minore e genitore/tutore legale) autorizzano a titolo gratuito il Team Ragnarok A.S.D., ai sensi degli artt. 10 e 96 Legge 633/1941 e dell\'art. 96 D.Lgs. 196/2003, alla ripresa, trasmissione e pubblicazione delle immagini (fotografie e/o video) ritraenti il minore, realizzate durante gli allenamenti, i corsi, le competizioni, gli stage e ogni altro evento ufficiale del team.



Le immagini e i video potranno essere utilizzati a scopo promozionale, divulgativo e istituzionale sulle piattaforme ufficiali del Team Ragnarok A.S.D., inclusi a titolo esemplificativo:

- Profilo e canali social media ufficiali (es. Instagram, Facebook, YouTube, TikTok).

- Sito web ufficiale della A.S.D.

- Materiale cartaceo promozionale (volantini, locandine, brochure).

- Articoli di giornale, rassegne stampa e servizi mediatici.



La presente liberatoria ha validita\' illimitata nel tempo, salvo revoca scritta da comunicare tramite email o raccomandata A/R alla direzione della A.S.D.



--------------------------------------------------------------------------------



3. CONSENSO AL TRATTAMENTO DEI DATI PERSONALI DEL MINORE E DEL GENITORE (GDPR UE 2016/679 E D.LGS. 196/2003 E SS.MM.II.)



Ai sensi del Regolamento UE 2016/679 (GDPR) e del D.Lgs. 196/2003 (come modificato dal D.Lgs. 101/2018, con particolare riferimento all\'art. 2-quinquies sul consenso del minore che ha compiuto i 14 anni), si autorizza il Team Ragnarok A.S.D. al trattamento dei dati personali propri e del minore registrato per le seguenti finalita\':

- Gestione amministrativa, contabile e tesseramento presso le Federazioni Sportive / Enti di Promozione Sportiva riconosciuti (es. tesseramento, assicurazione).

- Comunicazioni operative relative agli allenamenti, orari, eventi e gare.

- Gestione della liberatoria immagini come descritto al punto 2.



I dati saranno conservati per il tempo strettamente necessario all\'adempimento delle finalita\' associative e di legge. In qualsiasi momento e\' possibile esercitare i diritti previsti dal GDPR (accesso, rettifica, cancellazione, limitazione, opposizione) contattando il titolare del trattamento dati.



--------------------------------------------------------------------------------



DICHIARAZIONE DI ACCETTAZIONE E SOTTOSCRIZIONE



I sottoscritti dichiarano di aver letto, compreso e accettato integralmente:

[X] I Termini e Condizioni, il Regolamento Minori (14-17 anni) e il Codice Etico Genitori

[X] Il trattamento dei dati personali (GDPR) del minore e del genitore

[X] La liberatoria per la diffusione di immagini e video del minore



DATI DI ACCETTAZIONE E FIRME:

''';

  /// Generates and uploads the 14-17 minor terms acceptance document.
  Future<void> saveMinor1417TermsDocument({
    required String userId,
    required String minorFullName,
    required String minorTaxCode,
    required String minorBirthDate,
    required String parentFullName,
    required String parentTaxCode,
    required String parentDocumentNumber,
    required String userEmail,
  }) async {
    try {
      final acceptedAt = DateTime.now().toUtc();
      final ipAddress = await _getPublicIpAddress();

      final italianMonths = [
        'gennaio',
        'febbraio',
        'marzo',
        'aprile',
        'maggio',
        'giugno',
        'luglio',
        'agosto',
        'settembre',
        'ottobre',
        'novembre',
        'dicembre',
      ];

      final day = acceptedAt.day.toString().padLeft(2, '0');
      final month = italianMonths[acceptedAt.month - 1];
      final year = acceptedAt.year;
      final hour = acceptedAt.hour.toString().padLeft(2, '0');
      final minute = acceptedAt.minute.toString().padLeft(2, '0');

      final dataSection =
          '''Minore: $minorFullName | C.F.: $minorTaxCode | Nato il: $minorBirthDate
Genitore/Tutore: $parentFullName | C.F.: $parentTaxCode | Doc. Identita\' N.: $parentDocumentNumber
Email: $userEmail
Data Generazione Documento: $day $month $year $hour:$minute UTC
Indirizzo IP: $ipAddress



Firma per esteso del Minore (14-17 anni): ____________________________________



Firma per esteso del Genitore / Tutore Legale: ____________________________________



(E\' obbligatorio allegare al presente modulo ricaricato nell\'app la copia del documento d\'identita\' del genitore/tutore legale in corso di validita\').



================================================================================

Documento generato automaticamente dall\'app Team Ragnarok ASD''';

      final fullContent = _minor1417TermsTemplate + dataSection;
      final documentBytes = Uint8List.fromList(utf8.encode(fullContent));

      final timestamp = acceptedAt.millisecondsSinceEpoch;
      final fileName = 'modulo_minore_1417_$timestamp.txt';
      final filePath = '$userId/$fileName';

      await _client.storage.from('user_docs').uploadBinary(
            filePath,
            documentBytes,
            fileOptions: const FileOptions(
              contentType: 'text/plain; charset=utf-8',
              upsert: false,
            ),
          );

      final italianMonthsShort = [
        'gen',
        'feb',
        'mar',
        'apr',
        'mag',
        'giu',
        'lug',
        'ago',
        'set',
        'ott',
        'nov',
        'dic',
      ];
      final dateLabel =
          '${acceptedAt.day.toString().padLeft(2, '0')} ${italianMonthsShort[acceptedAt.month - 1]} ${acceptedAt.year}';

      // Use SECURITY DEFINER RPC to bypass RLS during registration
      await _client.rpc('save_registration_document', params: {
        'p_user_id': userId,
        'p_file_name': 'Modulo Iscrizione Minore 14-17 anni',
        'p_file_url': filePath,
        'p_file_type': 'document',
        'p_document_type': 'minor_1417_terms',
        'p_document_label':
            'Modulo minore 14-17 anni - da firmare e ricaricare entro 7 giorni ($dateLabel)',
      });

      debugPrint('Minor 14-17 terms document saved for user $userId');
    } catch (e) {
      debugPrint('Warning: Could not save minor 14-17 terms document: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DOWNLOAD TERMS PDF FROM PROFILE (for existing stored documents)
  // ─────────────────────────────────────────────────────────────────────────

  /// Downloads the terms document as a PDF given its storage file path and document type
  Future<void> downloadTermsDocumentAsPdf({
    required String filePath,
    required String documentType,
    required String documentLabel,
  }) async {
    try {
      // Get the stored text content from Supabase storage
      final signedUrl = await _client.storage
          .from('user_docs')
          .createSignedUrl(filePath, 3600);

      // Fetch the text content
      final response = await _dio.get(
        signedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final textContent = utf8.decode(response.data as List<int>);

        // Generate PDF from the stored text
        String title;
        String fileName;
        switch (documentType) {
          case 'minor_1417_terms':
            title = 'Modulo Iscrizione Minore (14-17 anni) - Team Ragnarok ASD';
            fileName = 'modulo_minore_14_17_anni.pdf';
            break;
          case 'child_terms_acceptance':
            title = 'Modulo Iscrizione Minore (Under 14) - Team Ragnarok ASD';
            fileName = 'termini_iscrizione_minore_under14.pdf';
            break;
          default:
            title =
                'Modulo di Iscrizione e Regolamento Interno - Team Ragnarok ASD';
            fileName = 'termini_iscrizione.pdf';
        }

        final pdfBytes = await _generatePdfFromText(title, textContent);
        await downloadPdfBytes(pdfBytes, fileName);
      }
    } catch (e) {
      debugPrint('Warning: Could not download terms document as PDF: $e');
      // Fallback: open the signed URL directly
      try {
        final signedUrl = await _client.storage
            .from('user_docs')
            .createSignedUrl(filePath, 3600);
        if (await canLaunchUrl(Uri.parse(signedUrl))) {
          await launchUrl(Uri.parse(signedUrl),
              mode: LaunchMode.externalApplication);
        }
      } catch (fallbackError) {
        debugPrint('Fallback also failed: $fallbackError');
      }
    }
  }
}
