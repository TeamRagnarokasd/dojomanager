import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

class PendingRegistrationsWidget extends StatefulWidget {
  const PendingRegistrationsWidget({super.key});

  @override
  State<PendingRegistrationsWidget> createState() =>
      _PendingRegistrationsWidgetState();
}

class _PendingRegistrationsWidgetState
    extends State<PendingRegistrationsWidget> {
  List<Map<String, dynamic>> _pendingRegistrations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRegistrations();
  }

  Future<void> _loadPendingRegistrations() async {
    try {
      final client = SupabaseService.instance.client;

      final response = await client
          .from('pending_registrations')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      setState(() {
        _pendingRegistrations = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading pending registrations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveRegistration(Map<String, dynamic> registration) async {
    try {
      final client = SupabaseService.instance.client;

      // Update registration status
      await client.from('pending_registrations').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': client.auth.currentUser?.id,
      }).eq('id', registration['id']);

      print('Aggiornamento DB riuscito, provo a inviare la mail...');

      // Send welcome email via Edge Function
      try {
        final email = registration['email'] as String?;
        final fullName = registration['full_name'] as String?;
        if (email != null && email.isNotEmpty) {
          final responseFunction = await client.functions.invoke(
            'send-welcome-email',
            body: {'email': email, 'fullName': fullName ?? ''},
          );
          print('Risposta funzione: ${responseFunction.data}');
        } else {
          print('Email non disponibile nel record, chiamata funzione saltata.');
        }
      } catch (e) {
        print('Errore chiamata funzione: $e');
      }

      Fluttertoast.showToast(
        msg: "Registrazione approvata con successo",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      await _loadPendingRegistrations();
    } catch (e) {
      print('Errore aggiornamento DB: $e');
      debugPrint('Error approving registration: $e');
      Fluttertoast.showToast(
        msg: "Errore nell'approvazione",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _rejectRegistration(Map<String, dynamic> registration) async {
    try {
      final client = SupabaseService.instance.client;

      // Update registration status
      await client.from('pending_registrations').update({
        'status': 'rejected',
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': client.auth.currentUser?.id,
      }).eq('id', registration['id']);

      Fluttertoast.showToast(
        msg: "Registrazione rifiutata",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      await _loadPendingRegistrations();
    } catch (e) {
      debugPrint('Error rejecting registration: $e');
      Fluttertoast.showToast(
        msg: "Errore nel rifiuto",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppTheme.cardLight,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const CustomIconWidget(
                  iconName: 'pending_actions',
                  color: Colors.white,
                ),
                SizedBox(width: 2.w),
                Text(
                  'Registrazioni in Sospeso',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(maxHeight: 40.h),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pendingRegistrations.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Text(
                          'Nessuna registrazione in sospeso',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _pendingRegistrations.length,
                        itemBuilder: (context, index) {
                          final registration = _pendingRegistrations[index];
                          return _buildRegistrationCard(registration);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationCard(Map<String, dynamic> registration) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.w),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  registration['full_name'] ?? 'Nome non disponibile',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.w),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  registration['requested_role'] ?? 'N/A',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.w),
          Text(
            registration['email'] ?? 'Email non disponibile',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: AppTheme.textSecondary,
            ),
          ),
          if (registration['phone'] != null) ...[
            SizedBox(height: 1.w),
            Text(
              registration['phone'],
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (registration['message'] != null) ...[
            SizedBox(height: 2.w),
            Text(
              registration['message'],
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 3.w),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveRegistration(registration),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    'Approva',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 2.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _rejectRegistration(registration),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(
                    'Rifiuta',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 2.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
