import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class PersonalInfoSection extends StatefulWidget {
  final TextEditingController nomeController;
  final TextEditingController cognomeController;
  final TextEditingController emailController;
  final TextEditingController telefonoController;
  final TextEditingController dataNascitaController;
  final TextEditingController codiceFiscaleController;
  final TextEditingController residenzaIndirizzoController;
  final TextEditingController residenzaCittaController;
  final TextEditingController residenzaProvinciaController;
  final TextEditingController residenzaCAPController;
  final TextEditingController genitoreNomeController;
  final TextEditingController genitoreCognomeController;
  final TextEditingController genitoreCodiceFiscaleController;
  final TextEditingController genitoreEmailController;
  final TextEditingController genitoreTelefonoController;
  final TextEditingController genitoreRelationController;
  final VoidCallback onDateTap;
  final String? nomeError;
  final String? cognomeError;
  final String? emailError;
  final String? telefonoError;
  final String? dataNascitaError;
  final String? codiceFiscaleError;
  final String? residenzaIndirizzoError;
  final String? residenzaCittaError;
  final String? residenzaProvinciaError;
  final String? residenzaCAPError;
  final String? genitoreNomeError;
  final String? genitoreCognomeError;
  final String? genitoreCodiceFiscaleError;
  final String? genitoreEmailError;
  final String? genitoreTelefonoError;
  final String? genitoreRelationError;
  final bool isMinor;

  const PersonalInfoSection({
    super.key,
    required this.nomeController,
    required this.cognomeController,
    required this.emailController,
    required this.telefonoController,
    required this.dataNascitaController,
    required this.codiceFiscaleController,
    required this.residenzaIndirizzoController,
    required this.residenzaCittaController,
    required this.residenzaProvinciaController,
    required this.residenzaCAPController,
    required this.genitoreNomeController,
    required this.genitoreCognomeController,
    required this.genitoreCodiceFiscaleController,
    required this.genitoreEmailController,
    required this.genitoreTelefonoController,
    required this.genitoreRelationController,
    required this.onDateTap,
    required this.isMinor,
    this.nomeError,
    this.cognomeError,
    this.emailError,
    this.telefonoError,
    this.dataNascitaError,
    this.codiceFiscaleError,
    this.residenzaIndirizzoError,
    this.residenzaCittaError,
    this.residenzaProvinciaError,
    this.residenzaCAPError,
    this.genitoreNomeError,
    this.genitoreCognomeError,
    this.genitoreCodiceFiscaleError,
    this.genitoreEmailError,
    this.genitoreTelefonoError,
    this.genitoreRelationError,
  });

  @override
  State<PersonalInfoSection> createState() => _PersonalInfoSectionState();
}

