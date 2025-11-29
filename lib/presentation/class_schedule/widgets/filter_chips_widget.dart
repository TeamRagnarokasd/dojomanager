import 'package:flutter/material.dart';


class FilterChipsWidget extends StatefulWidget {
  final List<String> selectedFilters;
  final Function(String) onFilterToggle;

  const FilterChipsWidget({
    Key? key,
    required this.selectedFilters,
    required this.onFilterToggle,
  }) : super(key: key);

  @override
  State<FilterChipsWidget> createState() => _FilterChipsWidgetState();
}

class _FilterChipsWidgetState extends State<FilterChipsWidget> {
  @override
  Widget build(BuildContext context) {
    // Updated disciplines to match the database enum values
    // Only including valid discipline_type enum values: ['bjj', 'mma', 'sambo', 'grappling', 'fitness']
    final disciplines = [
      'Tutti',
      'BJJ',
      'MMA',
      'Sambo',
      'Grappling',
      'Fitness'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: disciplines.length,
        itemBuilder: (context, index) {
          final discipline = disciplines[index];
          final isSelected = widget.selectedFilters.contains(discipline);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(discipline),
              selected: isSelected,
              onSelected: (bool selected) {
                widget.onFilterToggle(discipline);
              },
              selectedColor: Theme.of(context).primaryColor.withAlpha(51),
              checkmarkColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.grey.withAlpha(26),
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.withAlpha(77),
                width: 1.5,
              ),
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }
}