import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class SecurityExplanationWidget extends StatefulWidget {
  final VoidCallback onContinue;

  const SecurityExplanationWidget({
    super.key,
    required this.onContinue,
  });

  @override
  State<SecurityExplanationWidget> createState() =>
      _SecurityExplanationWidgetState();
}

class _SecurityExplanationWidgetState extends State<SecurityExplanationWidget> {
  int _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      child: Column(
        children: [
          // Title
          Text(
            'Sicurezza e Privacy',
            style: GoogleFonts.inter(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 2.h),

          // Description
          Text(
            'I tuoi dati biometrici sono protetti con i massimi standard di sicurezza. Ecco cosa devi sapere.',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Security features
          Expanded(
            child: ListView(
              children: [
                _buildSecurityCard(
                  0,
                  Icons.storage,
                  'Archiviazione Locale',
                  'I dati biometrici non vengono mai inviati ai nostri server',
                  'I tuoi dati biometrici (impronte digitali, scansioni facciali) rimangono sempre sul tuo dispositivo. Utilizziamo solo il chip di sicurezza integrato del telefono per l\'autenticazione. Team Ragnarok non ha mai accesso ai tuoi dati biometrici reali.',
                ),
                _buildSecurityCard(
                  1,
                  Icons.lock,
                  'Crittografia Hardware',
                  'Protezione attraverso il Secure Enclave del dispositivo',
                  'Il tuo dispositivo utilizza un chip di sicurezza dedicato (Secure Enclave su iOS, TEE su Android) per crittografare e proteggere i dati biometrici. Questa crittografia è a livello hardware e non può essere violata da software dannoso.',
                ),
                _buildSecurityCard(
                  2,
                  Icons.shield_outlined,
                  'Standard di Sicurezza',
                  'Conformità con normative internazionali di privacy',
                  'La nostra implementazione rispetta gli standard GDPR europei e le linee guida Apple/Google per la sicurezza biometrica. Non memorizziamo template biometrici e non possiamo ricostruire le tue caratteristiche fisiche dai dati crittografati.',
                ),
                _buildSecurityCard(
                  3,
                  Icons.phonelink_lock,
                  'Controllo Dispositivo',
                  'Funziona solo su questo dispositivo specifico',
                  'L\'autenticazione biometrica è legata esclusivamente a questo dispositivo. Se cambi telefono, dovrai riconfigurare l\'accesso biometrico. Questo garantisce che nessun altro dispositivo possa utilizzare i tuoi dati di autenticazione.',
                ),
                _buildSecurityCard(
                  4,
                  Icons.backup,
                  'Metodi di Backup',
                  'Accesso alternativo sempre disponibile',
                  'Potrai sempre accedere con email e password anche se l\'autenticazione biometrica non funziona. Il backup tramite PIN è opzionale e viene memorizzato in modo sicuro solo sul dispositivo.',
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Ho Compreso, Continua',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build expandable security information card
  Widget _buildSecurityCard(
    int index,
    IconData icon,
    String title,
    String subtitle,
    String expandedText,
  ) {
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? const Color(0xFFFF0000) : Colors.grey.shade800,
        ),
      ),
      child: Column(
        children: [
          // Main card content
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFFFF0000),
                      size: 6.w,
                    ),
                  ),

                  SizedBox(width: 4.w),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expand indicator
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade500,
                    size: 6.w,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            Divider(
              color: Colors.grey.shade800,
              height: 1,
            ),
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Text(
                expandedText,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  color: Colors.grey.shade300,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
