import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
import '../../theme/app_theme.dart';
import './widgets/availability_indicator_widget.dart';
import './widgets/booking_confirmation_widget.dart';
import './widgets/booking_header_widget.dart';
import './widgets/cancellation_policy_widget.dart';
import './widgets/class_details_section_widget.dart';
import './widgets/payment_method_section_widget.dart';
import './widgets/student_selection_widget.dart';

class ClassBooking extends StatefulWidget {
  const ClassBooking({Key? key}) : super(key: key);

  @override
  State<ClassBooking> createState() => _ClassBookingState();
}

class _ClassBookingState extends State<ClassBooking>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Booking state variables
  String? _selectedStudentId;
  String? _selectedPaymentMethod;
  bool _isBookingProcessing = false;
  bool _bookingCompleted = false;
  String? _bookingId;
  String? _qrCode;

  // Class data (would come from arguments in real app)
  final Map<String, dynamic> _classData = {
    'id': 'class_001',
    'discipline': 'BJJ',
    'instructor': {
      'name': 'Marco Rossi',
      'photo':
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    },
    'date': '2025-08-30',
    'time': '19:00 - 20:30',
    'duration': '1h 30min',
    'capacity': 20,
    'booked': 15,
    'level': 'Intermedio',
    'equipment': 'Gi obbligatorio',
    'description':
        'Lezione di Brazilian Jiu-Jitsu focalizzata su tecniche di guardia e passaggio.',
    'location': 'Palestra Principale',
    'price': 25.00,
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadClassData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  void _loadClassData() {
    // In real app, extract from ModalRoute.of(context)!.settings.arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      // Update _classData with passed arguments
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bookingCompleted) {
      return _buildBookingConfirmation();
    }

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 50 * _slideAnimation.value),
            child: Opacity(opacity: _fadeAnimation.value, child: _buildBody()),
          );
        },
      ),
      bottomNavigationBar: _buildBookingButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Prenotazione Lezione',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Image.asset(
          AppConstants.teamLogo,
          width: 8.w,
          height: 4.h,
          fit: BoxFit.contain,
        ),
        SizedBox(width: 4.w),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        children: [
          BookingHeaderWidget(classData: _classData),
          SizedBox(height: 3.h),
          ClassDetailsSectionWidget(classData: _classData),
          SizedBox(height: 3.h),
          AvailabilityIndicatorWidget(
            capacity: _classData['capacity'],
            booked: _classData['booked'],
          ),
          SizedBox(height: 3.h),
          StudentSelectionWidget(
            selectedStudentId: _selectedStudentId,
            onStudentSelected: (studentId) {
              setState(() => _selectedStudentId = studentId);
            },
          ),
          SizedBox(height: 3.h),
          PaymentMethodSectionWidget(
            selectedMethod: _selectedPaymentMethod,
            onMethodSelected: (method) {
              setState(() => _selectedPaymentMethod = method);
            },
            classPrice: _classData['price'],
          ),
          SizedBox(height: 3.h),
          CancellationPolicyWidget(),
          SizedBox(height: 10.h), // Space for bottom button
        ],
      ),
    );
  }

  Widget _buildBookingButton() {
    final bool canBook =
        _selectedStudentId != null &&
        _selectedPaymentMethod != null &&
        !_isBookingProcessing;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: canBook ? _processBooking : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canBook ? Colors.red : Colors.grey[700],
            padding: EdgeInsets.symmetric(vertical: 2.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
            ),
            elevation: canBook ? 4 : 0,
          ),
          child:
              _isBookingProcessing
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 4.w,
                        height: 4.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'Elaborazione...',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                  : Text(
                    'Conferma Prenotazione - €${_classData['price'].toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildBookingConfirmation() {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Prenotazione Confermata',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Image.asset(
            AppConstants.teamLogo,
            width: 8.w,
            height: 4.h,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: BookingConfirmationWidget(
        bookingId: _bookingId!,
        qrCode: _qrCode!,
        classData: _classData,
        onDone: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _processBooking() async {
    setState(() => _isBookingProcessing = true);

    try {
      // Simulate booking API call
      await Future.delayed(Duration(seconds: 2));

      // Simulate SumUp/Satispay integration
      final paymentResult = await _processPayment();

      if (paymentResult['success']) {
        // Generate booking confirmation
        final bookingId = 'TR${DateTime.now().millisecondsSinceEpoch}';
        final qrCode = 'QR_${bookingId}_${_classData['id']}';

        setState(() {
          _bookingId = bookingId;
          _qrCode = qrCode;
          _bookingCompleted = true;
          _isBookingProcessing = false;
        });

        _showSuccessMessage();
      } else {
        _showErrorMessage(paymentResult['error']);
        setState(() => _isBookingProcessing = false);
      }
    } catch (e) {
      _showErrorMessage('Errore durante la prenotazione. Riprova.');
      setState(() => _isBookingProcessing = false);
    }
  }

  Future<Map<String, dynamic>> _processPayment() async {
    // Simulate external payment processing
    await Future.delayed(Duration(milliseconds: 1500));

    if (_selectedPaymentMethod == 'sumup' ||
        _selectedPaymentMethod == 'satispay') {
      // In real app, integrate with SumUp/Satispay APIs
      return {'success': true};
    } else if (_selectedPaymentMethod == 'subscription') {
      // Use subscription credits
      return {'success': true};
    } else if (_selectedPaymentMethod == 'card') {
      // Process saved card
      return {'success': true};
    }

    return {'success': false, 'error': 'Metodo di pagamento non valido'};
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 2.w),
            Text(
              'Prenotazione confermata con successo!',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }
}
