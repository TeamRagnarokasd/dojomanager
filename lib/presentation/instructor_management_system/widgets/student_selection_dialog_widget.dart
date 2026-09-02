import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/instructor_management_service.dart';
import '../../../core/app_export.dart';

class StudentSelectionDialogWidget extends StatefulWidget {
  final VoidCallback onStudentPromoted;

  const StudentSelectionDialogWidget({
    super.key,
    required this.onStudentPromoted,
  });

  @override
  State<StudentSelectionDialogWidget> createState() =>
      _StudentSelectionDialogWidgetState();
}

class _StudentSelectionDialogWidgetState
    extends State<StudentSelectionDialogWidget> {
  final InstructorManagementService _instructorService =
      InstructorManagementService();

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isPromoting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final students = await _instructorService.getApprovedStudents();

      setState(() {
        _students = students;
        _filteredStudents = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterStudents(String query) {
    setState(() {
      _searchQuery = query;
      _filteredStudents = _students.where((student) {
        final name = student['full_name']?.toString().toLowerCase() ?? '';
        final email = student['email']?.toString().toLowerCase() ?? '';
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || email.contains(searchLower);
      }).toList();
    });
  }

  Future<void> _promoteStudent(Map<String, dynamic> student) async {
    try {
      setState(() => _isPromoting = true);

      await _instructorService.promoteStudentToInstructor(student['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student['full_name']} promosso a istruttore!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onStudentPromoted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'instructor_mgmt.promote_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isPromoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.school, color: const Color(0xFF4CAF50), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'student_reg_ui.select_student'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'student_reg_ui.promote_student_subtitle'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: TextField(
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'reminders.search_name_email'.tr(),
                  hintStyle: GoogleFonts.inter(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: _filterStudents,
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50),
                        ),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'student_reg_ui.load_students_error'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadStudents,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                ),
                                child: Text(
                                  'common.retry'.tr(),
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _filteredStudents.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_search,
                                    size: 64,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'student_reg_ui.no_approved_students'
                                            .tr()
                                        : 'student_reg_ui.no_search_results'
                                            .tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'student_reg_ui.no_students_to_promote'
                                            .tr()
                                        : 'student_reg_ui.try_different_search'
                                            .tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];
                                return _buildStudentCard(student);
                              },
                            ),
            ),

            // Footer Info
            if (!_isLoading && _filteredStudents.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'student_reg_ui.promotion_auto_role'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[400],
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

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              _isPromoting ? null : () => _showPromotionConfirmation(student),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: const Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: student['profile_image_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: student['profile_image_url'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF3A3A3A),
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 25,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF3A3A3A),
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 25,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF3A3A3A),
                            child: const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 25,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Student Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['full_name'] ??
                            'registration_mgmt.name_unavailable'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        student['email'] ?? 'common.not_available'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                      if (student['created_at'] != null)
                        Text(
                          'student_reg_ui.enrolled_on'.tr(namedArgs: {
                            'date': _formatDate(student['created_at']),
                          }),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),

                // Promote Button
                Icon(
                  Icons.arrow_forward_ios,
                  color: const Color(0xFF4CAF50),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'student_reg_ui.invalid_date'.tr();
    }
  }

  Future<void> _showPromotionConfirmation(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          'student_reg_ui.confirm_promotion'.tr(),
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'student_reg_ui.promote_confirm_message'.tr(namedArgs: {
                'name': '${student['full_name']}',
              }),
              style: GoogleFonts.inter(color: Colors.grey[300]),
            ),
            const SizedBox(height: 16),
            Text(
              'student_reg_ui.what_will_happen'.tr(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Il ruolo cambierà da "student" a "instructor"',
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            Text(
              '• Verrà creato un profilo istruttore',
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            Text(
              '• Avrà accesso al dashboard istruttore',
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: Text(
              'student_reg_ui.promote'.tr(),
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _promoteStudent(student);
    }
  }
}
