import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';

class PersonalInfoWidget extends StatefulWidget {
  const PersonalInfoWidget({Key? key}) : super(key: key);

  @override
  State<PersonalInfoWidget> createState() => _PersonalInfoWidgetState();
}

class _PersonalInfoWidgetState extends State<PersonalInfoWidget> {
  bool _isEditing = false;
  final TextEditingController _nomeController =
      TextEditingController(text: 'Marco');
  final TextEditingController _cognomeController =
      TextEditingController(text: 'Rossi');
  final TextEditingController _emailController =
      TextEditingController(text: 'marco.rossi@teamragnarok.com');
  final TextEditingController _telefonoController =
      TextEditingController(text: '+39 345 678 9012');

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
                'Informazioni Personali',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
                icon: Icon(
                  _isEditing ? Icons.save : Icons.edit,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildInfoField('Nome', _nomeController, Icons.person),
          SizedBox(height: 2.h),
          _buildInfoField('Cognome', _cognomeController, Icons.person_outline),
          SizedBox(height: 2.h),
          _buildInfoField('Email', _emailController, Icons.email),
          SizedBox(height: 2.h),
          _buildInfoField('Telefono', _telefonoController, Icons.phone),
        ],
      ),
    );
  }

  Widget _buildInfoField(
      String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 0.5.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: _isEditing ? Color(0xFF2A2A2A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isEditing
                  ? Colors.red.withAlpha(128)
                  : Colors.grey.withAlpha(77),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.red, size: 5.w),
              SizedBox(width: 3.w),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: _isEditing,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.sp,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) {
                    if (label == 'Email' && value != null && value.isNotEmpty) {
                      return _validateEmail(value) ? null : 'Email non valida';
                    }
                    if (label == 'Telefono' &&
                        value != null &&
                        value.isNotEmpty) {
                      return _validatePhone(value) ? null : 'Numero non valido';
                    }
                    return value?.isEmpty ?? true ? 'Campo obbligatorio' : null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _validatePhone(String phone) {
    return RegExp(r'^[\+]?[0-9\s\-\(\)]{8,15}$').hasMatch(phone);
  }
}