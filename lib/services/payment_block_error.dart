import 'package:flutter/material.dart';

/// Riconosce i due controlli di sicurezza sui pagamenti applicati dal
/// trigger su `payment_confirmations` (vedi la migrazione
/// payment_confirmations_server_checks) a partire dal testo dell'errore che
/// arriva dal database, e prepara un dialogo chiaro per l'utente al posto
/// del classico errore tecnico generico.
class PaymentBlockError {
  final String message;
  final bool needsGuardianProfile;

  const PaymentBlockError(this.message, {required this.needsGuardianProfile});

  /// Testo esatto dei due messaggi, così come li scrive il trigger sul
  /// database — deve restare identico a quello nella migrazione.
  static const String guardianDataMessage =
      'Prima di poter pagare, il tutore deve compilare i propri dati nel Profilo (nome, cognome e codice fiscale del genitore/tutore).';
  static const String annualFirstMessage =
      'Devi prima completare l\'iscrizione annuale prima di poter attivare altri piani.';

  /// Ritorna null se [error] non corrisponde a nessuno dei due controlli
  /// (errore generico, da mostrare come oggi).
  static PaymentBlockError? fromError(Object error) {
    final text = error.toString();
    if (text.contains(guardianDataMessage)) {
      return const PaymentBlockError(
        guardianDataMessage,
        needsGuardianProfile: true,
      );
    }
    if (text.contains(annualFirstMessage)) {
      return const PaymentBlockError(
        annualFirstMessage,
        needsGuardianProfile: false,
      );
    }
    return null;
  }

  /// Mostra il messaggio come dialogo chiaro; se riguarda i dati del
  /// genitore, aggiunge un bottone "Vai al Profilo" — solo quando
  /// [showProfileButton] è true (di default), cioè quando la persona che
  /// vede il dialogo è quella che deve compilare i propri dati (non un
  /// admin che sta confermando il pagamento per conto di qualcun altro).
  ///
  /// Ritorna true se l'utente ha scelto "Vai al Profilo": la navigazione
  /// resta al chiamante, che sa nell'ordine giusto se deve prima chiudere
  /// un proprio foglio/dialogo (per non impilare la schermata Profilo
  /// sotto qualcosa che sta per chiudersi).
  Future<bool> show(BuildContext context, {bool showProfileButton = true}) async {
    final goToProfile = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pagamento non completato'),
        content: Text(message),
        actions: [
          if (needsGuardianProfile && showProfileButton)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Vai al Profilo'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
    return goToProfile ?? false;
  }
}
