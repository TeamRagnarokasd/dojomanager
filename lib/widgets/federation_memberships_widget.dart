import 'package:flutter/material.dart';

import '../services/federation_membership_service.dart';

/// "Affiliazioni": a small section listing each federation the profile's
/// owner is tesserato with (a student — adult or minor — can have more than
/// one) — just the federation name and card number, nothing else, unless
/// [canManage] is true.
///
/// Exactly one of [userId] / [childProfileId] should be set to view someone
/// else's memberships (an admin viewing an adult's or a minor's profile);
/// with both null, shows the signed-in user's own memberships (RLS already
/// limits that read to their own rows).
///
/// With [canManage] true (admin-only — enforced by RLS on the actual
/// writes, not just hidden here) the section also lets the admin add a new
/// membership, edit a card number, or delete a membership. With it false
/// (the default), the section is read-only and hides itself entirely when
/// there are none, or on any load error.
class FederationMembershipsWidget extends StatefulWidget {
  const FederationMembershipsWidget({
    super.key,
    this.userId,
    this.childProfileId,
    this.canManage = false,
  });

  final String? userId;
  final String? childProfileId;
  final bool canManage;

  @override
  State<FederationMembershipsWidget> createState() =>
      _FederationMembershipsWidgetState();
}

class _FederationMembershipsWidgetState extends State<FederationMembershipsWidget> {
  List<FederationMembership>? _memberships;
  bool _hadLoadError = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final childProfileId = widget.childProfileId;
      final userId = widget.userId;
      final memberships = childProfileId != null
          ? await FederationMembershipService.instance
              .getMembershipsForChildren([childProfileId])
          : userId == null
              ? await FederationMembershipService.instance.getMyMemberships()
              : await FederationMembershipService.instance
                  .getMembershipsForUsers([userId]);
      if (!mounted) return;
      setState(() {
        _memberships = memberships;
        _hadLoadError = false;
      });
    } catch (_) {
      // Not critical — the section just stays hidden when read-only.
      if (mounted) setState(() => _hadLoadError = true);
    }
  }

  Future<void> _showAddEditDialog({FederationMembership? existing}) async {
    final usedFederations = (_memberships ?? const <FederationMembership>[])
        .map((m) => m.federation)
        .toSet();
    String? selectedFederation = existing?.federation;
    final cardController = TextEditingController(text: existing?.cardNumber ?? '');

    final availableFederations = existing != null
        ? kFederationFullLabels.keys
        : kFederationFullLabels.keys.where((f) => !usedFederations.contains(f));

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Nuova tessera' : 'Modifica tessera'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedFederation,
                  decoration: const InputDecoration(labelText: 'Federazione'),
                  items: availableFederations
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(federationFullLabel(f)),
                          ))
                      .toList(),
                  onChanged: existing != null
                      ? null
                      : (value) =>
                          setDialogState(() => selectedFederation = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cardController,
                  decoration: const InputDecoration(labelText: 'Numero tessera'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: selectedFederation == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Salva'),
              ),
            ],
          ),
        ),
      );

      if (saved != true || selectedFederation == null) return;

      setState(() => _isSaving = true);
      try {
        await FederationMembershipService.instance.upsertMembership(
          userId: widget.childProfileId == null ? widget.userId : null,
          childProfileId: widget.childProfileId,
          federation: selectedFederation!,
          cardNumber: cardController.text.trim().isEmpty
              ? null
              : cardController.text.trim(),
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tessera salvata')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore nel salvataggio: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } finally {
      cardController.dispose();
    }
  }

  Future<void> _confirmDelete(FederationMembership membership) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina tessera'),
        content: Text(
          'Eliminare la tessera ${federationFullLabel(membership.federation)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await FederationMembershipService.instance.deleteMembership(
        userId: widget.childProfileId == null ? widget.userId : null,
        childProfileId: widget.childProfileId,
        federation: membership.federation,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nell\'eliminazione: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberships = _memberships;
    final canManage = widget.canManage;

    if (!canManage && (memberships == null || memberships.isEmpty)) {
      return const SizedBox.shrink();
    }
    if (canManage && memberships == null && !_hadLoadError) {
      // Still loading — keep the section out of the layout until we know.
      return const SizedBox.shrink();
    }
    if (canManage && memberships == null && _hadLoadError) {
      // Never successfully loaded: showing "Nessuna tessera" here would be
      // a guess, not a fact, and the + button would let the admin silently
      // overwrite a real membership that just failed to load. Fail closed —
      // report the error and offer a retry instead.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Impossibile caricare le tessere. Riprova.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Riprova',
              onPressed: _load,
            ),
          ],
        ),
      );
    }

    final rows = memberships ?? const <FederationMembership>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Affiliazioni',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Aggiungi tessera',
                  onPressed: _isSaving ||
                          rows.length >= kFederationFullLabels.length
                      ? null
                      : () => _showAddEditDialog(),
                ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nessuna tessera',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final membership in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (membership.cardNumber != null &&
                              membership.cardNumber!.trim().isNotEmpty)
                          ? '${federationFullLabel(membership.federation)} · #${membership.cardNumber}'
                          : federationFullLabel(membership.federation),
                    ),
                  ),
                  if (canManage) ...[
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Modifica',
                      onPressed: _isSaving
                          ? null
                          : () => _showAddEditDialog(existing: membership),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Elimina',
                      onPressed:
                          _isSaving ? null : () => _confirmDelete(membership),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
