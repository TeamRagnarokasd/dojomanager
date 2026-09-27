import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class CompetitionListItem extends StatelessWidget {
  final Map<String, dynamic> competition;
  final bool isInterested;
  final bool isSelfRegistered;
  final bool isPending;
  final ValueChanged<bool> onToggleInterested;
  final ValueChanged<bool> onToggleSelfRegistered;
  final bool showParticipantsButton;
  final VoidCallback? onShowParticipants;

  const CompetitionListItem({
    super.key,
    required this.competition,
    required this.isInterested,
    required this.isSelfRegistered,
    required this.isPending,
    required this.onToggleInterested,
    required this.onToggleSelfRegistered,
    this.showParticipantsButton = false,
    this.onShowParticipants,
  });

  @override
  Widget build(BuildContext context) {
    final name = (competition['name'] ?? '').toString();
    final city = (competition['city'] ?? '').toString();
    final notes = (competition['notes'] ?? '').toString();
    final link = (competition['registration_link'] ?? '').toString();

    DateTime? start;
    DateTime? end;
    try {
      start = DateTime.parse(competition['event_date_start'].toString());
      end = DateTime.parse(competition['event_date_end'].toString());
    } catch (_) {}

    final dateLabel = start == null
        ? ''
        : (end == null || end.isAtSameMomentAs(start))
            ? DateFormat('d MMM yyyy', 'it_IT').format(start)
            : '${DateFormat('d MMM', 'it_IT').format(start)} - '
                '${DateFormat('d MMM yyyy', 'it_IT').format(end)}';

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 0.5.h),
          Text(
            [
              if (dateLabel.isNotEmpty) dateLabel,
              if (city.isNotEmpty) city,
            ].join(' • '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (notes.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: Text(notes, style: Theme.of(context).textTheme.bodyMedium),
            ),
          if (link.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: TextButton.icon(
                onPressed: () => _openLink(context, link),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Link iscrizione'),
              ),
            ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: [
              _buildToggleChip(
                context,
                label: 'Voglio farla',
                selected: isInterested,
                onTap: () => onToggleInterested(!isInterested),
              ),
              _buildToggleChip(
                context,
                label: 'Mi sono iscritto',
                selected: isSelfRegistered,
                onTap: () => onToggleSelfRegistered(!isSelfRegistered),
              ),
            ],
          ),
          if (showParticipantsButton)
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: TextButton.icon(
                onPressed: onShowParticipants,
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('Partecipanti'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: isPending ? null : (_) => onTap(),
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: selected ? color : null,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il link.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il link.')),
        );
      }
    }
  }
}
