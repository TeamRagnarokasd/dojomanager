import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../services/child_profile_service.dart';

/// Widget shown in the dashboard AppBar / header area that lets the user
/// switch between their own (adult) profile and any linked child profiles.
class ProfileSwitcherWidget extends StatefulWidget {
  final Map<String, dynamic>? adultProfile;
  final VoidCallback? onProfileChanged;

  const ProfileSwitcherWidget({
    Key? key,
    this.adultProfile,
    this.onProfileChanged,
  }) : super(key: key);

  @override
  State<ProfileSwitcherWidget> createState() => _ProfileSwitcherWidgetState();
}

class _ProfileSwitcherWidgetState extends State<ProfileSwitcherWidget> {
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final children = await ChildProfileService.getChildProfiles();
      if (mounted) {
        setState(() {
          _children = children;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _currentProfileName {
    if (ChildProfileService.isChildProfileActive) {
      final child = _children.firstWhere(
        (c) => c['id'] == ChildProfileService.activeChildProfileId,
        orElse: () => {},
      );
      if (child.isNotEmpty) {
        return child['full_name'] as String? ??
            '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'.trim();
      }
    }
    return widget.adultProfile?['full_name'] as String? ?? 'Profilo';
  }

  bool get _isChildActive => ChildProfileService.isChildProfileActive;

  void _showSwitcherMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _buildSwitcherSheet(ctx),
    );
  }

  Widget _buildSwitcherSheet(BuildContext ctx) {
    final adultName =
        widget.adultProfile?['full_name'] as String? ?? 'Profilo Adulto';
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 10.w,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Seleziona Profilo',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 1.5.h),

          // Adult profile tile
          _ProfileTile(
            name: adultName,
            subtitle: 'Profilo Adulto',
            icon: Icons.person,
            isSelected: !_isChildActive,
            onTap: () async {
              Navigator.pop(ctx);
              await ChildProfileService.setActiveProfile(null);
              if (mounted) setState(() {});
              widget.onProfileChanged?.call();
            },
          ),

          if (_children.isNotEmpty) ...[
            SizedBox(height: 1.h),
            Divider(color: Colors.grey[800]),
            SizedBox(height: 0.5.h),
            Text(
              'Profili Figli',
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 0.5.h),
            ..._children.map((child) {
              final childName =
                  child['full_name'] as String? ??
                  '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'
                      .trim();
              final isSelected =
                  ChildProfileService.activeChildProfileId == child['id'];
              return _ProfileTile(
                name: childName,
                subtitle: 'Profilo Minore',
                icon: Icons.child_care,
                isSelected: isSelected,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ChildProfileService.setActiveProfile(
                    child['id'] as String,
                  );
                  if (mounted) setState(() {});
                  widget.onProfileChanged?.call();
                },
              );
            }),
          ],

          SizedBox(height: 1.h),
          Divider(color: Colors.grey[800]),
          SizedBox(height: 0.5.h),

          // Manage children link
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/child-profiles').then((_) {
                _loadChildren();
                widget.onProfileChanged?.call();
              });
            },
            icon: const Icon(
              Icons.manage_accounts,
              color: Color(0xFFFF0000),
              size: 18,
            ),
            label: Text(
              'Gestisci Profili Figli',
              style: GoogleFonts.inter(
                color: const Color(0xFFFF0000),
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(width: 40, height: 40);
    }

    return GestureDetector(
      onTap: _showSwitcherMenu,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: _isChildActive
              ? const Color(0xFFFF0000).withValues(alpha: 0.15)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isChildActive
                ? const Color(0xFFFF0000).withValues(alpha: 0.5)
                : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isChildActive ? Icons.child_care : Icons.person,
              color: _isChildActive
                  ? const Color(0xFFFF0000)
                  : Colors.grey[300],
              size: 16,
            ),
            SizedBox(width: 1.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 25.w),
              child: Text(
                _currentProfileName,
                style: GoogleFonts.inter(
                  color: _isChildActive
                      ? const Color(0xFFFF0000)
                      : Colors.grey[300],
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            SizedBox(width: 1.w),
            Icon(
              Icons.keyboard_arrow_down,
              color: _isChildActive
                  ? const Color(0xFFFF0000)
                  : Colors.grey[400],
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? const Color(0xFFFF0000).withValues(alpha: 0.2)
              : Colors.grey[800],
          border: isSelected
              ? Border.all(color: const Color(0xFFFF0000), width: 2)
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFFFF0000) : Colors.grey[400],
          size: 20,
        ),
      ),
      title: Text(
        name,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13.sp,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11.sp),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFFFF0000), size: 20)
          : null,
      onTap: onTap,
    );
  }
}
