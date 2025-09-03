import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class TermsAcceptanceSection extends StatefulWidget {
  final bool isAccepted;
  final Function(bool) onChanged;

  const TermsAcceptanceSection({
    super.key,
    required this.isAccepted,
    required this.onChanged,
  });

  @override
  State<TermsAcceptanceSection> createState() => _TermsAcceptanceSectionState();
}

class _TermsAcceptanceSectionState extends State<TermsAcceptanceSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Termini e Condizioni',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
          ),
          SizedBox(height: 2.h),
          _buildTermsCheckbox(),
          SizedBox(height: 2.h),
          _buildExpandableTerms(),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: widget.isAccepted,
          onChanged: (value) => widget.onChanged(value ?? false),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: GestureDetector(
            onTap: () => widget.onChanged(!widget.isAccepted),
            child: RichText(
              text: TextSpan(
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(text: 'Accetto i '),
                  TextSpan(
                    text: 'Termini e Condizioni',
                    style: TextStyle(
                      color: AppTheme.lightTheme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: ' e la '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: AppTheme.lightTheme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: ' della scuola di arti marziali *'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableTerms() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary
                  .withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.primary
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Leggi i Termini e Condizioni completi',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                CustomIconWidget(
                  iconName: _isExpanded ? 'expand_less' : 'expand_more',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          SizedBox(height: 2.h),
          Container(
            width: double.infinity,
            height: 25.h,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withValues(alpha: 0.3),
              ),
            ),
            child: SingleChildScrollView(
              child: Text(
                _getTermsAndConditionsText(),
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getTermsAndConditionsText() {
    return '''TERMINI E CONDIZIONI DI SERVIZIO - TEAM RAGNAROK ASD

1. Accettazione del Regolamento e Condotta
Con la presente iscrizione, il sottoscritto (o il genitore/tutore legale per i minori) dichiara di aver letto e accettato integralmente il regolamento interno del Team Ragnarok ASD.
• Il partecipante si impegna a mantenere un comportamento rispettoso e leale verso gli istruttori, i compagni di squadra, gli avversari e chiunque sia presente durante gli allenamenti, gli eventi e le competizioni.
• È severamente vietato commettere atti che costituiscano reato o che siano contrari alla legge, sia all'interno che all'esterno delle attività del team. Qualsiasi comportamento illegale o gravemente scorretto comporterà l'immediata espulsione dal team, senza diritto a rimborso.
• Il partecipante si impegna a rispettare le attrezzature, le strutture di allenamento e le norme di sicurezza stabilite dagli istruttori.

2. Liberatoria per l'Uso di Immagini (Fotografie e Video)
Il sottoscritto (o il genitore/tutore legale per i minori) acconsente alla ripresa e alla pubblicazione di proprie immagini, fotografie e/o video realizzati durante gli allenamenti, le competizioni, gli stage o qualsiasi altro evento ufficiale del Team Ragnarok ASD.
• Le immagini e i video potranno essere utilizzati a scopo promozionale e divulgativo per le attività del team.
• Le immagini potranno essere pubblicate sui canali ufficiali del Team Ragnarok ASD, inclusi ma non limitati a:
  - Sito web
  - Profili social media (es. Facebook, Instagram, YouTube)
  - Materiale promozionale (es. volantini, brochure)
  - Articoli di giornale o servizi mediatici
• La presente liberatoria ha validità illimitata nel tempo, salvo revoca scritta e formale che dovrà essere comunicata tramite email o lettera raccomandata alla direzione del team.

3. Consenso al Trattamento dei Dati Personali (GDPR)
Con la presente, ai sensi del Regolamento UE 2016/679 (GDPR), si autorizza il Team Ragnarok ASD al trattamento dei dati personali forniti in questo modulo, per le seguenti finalità:
• Gestione amministrativa dell'iscrizione.
• Comunicazioni relative alle attività, agli eventi e agli orari del team.
• Adempimento degli obblighi di legge (es. assicurazioni, tesseramento a federazioni sportive, ecc.).
• Le immagini e i video potranno essere utilizzati a fini promozionali e divulgativi.

I dati saranno conservati per il tempo strettamente necessario al raggiungimento delle finalità sopra indicate e, successivamente, per l'adempimento degli obblighi di legge. In qualsiasi momento, è possibile esercitare i diritti previsti dal GDPR (accesso, rettifica, cancellazione, limitazione, opposizione) contattando il responsabile del trattamento dati all'indirizzo lutadordeeliteravenna@gmail.com

4. SERVIZI OFFERTI
Il Team Ragnarok ASD offre corsi di arti marziali, allenamenti personalizzati e servizi correlati per studenti di tutti i livelli.

5. REGISTRAZIONE E ACCOUNT
• Devi fornire informazioni accurate e complete durante la registrazione
• Sei responsabile della sicurezza del tuo account
• Devi notificare immediatamente qualsiasi uso non autorizzato

6. PAGAMENTI E RIMBORSI
• I pagamenti devono essere effettuati secondo i termini concordati
• I rimborsi sono soggetti alle politiche del team
• Le tariffe possono essere modificate con preavviso di 30 giorni

7. COMPORTAMENTO E SICUREZZA
• Gli studenti devono seguire le regole di sicurezza e disciplina
• Comportamenti inappropriati possono portare alla sospensione
• Il team non è responsabile per infortuni dovuti a negligenza dello studente

8. LIMITAZIONE DI RESPONSABILITÀ
Il Team Ragnarok ASD non sarà responsabile per danni indiretti o consequenziali derivanti dall'uso dei servizi.

9. MODIFICHE AI TERMINI
Ci riserviamo il diritto di modificare questi termini in qualsiasi momento con preavviso appropriato.

10. LEGGE APPLICABILE
Questi termini sono regolati dalla legge italiana e qualsiasi controversia sarà risolta presso i tribunali competenti.

Ultimo aggiornamento: 30 Agosto 2025''';
  }
}