class _PersonalInfoSectionState extends State<PersonalInfoSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Basic personal information section
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppTheme.lightTheme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.lightTheme.colorScheme.outline
                  .withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informazioni Personali',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
              SizedBox(height: 3.h),
              _buildTextField(
                controller: widget.nomeController,
                label: 'Nome *',
                hint: 'Inserisci il tuo nome',
                errorText: widget.nomeError,
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: 2.h),
              _buildTextField(
                controller: widget.cognomeController,
                label: 'Cognome *',
                hint: 'Inserisci il tuo cognome',
                errorText: widget.cognomeError,
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: 2.h),
              _buildTextField(
                controller: widget.emailController,
                label: 'Email *',
                hint: 'esempio@email.com',
                errorText: widget.emailError,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 2.h),
              _buildTextField(
                controller: widget.telefonoController,
                label: 'Telefono *',
                hint: '+39 123 456 7890',
                errorText: widget.telefonoError,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                ],
              ),
              SizedBox(height: 2.h),
              _buildDateField(),
              SizedBox(height: 2.h),
              _buildTextField(
                controller: widget.codiceFiscaleController,
                label: 'Codice Fiscale *',
                hint: 'RSSMRA85M01H501Z',
                errorText: widget.codiceFiscaleError,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                  LengthLimitingTextInputFormatter(16),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 3.h),

        // Residence information section
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppTheme.lightTheme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.lightTheme.colorScheme.outline
                  .withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Residenza',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
              SizedBox(height: 3.h),
              _buildTextField(
                controller: widget.residenzaIndirizzoController,
                label: 'Indirizzo *',
                hint: 'Via Roma, 123',
                errorText: widget.residenzaIndirizzoError,
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: widget.residenzaCittaController,
                      label: 'Città *',
                      hint: 'Milano',
                      errorText: widget.residenzaCittaError,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: widget.residenzaProvinciaController,
                      label: 'Provincia *',
                      hint: 'MI',
                      errorText: widget.residenzaProvinciaError,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z]')),
                        LengthLimitingTextInputFormatter(2),
                      ],
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: widget.residenzaCAPController,
                      label: 'CAP *',
                      hint: '20121',
                      errorText: widget.residenzaCAPError,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Parent/Guardian information section (only for minors)
        if (widget.isMinor) ...[
          SizedBox(height: 3.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.secondary
                    .withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'family_restroom',
                      color: AppTheme.lightTheme.colorScheme.secondary,
                      size: 24,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Dati Genitore/Tutore (Obbligatorio per Minorenni)',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTheme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme.colorScheme.secondaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Essendo minorenne, è necessario fornire i dati completi di un genitore o tutore legale.',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color:
                          AppTheme.lightTheme.colorScheme.onSecondaryContainer,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                SizedBox(height: 3.h),
                _buildTextField(
                  controller: widget.genitoreNomeController,
                  label: 'Nome Genitore/Tutore *',
                  hint: 'Nome del genitore/tutore',
                  errorText: widget.genitoreNomeError,
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 2.h),
                _buildTextField(
                  controller: widget.genitoreCognomeController,
                  label: 'Cognome Genitore/Tutore *',
                  hint: 'Cognome del genitore/tutore',
                  errorText: widget.genitoreCognomeError,
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 2.h),
                _buildTextField(
                  controller: widget.genitoreCodiceFiscaleController,
                  label: 'Codice Fiscale Genitore/Tutore *',
                  hint: 'RSSMRA75M01H501X',
                  errorText: widget.genitoreCodiceFiscaleError,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                ),
                SizedBox(height: 2.h),
                _buildTextField(
                  controller: widget.genitoreEmailController,
                  label: 'Email Genitore/Tutore *',
                  hint: 'email.genitore@email.com',
                  errorText: widget.genitoreEmailError,
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 2.h),
                _buildTextField(
                  controller: widget.genitoreTelefonoController,
                  label: 'Telefono Genitore/Tutore *',
                  hint: '+39 321 654 9870',
                  errorText: widget.genitoreTelefonoError,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                  ],
                ),
                SizedBox(height: 2.h),
                _buildRelationDropdownField(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? errorText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: _getPrefixIcon(label),
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data di Nascita *',
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: widget.dataNascitaController,
          readOnly: true,
          onTap: widget.onDateTap,
          decoration: InputDecoration(
            hintText: 'DD/MM/YYYY',
            errorText: widget.dataNascitaError,
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'calendar_today',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 20,
              ),
            ),
            suffixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'arrow_drop_down',
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationDropdownField() {
    final List<String> relations = [
      'Madre',
      'Padre',
      'Tutore Legale',
      'Nonno/a',
      'Zio/a',
      'Altro'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grado di Parentela *',
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 1.h),
        DropdownButtonFormField<String>(
          value: widget.genitoreRelationController.text.isNotEmpty
              ? widget.genitoreRelationController.text
              : null,
          decoration: InputDecoration(
            hintText: 'Seleziona il grado di parentela',
            errorText: widget.genitoreRelationError,
            prefixIcon: Padding(
              padding: EdgeInsets.all(3.w),
              child: CustomIconWidget(
                iconName: 'family_restroom',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 20,
              ),
            ),
          ),
          items: relations.map((String relation) {
            return DropdownMenuItem<String>(
              value: relation,
              child: Text(relation),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              widget.genitoreRelationController.text = newValue;
              setState(() {});
            }
          },
        ),
      ],
    );
  }

  Widget? _getPrefixIcon(String label) {
    String iconName;
    switch (label.toLowerCase()) {
      case 'nome *':
      case 'cognome *':
      case 'nome genitore/tutore *':
      case 'cognome genitore/tutore *':
        iconName = 'person';
        break;
      case 'email *':
      case 'email genitore/tutore *':
        iconName = 'email';
        break;
      case 'telefono *':
      case 'telefono genitore/tutore *':
        iconName = 'phone';
        break;
      case 'codice fiscale *':
      case 'codice fiscale genitore/tutore *':
        iconName = 'badge';
        break;
      case 'indirizzo *':
        iconName = 'home';
        break;
      case 'città *':
        iconName = 'location_city';
        break;
      case 'provincia *':
        iconName = 'map';
        break;
      case 'cap *':
        iconName = 'local_post_office';
        break;
      default:
        return null;
    }

    return Padding(
      padding: EdgeInsets.all(3.w),
      child: CustomIconWidget(
        iconName: iconName,
        color: AppTheme.lightTheme.colorScheme.primary,
        size: 20,
      ),
    );
  }
}
