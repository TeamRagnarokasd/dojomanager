import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../constants/app_constants.dart';
import '../../../core/app_export.dart';

class PersonalInfoSection extends StatelessWidget {
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController birthDateController;
  final TextEditingController birthPlaceController;
  final TextEditingController addressController;
  final TextEditingController cityController;
  final TextEditingController provinceController;
  final TextEditingController capController;
  final TextEditingController taxCodeController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onNext;

  const PersonalInfoSection({
    Key? key,
    required this.fullNameController,
    required this.emailController,
    required this.phoneController,
    required this.birthDateController,
    required this.birthPlaceController,
    required this.addressController,
    required this.cityController,
    required this.provinceController,
    required this.capController,
    required this.taxCodeController,
    required this.formKey,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informazioni Personali',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: fullNameController,
              label: 'Nome Completo',
              hint: 'Mario Rossi',
              icon: Icons.person,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                return null;
              },
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: emailController,
              label: 'Email',
              hint: 'mario.rossi@example.com',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value!)) {
                  return 'Email non valida';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: phoneController,
              label: 'Telefono',
              hint: '+39 123 456 7890',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                return null;
              },
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: birthDateController,
              label: 'Data di Nascita',
              hint: 'GG/MM/AAAA',
              icon: Icons.calendar_today,
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                return null;
              },
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: birthPlaceController,
              label: 'Luogo di Nascita',
              hint: 'Roma',
              icon: Icons.location_city,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                return null;
              },
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: taxCodeController,
              label: 'Codice Fiscale',
              hint: 'RSSMRA85M01H501Z',
              icon: Icons.credit_card,
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                // Basic Italian tax code validation (16 characters)
                if (value!.length != 16) {
                  return 'Il codice fiscale deve essere di 16 caratteri';
                }
                return null;
              },
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: addressController,
              label: 'Indirizzo',
              hint: 'Via Roma 123',
              icon: Icons.home,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                return null;
              },
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: cityController,
                    label: 'Città',
                    hint: 'Milano',
                    icon: Icons.location_city,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Obbligatorio';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    controller: provinceController,
                    label: 'Provincia',
                    hint: 'MI',
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Obbligatorio';
                      if (value!.length != 2) return 'Sigla provinciale';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            _buildTextField(
              controller: capController,
              label: 'CAP',
              hint: '20100',
              icon: Icons.markunread_mailbox,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                if (value!.length != 5) return 'Il CAP deve essere di 5 cifre';
                return null;
              },
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    onNext();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultBorderRadius,
                    ),
                  ),
                ),
                child: Text(
                  'Avanti',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 12.sp),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          textCapitalization: textCapitalization,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey),
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            filled: true,
            fillColor: Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 1.5.h,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.red,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      birthDateController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }
}
