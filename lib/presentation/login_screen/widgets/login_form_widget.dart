import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class LoginFormWidget extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final VoidCallback onPasswordVisibilityToggle;
  final VoidCallback onForgotPassword;
  final String? emailError;
  final String? passwordError;
  final bool rememberMe;
  final ValueChanged<bool> onRememberMeChanged;

  const LoginFormWidget({
    Key? key,
    required this.emailController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.onPasswordVisibilityToggle,
    required this.onForgotPassword,
    this.emailError,
    this.passwordError,
    required this.rememberMe,
    required this.onRememberMeChanged,
  }) : super(key: key);

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email Field
        TextFormField(
          controller: widget.emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'Inserisci la tua email',
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'email',
                color: AppTheme.textSecondaryLight,
                size: 20,
              ),
            ),
            errorText: widget.emailError,
          ),
          onFieldSubmitted: (_) {
            FocusScope.of(context).requestFocus(_passwordFocusNode);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email richiesta';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Formato email non valido';
            }
            return null;
          },
        ),
        SizedBox(height: 3.h),

        // Password Field
        TextFormField(
          controller: widget.passwordController,
          focusNode: _passwordFocusNode,
          obscureText: !widget.isPasswordVisible,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Inserisci la tua password',
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'lock',
                color: AppTheme.textSecondaryLight,
                size: 20,
              ),
            ),
            suffixIcon: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onPasswordVisibilityToggle();
              },
              child: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName:
                      widget.isPasswordVisible
                          ? 'visibility'
                          : 'visibility_off',
                  color: AppTheme.textSecondaryLight,
                  size: 20,
                ),
              ),
            ),
            errorText: widget.passwordError,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password richiesta';
            }
            if (value.length < 6) {
              return 'Password deve essere almeno 6 caratteri';
            }
            return null;
          },
        ),
        SizedBox(height: 2.h),

        // Remember Me Checkbox - Separate Row for Better Visibility
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: widget.rememberMe,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  widget.onRememberMeChanged(value ?? false);
                },
                activeColor: AppTheme.primaryLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(width: 2.w),
            Text(
              'Ricordami',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),

        // Forgot Password Link - Separate Row
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onForgotPassword();
            },
            child: Text(
              'Password Dimenticata?',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
