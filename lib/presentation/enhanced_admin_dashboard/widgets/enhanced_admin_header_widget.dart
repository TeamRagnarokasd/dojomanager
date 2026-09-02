import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class EnhancedAdminHeaderWidget extends StatelessWidget {
  final String adminLevel;
  final String adminName;
  final VoidCallback onSignOut;
  final Map<String, dynamic> stats;
  final VoidCallback? onPendingTap;
  final VoidCallback? onSwitchToInstructor;
  final VoidCallback? onPasswordResetTap;

  const EnhancedAdminHeaderWidget({
    Key? key,
    required this.adminLevel,
    required this.adminName,
    required this.onSignOut,
    required this.stats,
    this.onPendingTap,
    this.onSwitchToInstructor,
    this.onPasswordResetTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      margin: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 32,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminLevel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      adminName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      'Pannello di Controllo Team Ragnarok',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (onSwitchToInstructor != null)
                Tooltip(
                  message: 'Passa a Vista Istruttore',
                  child: InkWell(
                    onTap: onSwitchToInstructor,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              SizedBox(width: 1.w),
              IconButton(
                onPressed: onSignOut,
                icon: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: 'Disconnetti',
              ),
            ],
          ),

          SizedBox(height: 3.h),

          // Quick Statistics Overview - Row 1
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Membri\nRegistrati',
                  '${stats['registeredMembers'] ?? 0}',
                  Icons.how_to_reg,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Entrate Mese',
                  '€${(stats['monthlyRevenue'] as double? ?? 0.0).toStringAsFixed(0)}',
                  Icons.euro_symbol,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildStatCard(
                  context,
                  'In Attesa',
                  '${stats['pendingApprovals']}',
                  Icons.pending_actions,
                ),
              ),
            ],
          ),

          SizedBox(height: 2.h),

          // Quick Statistics Overview - Row 2
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Membri\nIscritti',
                  '${stats['subscribedMembers'] ?? 0}',
                  Icons.card_membership,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Membri\nAbbonati',
                  '${stats['courseSubscribers'] ?? 0}',
                  Icons.sports_martial_arts,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildPasswordResetCard(context),
              ),
            ],
          ),

          SizedBox(height: 2.h),

          // Quick Access Menu
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAccessButton(context, Icons.group, 'Utenti'),
                _buildQuickAccessButton(
                  context,
                  Icons.receipt_long,
                  'Ricevute',
                ),
                _buildQuickAccessButton(context, Icons.event_note, 'Eventi'),
                _buildQuickAccessButton(
                  context,
                  Icons.sports_martial_arts,
                  'Discipline',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final bool isPending = label == 'In Attesa';
    final int pendingCount =
        isPending ? (stats['pendingApprovals'] as int? ?? 0) : 0;
    final bool isTappable =
        isPending && pendingCount > 0 && onPendingTap != null;

    final card = Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isTappable
            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTappable
              ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: isTappable ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 24),
          SizedBox(height: 1.h),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isTappable
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (isTappable) {
      return GestureDetector(onTap: onPendingTap, child: card);
    }
    return card;
  }

  Widget _buildPasswordResetCard(BuildContext context) {
    final int count = stats['passwordResetRequests'] as int? ?? 0;
    final bool hasPending = count > 0;

    final card = Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: hasPending
            ? Colors.orange.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPending
              ? Colors.orange.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: hasPending ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.lock_reset,
                color: hasPending
                    ? Colors.orange
                    : Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              if (hasPending)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: hasPending
                      ? Colors.orange
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            'Reset\nPassword',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (onPasswordResetTap != null) {
      return GestureDetector(onTap: onPasswordResetTap, child: card);
    }
    return card;
  }

  Widget _buildQuickAccessButton(
    BuildContext context,
    IconData icon,
    String label,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
