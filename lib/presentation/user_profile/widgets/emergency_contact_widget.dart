import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';

class EmergencyContactWidget extends StatefulWidget {
  const EmergencyContactWidget({super.key});

  @override
  State<EmergencyContactWidget> createState() => _EmergencyContactWidgetState();
}

class _EmergencyContactWidgetState extends State<EmergencyContactWidget> {
  final List<Map<String, String>> _emergencyContacts = [
    {
      'name': 'Maria Rossi',
      'relationship': 'Madre',
      'phone': '+39 333 987 6543',
    },
    {
      'name': 'Dr. Giovanni Bianchi',
      'relationship': 'Medico di famiglia',
      'phone': '+39 011 123 4567',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'profile.emergency_contacts_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                IconButton(
                  onPressed: _showAddContactDialog,
                  icon: Icon(Icons.add, color: const Color(0xFFFF0000)),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (_emergencyContacts.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.contact_emergency_outlined,
                      size: 48.sp,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'profile.no_emergency_contact'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'profile.add_emergency_hint'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_emergencyContacts.length, (index) {
                final contact = _emergencyContacts[index];
                return _buildContactTile(context, contact, index);
              }),
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFFFF0000),
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'profile.emergency_disclaimer'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFFF0000),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context,
    Map<String, String> contact,
    int index,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.person,
              color: const Color(0xFFFF0000),
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact['name']!,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  contact['relationship']!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFFF0000),
                      ),
                ),
                Text(
                  contact['phone']!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _callContact(contact['phone']!),
                icon: Icon(Icons.call, color: Colors.green, size: 20.sp),
              ),
              IconButton(
                onPressed: () => _editContact(index),
                icon: Icon(
                  Icons.edit,
                  color: const Color(0xFFFF0000),
                  size: 20.sp,
                ),
              ),
              IconButton(
                onPressed: () => _deleteContact(index),
                icon: Icon(Icons.delete, color: Colors.red, size: 20.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    _showContactDialog(isEditing: false);
  }

  void _editContact(int index) {
    _showContactDialog(isEditing: true, contactIndex: index);
  }

  void _showContactDialog({required bool isEditing, int? contactIndex}) {
    final nameController = TextEditingController(
      text: isEditing && contactIndex != null
          ? _emergencyContacts[contactIndex]['name']
          : '',
    );
    final relationshipController = TextEditingController(
      text: isEditing && contactIndex != null
          ? _emergencyContacts[contactIndex]['relationship']
          : '',
    );
    final phoneController = TextEditingController(
      text: isEditing && contactIndex != null
          ? _emergencyContacts[contactIndex]['phone']
          : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing
              ? 'profile.edit_emergency_contact'.tr()
              : 'profile.add_emergency_contact'.tr(),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'profile.full_name_label'.tr(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: relationshipController,
              decoration: InputDecoration(
                labelText: 'profile.relation'.tr(),
                prefixIcon: Icon(Icons.family_restroom),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'profile.phone_number_label'.tr(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  relationshipController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final contact = {
                  'name': nameController.text,
                  'relationship': relationshipController.text,
                  'phone': phoneController.text,
                };

                setState(() {
                  if (isEditing && contactIndex != null) {
                    _emergencyContacts[contactIndex] = contact;
                  } else {
                    _emergencyContacts.add(contact);
                  }
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? 'profile.contact_edited_success'.tr()
                          : 'profile.contact_added_success'.tr(),
                    ),
                    backgroundColor: const Color(0xFFFF0000),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
            ),
            child: Text(
              isEditing ? 'profile.modify'.tr() : 'common.add'.tr(),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _callContact(String phone) {
    // Implement phone call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('profile.calling_phone'.tr(namedArgs: {'phone': phone})),
        backgroundColor: const Color(0xFFFF0000),
      ),
    );
  }

  void _deleteContact(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile.delete_contact_title'.tr()),
        content: Text(
          'profile.delete_contact_confirm'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _emergencyContacts.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('profile.contact_deleted'.tr()),
                  backgroundColor: const Color(0xFFFF0000),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('common.delete'.tr(),
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
