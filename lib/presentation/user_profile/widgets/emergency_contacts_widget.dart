import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';

class EmergencyContactsWidget extends StatefulWidget {
  const EmergencyContactsWidget({Key? key}) : super(key: key);

  @override
  State<EmergencyContactsWidget> createState() =>
      _EmergencyContactsWidgetState();
}

class _EmergencyContactsWidgetState extends State<EmergencyContactsWidget> {
  List<Map<String, String>> emergencyContacts = [
    {
      'name': 'Maria Rossi',
      'relationship': 'Moglie',
      'phone': '+39 339 123 4567'
    },
    {
      'name': 'Dr. Luigi Bianchi',
      'relationship': 'Medico di Famiglia',
      'phone': '+39 06 123 4567'
    },
  ];

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
                'Contatti di Emergenza',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: _showAddContactDialog,
                icon: Icon(Icons.add, color: Colors.red),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          ...emergencyContacts.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, String> contact = entry.value;
            return _buildContactCard(contact, index);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildContactCard(Map<String, String> contact, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
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
                  contact['name'] ?? '',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  contact['relationship'] ?? '',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 10.sp,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.phone, color: Colors.red, size: 3.w),
                    SizedBox(width: 1.w),
                    Text(
                      contact['phone'] ?? '',
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
                _showEditContactDialog(contact, index);
              } else if (value == 'delete') {
                _deleteContact(index);
              } else if (value == 'call') {
                _callContact(contact['phone'] ?? '');
              }
            },
            itemBuilder: (context) => [
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
                    Text('Elimina',
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

  void _showAddContactDialog() {
    _showContactDialog('Aggiungi Contatto di Emergenza', {}, -1);
  }

  void _showEditContactDialog(Map<String, String> contact, int index) {
    _showContactDialog('Modifica Contatto di Emergenza', contact, index);
  }

  void _showContactDialog(
      String title, Map<String, String> contact, int index) {
    final nameController = TextEditingController(text: contact['name'] ?? '');
    final relationshipController =
        TextEditingController(text: contact['relationship'] ?? '');
    final phoneController = TextEditingController(text: contact['phone'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(title, style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField('Nome', nameController, Icons.person),
            SizedBox(height: 2.h),
            _buildDialogTextField('Parentela/Ruolo', relationshipController,
                Icons.family_restroom),
            SizedBox(height: 2.h),
            _buildDialogTextField('Telefono', phoneController, Icons.phone),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final newContact = {
                'name': nameController.text,
                'relationship': relationshipController.text,
                'phone': phoneController.text,
              };

              setState(() {
                if (index == -1) {
                  emergencyContacts.add(newContact);
                } else {
                  emergencyContacts[index] = newContact;
                }
              });

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

  void _deleteContact(int index) {
    setState(() {
      emergencyContacts.removeAt(index);
    });
  }

  void _callContact(String phone) {
    // In a real app, you would use url_launcher to make a phone call
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chiamando $phone...'),
        backgroundColor: Colors.green,
      ),
    );
  }
}