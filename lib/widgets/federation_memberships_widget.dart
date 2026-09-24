import 'package:flutter/material.dart';

import '../services/federation_membership_service.dart';

/// "Affiliazioni": a small section on the student's own profile listing
/// each federation they're tesserato with (a student can have more than
/// one) — just the federation name and card number, nothing else. RLS
/// already limits `user_federation_memberships` reads to the caller's own
/// rows, so this only ever shows the signed-in user's own memberships.
/// Hidden entirely when there are none, or on any load error.
class FederationMembershipsWidget extends StatefulWidget {
  const FederationMembershipsWidget({super.key});

  @override
  State<FederationMembershipsWidget> createState() =>
      _FederationMembershipsWidgetState();
}

class _FederationMembershipsWidgetState extends State<FederationMembershipsWidget> {
  List<FederationMembership>? _memberships;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final memberships = await FederationMembershipService.instance.getMyMemberships();
      if (!mounted) return;
      setState(() => _memberships = memberships);
    } catch (_) {
      // Not critical — the section just stays hidden.
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberships = _memberships;
    if (memberships == null || memberships.isEmpty) return const SizedBox.shrink();

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
          Text(
            'Affiliazioni',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final membership in memberships)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                (membership.cardNumber != null && membership.cardNumber!.trim().isNotEmpty)
                    ? '${federationFullLabel(membership.federation)} · #${membership.cardNumber}'
                    : federationFullLabel(membership.federation),
              ),
            ),
        ],
      ),
    );
  }
}
