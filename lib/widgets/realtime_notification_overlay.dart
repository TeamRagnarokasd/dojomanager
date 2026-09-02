import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../services/realtime_notification_service.dart';

/// Wraps any widget and shows a sliding in-app banner whenever a
/// [RealtimeNotification] is emitted by [RealtimeNotificationService].
class RealtimeNotificationOverlay extends StatefulWidget {
  final Widget child;

  const RealtimeNotificationOverlay({Key? key, required this.child})
      : super(key: key);

  @override
  State<RealtimeNotificationOverlay> createState() =>
      _RealtimeNotificationOverlayState();
}

class _RealtimeNotificationOverlayState
    extends State<RealtimeNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;

  StreamSubscription<RealtimeNotification>? _sub;
  RealtimeNotification? _current;
  Timer? _autoDismissTimer;

  // Queue so rapid notifications don't get lost
  final List<RealtimeNotification> _queue = [];
  bool _showing = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _sub = RealtimeNotificationService.instance.notificationStream.listen(
      _onNotification,
    );
  }

  void _onNotification(RealtimeNotification n) {
    _queue.add(n);
    if (!_showing) _showNext();
  }

  void _showNext() {
    if (_queue.isEmpty) {
      _showing = false;
      return;
    }
    _showing = true;
    final next = _queue.removeAt(0);
    if (mounted) {
      setState(() => _current = next);
      _animController.forward(from: 0);
      _autoDismissTimer?.cancel();
      _autoDismissTimer = Timer(const Duration(seconds: 5), _dismiss);
    }
  }

  void _dismiss() {
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _current = null);
      }
      _showNext();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _slideAnim,
              child: _NotificationBanner(
                notification: _current!,
                onDismiss: _dismiss,
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  final RealtimeNotification notification;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.notification,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: notification.color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: notification.color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(notification.icon, color: Colors.white, size: 20),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
