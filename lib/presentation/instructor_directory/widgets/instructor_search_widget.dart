import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class InstructorSearchWidget extends StatelessWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;

  const InstructorSearchWidget({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: searchQuery.isNotEmpty
              ? const Color(0xFFFF0000)
              : Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: TextField(
        onChanged: onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Cerca istruttore, disciplina o specializzazione...',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.all(3.w),
            child: CustomIconWidget(
              iconName: 'search',
              color: searchQuery.isNotEmpty
                  ? const Color(0xFFFF0000)
                  : Colors.grey[400]!,
              size: 20,
            ),
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => onSearchChanged(''),
                  child: Padding(
                    padding: EdgeInsets.all(3.w),
                    child: CustomIconWidget(
                      iconName: 'clear',
                      color: Colors.grey[400]!,
                      size: 20,
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 4.w,
            vertical: 3.w,
          ),
        ),
      ),
    );
  }
}
