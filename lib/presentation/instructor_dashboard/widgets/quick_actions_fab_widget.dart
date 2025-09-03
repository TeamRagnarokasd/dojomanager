import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';


class QuickActionsFabWidget extends StatefulWidget {
  final VoidCallback onClassCreated;
  final VoidCallback onProgressUpdated;

  const QuickActionsFabWidget({
    Key? key,
    required this.onClassCreated,
    required this.onProgressUpdated,
  }) : super(key: key);

  @override
  State<QuickActionsFabWidget> createState() => _QuickActionsFabWidgetState();
}

class _QuickActionsFabWidgetState extends State<QuickActionsFabWidget>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _expandAnimation.value,
              child: Opacity(
                opacity: _expandAnimation.value,
                child: Column(
                  children: [
                    _buildActionButton(
                      'Nuova Lezione',
                      Icons.add_box,
                      Colors.blue,
                      _showCreateClassDialog,
                    ),
                    SizedBox(height: 2.h),
                    _buildActionButton(
                      'Aggiorna Progresso',
                      Icons.trending_up,
                      Colors.green,
                      _showProgressUpdateDialog,
                    ),
                    SizedBox(height: 2.h),
                    _buildActionButton(
                      'Messaggio Studenti',
                      Icons.message,
                      Colors.orange,
                      _showMessageDialog,
                    ),
                    SizedBox(height: 3.h),
                  ],
                ),
              ),
            );
          },
        ),
        FloatingActionButton(
          onPressed: _toggleExpansion,
          backgroundColor: Colors.red,
          child: AnimatedRotation(
            turns: isExpanded ? 0.25 : 0.0,
            duration: Duration(milliseconds: 300),
            child: Icon(
              isExpanded ? Icons.close : Icons.add,
              color: Colors.white,
              size: 7.w,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(77)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: 3.w),
        FloatingActionButton(
          mini: true,
          onPressed: onPressed,
          backgroundColor: color,
          heroTag: label,
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }

  void _toggleExpansion() {
    setState(() {
      isExpanded = !isExpanded;
    });

    if (isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _showCreateClassDialog() {
    _toggleExpansion();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'Crea Nuova Lezione',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField('Disciplina', Icons.sports_mma),
            SizedBox(height: 2.h),
            _buildDialogField('Orario', Icons.access_time),
            SizedBox(height: 2.h),
            _buildDialogField('Livello', Icons.bar_chart),
            SizedBox(height: 2.h),
            _buildDialogField('Max Studenti', Icons.people),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onClassCreated();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Nuova lezione creata con successo!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Crea', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProgressUpdateDialog() {
    _toggleExpansion();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'Aggiorna Progresso Studente',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField('Nome Studente', Icons.person),
            SizedBox(height: 2.h),
            _buildDialogField('Disciplina', Icons.sports_mma),
            SizedBox(height: 2.h),
            _buildDialogField('Nuovo Livello/Cintura', Icons.emoji_events),
            SizedBox(height: 2.h),
            _buildDialogField('Note', Icons.note),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onProgressUpdated();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Progresso aggiornato con successo!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child:
                Text('Aggiorna', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMessageDialog() {
    _toggleExpansion();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'Invia Messaggio',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField('Destinatari', Icons.people),
            SizedBox(height: 2.h),
            _buildDialogField('Oggetto', Icons.subject),
            SizedBox(height: 2.h),
            Container(
              height: 12.h,
              child: TextField(
                maxLines: 5,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Messaggio',
                  labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.message, color: Colors.orange),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.withAlpha(77)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Messaggio inviato con successo!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Invia', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, IconData icon) {
    return TextField(
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
}