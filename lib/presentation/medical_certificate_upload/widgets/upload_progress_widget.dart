import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class UploadProgressWidget extends StatefulWidget {
  final bool isUploading;
  final double progress;
  final VoidCallback? onCancel;
  final String? statusMessage;

  const UploadProgressWidget({
    super.key,
    required this.isUploading,
    required this.progress,
    this.onCancel,
    this.statusMessage,
  });

  @override
  State<UploadProgressWidget> createState() => _UploadProgressWidgetState();
}

class _UploadProgressWidgetState extends State<UploadProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.isUploading) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(UploadProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUploading && !oldWidget.isUploading) {
      _animationController.forward();
    } else if (!widget.isUploading && oldWidget.isUploading) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isUploading) {
      return SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  AppTheme.lightTheme.colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressHeader(),
            SizedBox(height: 3.h),
            _buildProgressBar(),
            SizedBox(height: 2.h),
            _buildProgressDetails(),
            if (widget.onCancel != null) ...[
              SizedBox(height: 3.h),
              _buildCancelButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color:
                AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SizedBox(
              width: 4.w,
              height: 4.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Caricamento in corso...',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
              if (widget.statusMessage != null) ...[
                SizedBox(height: 0.5.h),
                Text(
                  widget.statusMessage!,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          '${(widget.progress * 100).toInt()}%',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.lightTheme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progresso',
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _getProgressText(),
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Container(
          width: double.infinity,
          height: 1.h,
          decoration: BoxDecoration(
            color:
                AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widget.progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.lightTheme.colorScheme.primary,
                    AppTheme.lightTheme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDetails() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            'Stato:',
            _getStatusText(),
            'cloud_upload',
          ),
          SizedBox(height: 1.h),
          _buildDetailRow(
            'Tempo stimato:',
            _getEstimatedTime(),
            'schedule',
          ),
          SizedBox(height: 1.h),
          _buildDetailRow(
            'Connessione:',
            'Stabile',
            'wifi',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, String iconName) {
    return Row(
      children: [
        CustomIconWidget(
          iconName: iconName,
          color: AppTheme.lightTheme.colorScheme.primary,
          size: 16,
        ),
        SizedBox(width: 2.w),
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: Text(
            value,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.onCancel,
        icon: CustomIconWidget(
          iconName: 'cancel',
          color: AppTheme.lightTheme.colorScheme.error,
          size: 16,
        ),
        label: Text(
          'Annulla Caricamento',
          style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.lightTheme.colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          side: BorderSide(
            color: AppTheme.lightTheme.colorScheme.error,
            width: 1,
          ),
        ),
      ),
    );
  }

  String _getProgressText() {
    if (widget.progress < 0.1) {
      return 'Inizializzazione...';
    } else if (widget.progress < 0.5) {
      return 'Caricamento documento...';
    } else if (widget.progress < 0.8) {
      return 'Elaborazione...';
    } else if (widget.progress < 1.0) {
      return 'Finalizzazione...';
    } else {
      return 'Completato';
    }
  }

  String _getStatusText() {
    if (widget.progress < 0.1) {
      return 'Preparazione file';
    } else if (widget.progress < 0.5) {
      return 'Caricamento in corso';
    } else if (widget.progress < 0.8) {
      return 'Validazione documento';
    } else if (widget.progress < 1.0) {
      return 'Salvataggio';
    } else {
      return 'Completato con successo';
    }
  }

  String _getEstimatedTime() {
    if (widget.progress >= 1.0) {
      return 'Completato';
    }

    final remainingProgress = 1.0 - widget.progress;
    final estimatedSeconds =
        (remainingProgress * 30).round(); // Assume 30 seconds total

    if (estimatedSeconds < 5) {
      return 'Pochi secondi';
    } else if (estimatedSeconds < 60) {
      return '\$estimatedSeconds secondi';
    } else {
      final minutes = (estimatedSeconds / 60).ceil();
      return '\$minutes minuto${minutes > 1 ? 'i' : ''}';
    }
  }
}
