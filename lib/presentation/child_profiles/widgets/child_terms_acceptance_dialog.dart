import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

/// Result returned by [ChildTermsAcceptanceDialog].
/// [accepted] is true when the guardian confirmed.
/// [imageConsent] reflects whether the liberatoria immagini was accepted.
class ChildTermsResult {
  final bool accepted;
  final bool imageConsent;
  const ChildTermsResult({required this.accepted, required this.imageConsent});
}

/// Dialog shown when registering a new child/minor profile.
/// Terms (punto 1) and GDPR (punto 3) are mandatory.
/// Liberatoria immagini (punto 2) is optional.
class ChildTermsAcceptanceDialog extends StatefulWidget {
  final String childName;

  const ChildTermsAcceptanceDialog({Key? key, required this.childName})
      : super(key: key);

  @override
  State<ChildTermsAcceptanceDialog> createState() =>
      _ChildTermsAcceptanceDialogState();
}

class _ChildTermsAcceptanceDialogState
    extends State<ChildTermsAcceptanceDialog> {
  bool _acceptTerms = false;
  bool _acceptGdpr = false;
  bool _acceptImages = false;
  bool _isExpanded = false;

  // Only terms and GDPR are mandatory
  bool get _canProceed => _acceptTerms && _acceptGdpr;

  static const String _fullText =
      '''MODULO ISCRIZIONE MINORE (UNDER 14) E REGOLAMENTO INTERNO
TEAM RAGNAROK A.S.D.

1. ACCETTAZIONE DEL REGOLAMENTO, CONDOTTA DEL MINORE E CODICE ETICO DEI GENITORI/TUTORI

Con la presente iscrizione, il genitore/tutore legale esercitante la responsabilità genitoriale sul minore dichiara di aver preso visione e di accettare integralmente il regolamento interno del Team Ragnarok A.S.D.

A) Condotta del Minore:
Il minore si impegna a mantenere un comportamento rispettoso, disciplinato e leale verso gli istruttori, i compagni di squadra, gli avversari e le strutture. È severamente vietato qualsiasi atto di bullismo, violenza verbale o fisica non sportiva, dentro e fuori dal campo di allenamento.

B) Codice di Comportamento dei Genitori e Tutori Legali:
I genitori/tutori si impegnano a sostenere il percorso sportivo del minore in modo sano e positivo. In particolare è fatto obbligo di:

• Rispettare sempre le decisioni tecniche degli istruttori e i giudizi arbitrali durante le gare e le competizioni.

• Mantenere un comportamento educato, corretto e decoroso sugli spalti e nelle aree di gara, evitando qualsiasi tipo di insulto, protesta accesa, linguaggio volgare o condotta anti-sportiva verso arbitri, atleti, coach o altri genitori.

• Non interferire con le lezioni, gli allenamenti o la gestione dell'atleta all'angolo/bordo matassina/ring/gabbia durante le gare. I genitori devono stazionare esclusivamente nelle aree riservate al pubblico.

N.B.: Il mancato rispetto del presente codice di comportamento da parte dei genitori potrà comportare la sospensione o l'espulsione immediata del minore dal team, a discrezione della direzione, senza diritto ad alcun rimborso.

------------------------------------------------------------

2. LIBERATORIA PER LA DIFFUSIONE DI IMMAGINI DI MINORI (FOTOGRAFIE E VIDEO)

Il genitore/tutore legale autorizza a titolo gratuito il Team Ragnarok A.S.D. alla ripresa, trasmissione e pubblicazione delle immagini (fotografie e/o video) ritraenti il minore, realizzate durante gli allenamenti, i corsi, le competizioni, gli stage e ogni altro evento ufficiale del team.

Le immagini e i video potranno essere utilizzati a scopo promozionale, divulgativo e istituzionale sulle piattaforme ufficiali del Team Ragnarok, inclusi a titolo esemplificativo:

• Profilo e canali social media ufficiali (es. Instagram, Facebook, YouTube, TikTok).
• Sito web ufficiale della A.S.D.
• Materiale cartaceo promozionale (volantini, locandine, brochure).
• Articoli di giornale, rassegne stampa e servizi mediatici.

La presente liberatoria ha validità illimitata nel tempo, salvo revoca scritta da comunicare tramite email o raccomandata A/R alla direzione della A.S.D.

------------------------------------------------------------

3. CONSENSO AL TRATTAMENTO DEI DATI PERSONALI DEL MINORE (GDPR UE 2016/679)

Ai sensi del Regolamento UE 2016/679 (GDPR), il genitore/tutore autorizza il Team Ragnarok A.S.D. al trattamento dei dati personali propri e del minore registrato per le seguenti finalità:

• Gestione amministrativa, contabile e tesseramento presso le Federazioni Sportive / Enti di Promozione Sportiva riconosciuti (es. tesseramento, assicurazione).
• Comunicazioni operative relative agli allenamenti, orari, eventi e gare.
• Gestione della liberatoria immagini come descritto al punto 2.

I dati saranno conservati per il tempo strettamente necessario all'adempimento delle finalità associative e di legge. In qualsiasi momento è possibile esercitare i diritti previsti dal GDPR contattando il titolare del trattamento.''';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 85.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: const BoxDecoration(
                color: Color(0xFF2A0000),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.child_care,
                        color: Color(0xFFFF0000),
                        size: 22,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'MODULO ISCRIZIONE MINORE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'TEAM RAGNAROK A.S.D.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF0000),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Iscrizione di: ${widget.childName}',
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expandable full text
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(
                              0xFFFF0000,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isExpanded
                                  ? 'Nascondi testo completo'
                                  : 'Leggi il regolamento completo',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFFF0000),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              _isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: const Color(0xFFFF0000),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isExpanded) ...[
                      SizedBox(height: 1.5.h),
                      Container(
                        width: double.infinity,
                        height: 22.h,
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[800]!),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _fullText,
                            style: GoogleFonts.inter(
                              color: Colors.grey[300],
                              fontSize: 10.sp,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 2.h),

                    // Divider
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'DICHIARAZIONE DI ACCETTAZIONE',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    Text(
                      'Il genitore/tutore legale dichiara di aver letto, compreso e accettato integralmente in nome e per conto del minore:',
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: 11.sp,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 1.5.h),

                    // Checkbox 1 — Termini e Regolamento (OBBLIGATORIO)
                    _buildCheckbox(
                      value: _acceptTerms,
                      onChanged: (v) =>
                          setState(() => _acceptTerms = v ?? false),
                      label:
                          'I Termini e Condizioni, il Regolamento Minori e il Codice Etico Genitori',
                      isRequired: true,
                    ),
                    SizedBox(height: 1.h),

                    // Checkbox 2 — GDPR (OBBLIGATORIO)
                    _buildCheckbox(
                      value: _acceptGdpr,
                      onChanged: (v) =>
                          setState(() => _acceptGdpr = v ?? false),
                      label:
                          'Il trattamento dei dati personali (GDPR) del minore e del genitore',
                      isRequired: true,
                    ),
                    SizedBox(height: 1.h),

                    // Checkbox 3 — Liberatoria immagini (FACOLTATIVO)
                    _buildCheckbox(
                      value: _acceptImages,
                      onChanged: (v) =>
                          setState(() => _acceptImages = v ?? false),
                      label:
                          'La liberatoria per la diffusione di immagini e video del minore',
                      isRequired: false,
                    ),

                    // Note liberatoria facoltativa
                    SizedBox(height: 0.8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 0.8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 14,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              'La liberatoria immagini è facoltativa. Se non accettata, le immagini del minore non potranno essere pubblicate.',
                              style: GoogleFonts.inter(
                                color: Colors.blue[300],
                                fontSize: 10.sp,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!_canProceed) ...[
                      SizedBox(height: 1.5.h),
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 16,
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                'I punti 1 (Regolamento) e 3 (GDPR) sono obbligatori per completare l\'iscrizione.',
                                style: GoogleFonts.inter(
                                  color: Colors.orange[300],
                                  fontSize: 10.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 1.h),
                  ],
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border(top: BorderSide(color: Colors.grey[800]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[700]!),
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Annulla',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _canProceed
                          ? () => Navigator.pop(
                                context,
                                ChildTermsResult(
                                  accepted: true,
                                  imageConsent: _acceptImages,
                                ),
                              )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canProceed
                            ? const Color(0xFFFF0000)
                            : Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Accetto e Procedo',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required bool isRequired,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: EdgeInsets.all(2.5.w),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFFFF0000).withValues(alpha: 0.08)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? const Color(0xFFFF0000).withValues(alpha: 0.5)
                : Colors.grey[700]!,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFFF0000),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(width: 1.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 0.5.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          color: value ? Colors.white : Colors.grey[400],
                          fontSize: 11.sp,
                          height: 1.5,
                          fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    SizedBox(width: 1.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 1.5.w,
                        vertical: 0.3.h,
                      ),
                      decoration: BoxDecoration(
                        color: isRequired
                            ? Colors.red.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isRequired ? 'OBB.' : 'FAC.',
                        style: GoogleFonts.inter(
                          color:
                              isRequired ? Colors.red[300] : Colors.grey[400],
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
