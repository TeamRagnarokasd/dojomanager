import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';
import '../../../services/user_profile_service.dart';

class EmergencyContactsWidget extends StatefulWidget {
  const EmergencyContactsWidget({Key? key}) : super(key: key);

  @override
  State<EmergencyContactsWidget> createState() =>
      _EmergencyContactsWidgetState();
}

class _EmergencyContactsWidgetState extends State<EmergencyContactsWidget> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  String _emergencyContact = '';
  String _emergencyPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoading = true);

      final profile = await UserProfileService().getCurrentUserProfile();

      if (profile != null) {
        setState(() {
          _userProfile = profile;
          _emergencyContact = profile['emergency_contact'] ?? '';
          _emergencyPhone = profile['emergency_phone'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nel caricamento dei dati profilo'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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
                'Contatto di Emergenza',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _showEditContactDialog,
                icon: Icon(
                  _emergencyContact.isEmpty ? Icons.add : Icons.edit,
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
          else if (_emergencyContact.isEmpty && _emergencyPhone.isEmpty)
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
            'Nessun contatto di emergenza configurato',
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 12.sp,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1.h),
          Text(
            'Tocca + per aggiungere un contatto',
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              fontSize: 10.sp,
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
            child: Icon(
              Icons.contact_emergency,
              color: Colors.red,
              size: 5.w,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _emergencyContact.isNotEmpty
                      ? _emergencyContact
                      : 'Nome non specificato',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Contatto di Emergenza',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 10.sp,
                  ),
                ),
                if (_emergencyPhone.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.red, size: 3.w),
                      SizedBox(width: 1.w),
                      Text(
                        _emergencyPhone,
                        style: GoogleFonts.inter(
                          color: Colors.grey[300],
                          fontSize: 10.sp,
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
              } else if (value == 'call' && _emergencyPhone.isNotEmpty) {
                _callContact(_emergencyPhone);
              } else if (value == 'delete') {
                _deleteContact();
              }
            },
            itemBuilder: (context) => [
              if (_emergencyPhone.isNotEmpty)
                PopupMenuItem(
                  value: 'call',
                  child: Row(
                    children: [
                      Icon(Icons.call, color: Colors.green, size: 4.w),
                      SizedBox(width: 2.w),
                      Text('Chiama',
                          style: GoogleFonts.inter(color: Colors.white)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue, size: 4.w),
                    SizedBox(width: 2.w),
                    Text('Modifica',
                        style: GoogleFonts.inter(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 4.w),
                    SizedBox(width: 2.w),
                    Text('Rimuovi',
                        style: GoogleFonts.inter(color: Colors.white)),
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
    final nameController = TextEditingController(text: _emergencyContact);
    final phoneController = TextEditingController(text: _emergencyPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          _emergencyContact.isEmpty
              ? 'Aggiungi Contatto di Emergenza'
              : 'Modifica Contatto di Emergenza',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(
                'Nome e Cognome', nameController, Icons.person),
            SizedBox(height: 2.h),
            _buildDialogTextField(
                'Numero di Telefono', phoneController, Icons.phone),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await _updateEmergencyContact(
                nameController.text.trim(),
                phoneController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: Text('Salva', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(
      String label, TextEditingController controller, IconData icon) {
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
      final success = await UserProfileService().updateProfile(
        emergencyContact: name.isEmpty ? null : name,
        emergencyPhone: phone.isEmpty ? null : phone,
      );

      if (success) {
        setState(() {
          _emergencyContact = name;
          _emergencyPhone = phone;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contatto di emergenza aggiornato con successo'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'aggiornamento del contatto'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: ${e.toString()}'),
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
          'Rimuovi Contatto',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'Sei sicuro di voler rimuovere il contatto di emergenza?',
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Rimuovi', style: GoogleFonts.inter(color: Colors.red)),
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
        content: Text('Chiamando $phone...'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}