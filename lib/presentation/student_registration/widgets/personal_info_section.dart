import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../constants/app_constants.dart';
import '../../../core/app_export.dart';

class PersonalInfoSection extends StatefulWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController birthDateController;
  final TextEditingController birthPlaceController;
  final TextEditingController addressController;
  final TextEditingController cityController;
  final TextEditingController provinceController;
  final TextEditingController capController;
  final TextEditingController taxCodeController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final GlobalKey<FormState> formKey;
  final VoidCallback onNext;

  const PersonalInfoSection({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.phoneController,
    required this.birthDateController,
    required this.birthPlaceController,
    required this.addressController,
    required this.cityController,
    required this.provinceController,
    required this.capController,
    required this.taxCodeController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.formKey,
    required this.onNext,
  });

  @override
  State<PersonalInfoSection> createState() => _PersonalInfoSectionState();
}

class _PersonalInfoSectionState extends State<PersonalInfoSection> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile.personal_info'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: widget.firstNameController,
                  label: 'profile.first_name'.tr(),
                  hint: 'Mario',
                  icon: Icons.person,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'common.required_field'.tr();
                    }
                    if (value!.length < 2) {
                      return 'validation.min_2_chars'.tr();
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _buildTextField(
                  controller: widget.lastNameController,
                  label: 'profile.last_name'.tr(),
                  hint: 'Rossi',
                  icon: Icons.person_outline,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'common.required_field'.tr();
                    }
                    if (value!.length < 2) {
                      return 'validation.min_2_chars'.tr();
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildTextField(
            controller: widget.emailController,
            label: 'common.email'.tr(),
            hint: 'mario.rossi@example.com',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'common.required_field'.tr();
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value!)) {
                return 'validation.invalid_email'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),
          _buildTextField(
            controller: widget.phoneController,
            label: 'profile.phone'.tr(),
            hint: '+39 123 456 7890',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'common.required_field'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),
          _buildTextField(
            controller: widget.birthDateController,
            label: 'profile.birth_date'.tr(),
            hint: 'student_registration.date_format_hint'.tr(),
            icon: Icons.calendar_today,
            readOnly: true,
            onTap: () => _selectDate(context),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'common.required_field'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),
          _buildTextField(
            controller: widget.birthPlaceController,
            label: 'profile.birth_place'.tr(),
            hint: 'Roma',
            icon: Icons.location_city,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'common.required_field'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),
          _buildTextField(
            controller: widget.taxCodeController,
            label: 'profile.tax_code'.tr(),
            hint: 'RSSMRA85M01H501Z',
            icon: Icons.credit_card,
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'common.required_field'.tr();
              }
              // Basic Italian tax code validation (16 characters)
              if (value!.length != 16) {
                return 'validation.tax_code_16_chars'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),
          Text(
            'common.password'.tr(),
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          TextFormField(
            controller: widget.passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'student_registration.password_hint'.tr(),
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'validation.password_required'.tr();
              }
              if (value.length < 8) {
                return 'validation.password_min_8'.tr();
              }
              if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
                return 'validation.password_letters_numbers'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),
          Text(
            'student_registration.confirm_password_label'.tr(),
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          TextFormField(
            controller: widget.confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              hintText: 'student_registration.confirm_password_hint'.tr(),
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'validation.confirm_password_required'.tr();
              }
              if (value != widget.passwordController.text) {
                return 'validation.passwords_mismatch'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),
          _buildTextField(
            controller: widget.addressController,
            label: 'profile.address'.tr(),
            hint: 'Via Roma 123',
            icon: Icons.home,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'common.required_field'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: widget.cityController,
                  label: 'profile.city'.tr(),
                  hint: 'Milano',
                  icon: Icons.location_city,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'common.required_field'.tr();
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                flex: 1,
                child: _buildTextField(
                  controller: widget.provinceController,
                  label: 'profile.province'.tr(),
                  hint: 'MI',
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'common.required_field'.tr();
                    }
                    if (value!.length != 2) {
                      return 'validation.province_code_2'.tr();
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildTextField(
            controller: widget.capController,
            label: 'profile.zip_code'.tr(),
            hint: '20100',
            icon: Icons.markunread_mailbox,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'common.required_field'.tr();
              }
              if (value!.length != 5) {
                return 'validation.zip_5_digits'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 3.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (widget.formKey.currentState?.validate() ?? false) {
                  widget.onNext();
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
                'student_registration.next'.tr(),
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
      widget.birthDateController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }
}
