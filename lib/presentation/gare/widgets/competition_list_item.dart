import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/competitions_service.dart';

/// Proporzioni indicative della scheda gara con locandina di sfondo, usate
/// anche come riferimento per l'anteprima "riempi scheda" nel modulo di
/// modifica. L'altezza reale della scheda dipende dal contenuto (note,
/// bottoni), quindi è un'approssimazione a scopo di anteprima.
const double kCompetitionPosterCardAspectRatio = 16 / 11;

class CompetitionListItem extends StatelessWidget {
  final Map<String, dynamic> competition;
  final bool isInterested;
  final bool isSelfRegistered;
  final bool isPending;
  final ValueChanged<bool> onToggleInterested;
  final ValueChanged<bool> onToggleSelfRegistered;
  final bool showParticipantsButton;
  final VoidCallback? onShowParticipants;
  final bool showEditButton;
  final VoidCallback? onEdit;

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
    this.showEditButton = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final name = (competition['name'] ?? '').toString();
    final city = (competition['city'] ?? '').toString();
    final notes = (competition['notes'] ?? '').toString();
    final link = (competition['registration_link'] ?? '').toString();
    final posterUrl = CompetitionsService.instance.posterUrl(
      competition['poster_path'] as String?,
    );
    final hasPoster = posterUrl != null;
    final posterDisplayMode =
        (competition['poster_display_mode'] as String?) ?? 'riempi';
    final rawFocusY = competition['poster_focus_y'];
    final posterFocusY = rawFocusY is num
        ? rawFocusY.toDouble().clamp(0.0, 1.0)
        : 0.5;

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

    final titleColor = hasPoster ? Colors.white : null;
    final subtitleColor = hasPoster
        ? Colors.white.withValues(alpha: 0.9)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final bodyColor = hasPoster ? Colors.white : null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hasPoster
              ? () => _openFullscreenPoster(context, posterUrl, name)
              : null,
          child: Padding(
            padding: EdgeInsets.only(bottom: hasPoster ? 1.h : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        [
                          if (dateLabel.isNotEmpty) dateLabel,
                          if (city.isNotEmpty) city,
                        ].join(' • '),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                if (hasPoster)
                  Icon(
                    Icons.fullscreen,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
              ],
            ),
          ),
        ),
        if (notes.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: Text(
              notes,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: bodyColor),
            ),
          ),
        if (link.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: TextButton.icon(
              onPressed: () => _openLink(context, link),
              style: hasPoster
                  ? TextButton.styleFrom(foregroundColor: Colors.white)
                  : null,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Iscriviti sul sito'),
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
        if (showParticipantsButton || showEditButton)
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: Wrap(
              spacing: 1.w,
              children: [
                if (showParticipantsButton)
                  TextButton.icon(
                    onPressed: onShowParticipants,
                    style: hasPoster
                        ? TextButton.styleFrom(foregroundColor: Colors.white)
                        : null,
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text('Partecipanti'),
                  ),
                if (showEditButton)
                  TextButton.icon(
                    onPressed: onEdit,
                    style: hasPoster
                        ? TextButton.styleFrom(foregroundColor: Colors.white)
                        : null,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Modifica'),
                  ),
              ],
            ),
          ),
      ],
    );

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hasPoster ? Colors.black : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: hasPoster
          ? Stack(
              children: [
                Positioned.fill(
                  child: posterDisplayMode == 'intera'
                      ? Container(
                          color: Colors.black,
                          child: Image.network(
                            posterUrl,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Image.network(
                          posterUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment(0, posterFocusY * 2 - 1),
                        ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.all(4.w), child: content),
              ],
            )
          : Padding(padding: EdgeInsets.all(4.w), child: content),
    );
  }

  void _openFullscreenPoster(
    BuildContext context,
    String posterUrl,
    String name,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CompetitionPosterViewer(
          posterUrl: posterUrl,
          title: name,
        ),
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
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
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

/// Vista a schermo intero, ingrandibile, della locandina di una gara.
class _CompetitionPosterViewer extends StatelessWidget {
  final String posterUrl;
  final String title;

  const _CompetitionPosterViewer({
    required this.posterUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(posterUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
