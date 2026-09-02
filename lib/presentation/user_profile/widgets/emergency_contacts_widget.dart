import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/profile_typography.dart';
import '../../../services/supabase_service.dart';

class EmergencyContactsWidget extends StatefulWidget {
  final String? userId; // NEW: Optional user ID parameter

  const EmergencyContactsWidget({Key? key, this.userId}) : super(key: key);

  @override
  State<EmergencyContactsWidget> createState() =>
      _EmergencyContactsWidgetState();
}

class _EmergencyContactsWidgetState extends State<EmergencyContactsWidget> {
  Map<String, dynamic>? _emergencyContact;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContact();
  }

  Future<void> _loadEmergencyContact() async {
    try {
      final client = SupabaseService.instance.client;

      String? targetUserId = widget.userId;

      // 🎯 FIX: Use correct column names - emergency_contact and emergency_phone; maybeSingle() for missing profile
      final response = await client
          .from('user_profiles')
          .select('emergency_contact, emergency_phone')
          .eq('id', targetUserId ?? '')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _emergencyContact = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading emergency contact: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'profile.emergency_contact'.tr(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: ProfileTypography.sectionTitle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _showEditContactDialog,
                icon: Icon(
                  // 🎯 FIX: Use correct column name
                  _emergencyContact?['emergency_contact'] == null
                      ? Icons.add
                      : Icons.edit,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: Colors.red,
                strokeWidth: 2,
              ),
            )
          // 🎯 FIX: Use correct column names
          else if (_emergencyContact?['emergency_contact'] == null &&
              _emergencyContact?['emergency_phone'] == null)
            _buildEmptyState()
          else
            _buildContactCard(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(77)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.contact_emergency_outlined,
            color: Colors.grey[600],
            size: 8.w,
          ),
          SizedBox(height: 2.h),
          Text(
            'profile.no_emergency_contact'.tr(),
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: ProfileTypography.subtitle,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1.h),
          Text(
            'profile.tap_to_add_contact'.tr(),
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              fontSize: ProfileTypography.caption,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(77)),
      ),
      child: Row(
        children: [
          Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(51),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red),
            ),
            child: Icon(Icons.contact_emergency, color: Colors.red, size: 5.w),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎯 FIX: Use correct column name
                Text(
                  _emergencyContact?['emergency_contact'] ??
                      'profile.name_not_specified'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: ProfileTypography.emphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'profile.emergency_contact'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: ProfileTypography.caption,
                  ),
                ),
                // 🎯 FIX: Use correct column name
                if (_emergencyContact?['emergency_phone'] != null)
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.red, size: 16),
                      SizedBox(width: 1.w),
                      Text(
                        _emergencyContact?['emergency_phone'],
                        style: GoogleFonts.inter(
                          color: Colors.grey[300],
                          fontSize: ProfileTypography.caption,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: Color(0xFF2A2A2A),
            icon: Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditContactDialog();
              } else if (value == 'call' &&
                  _emergencyContact?['emergency_phone'] != null) {
                _callContact(_emergencyContact?['emergency_phone']);
              } else if (value == 'delete') {
                _deleteContact();
              }
            },
            itemBuilder: (context) => [
              // 🎯 FIX: Use correct column name
              if (_emergencyContact?['emergency_phone'] != null)
                PopupMenuItem(
                  value: 'call',
                  child: Row(
                    children: [
                      Icon(Icons.call, color: Colors.green, size: 4.w),
                      SizedBox(width: 2.w),
                      Text(
                        'profile.call'.tr(),
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue, size: 4.w),
                    SizedBox(width: 2.w),
                    Text(
                      'profile.modify'.tr(),
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 4.w),
                    SizedBox(width: 2.w),
                    Text(
                      'profile.remove'.tr(),
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog() {
    // 🎯 FIX: Use correct column names
    final nameController = TextEditingController(
      text: _emergencyContact?['emergency_contact'] ?? '',
    );
    final phoneController = TextEditingController(
      text: _emergencyContact?['emergency_phone'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          // 🎯 FIX: Use correct column name
          _emergencyContact?['emergency_contact'] == null
              ? 'profile.add_emergency_contact'.tr()
              : 'profile.edit_emergency_contact'.tr(),
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(
              'profile.full_name_label'.tr(),
              nameController,
              Icons.person,
            ),
            SizedBox(height: 2.h),
            _buildDialogTextField(
              'profile.phone_number_label'.tr(),
              phoneController,
              Icons.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _updateEmergencyContact(
                nameController.text.trim(),
                phoneController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: Text(
              'common.save'.tr(),
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.red),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.withAlpha(77)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _updateEmergencyContact(String name, String phone) async {
    try {
      final client = SupabaseService.instance.client;

      String? targetUserId = widget.userId;

      // 🎯 FIX: Use correct column names - emergency_contact and emergency_phone
      await client.from('user_profiles').update({
        'emergency_contact': name.isEmpty ? null : name,
        'emergency_phone': phone.isEmpty ? null : phone,
      }).eq('id', targetUserId ?? '');

      if (mounted) {
        setState(() {
          _emergencyContact = {
            'emergency_contact': name,
            'emergency_phone': phone,
          };
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile.emergency_contact_updated'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'errors.load_data_error'.tr(namedArgs: {'detail': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteContact() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'profile.remove_contact_title'.tr(),
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'profile.remove_contact_confirm'.tr(),
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'profile.remove'.tr(),
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _updateEmergencyContact('', '');
    }
  }

  void _callContact(String phone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('profile.calling_phone'.tr(namedArgs: {'phone': phone})),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'common.ok'.tr(),
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}
