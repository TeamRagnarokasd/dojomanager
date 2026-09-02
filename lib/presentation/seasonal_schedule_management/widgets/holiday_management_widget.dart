import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:sizer/sizer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HolidayManagementWidget extends StatefulWidget {
  final Map<String, dynamic>? currentSeason;
  final List<Map<String, dynamic>> holidays;
  final VoidCallback onHolidaysUpdated;

  const HolidayManagementWidget({
    Key? key,
    this.currentSeason,
    required this.holidays,
    required this.onHolidaysUpdated,
  }) : super(key: key);

  @override
  State<HolidayManagementWidget> createState() =>
      _HolidayManagementWidgetState();
}

class _HolidayManagementWidgetState extends State<HolidayManagementWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Predefined Italian holidays
  final List<Map<String, dynamic>> _italianHolidays = [
    {'name': 'Capodanno', 'date': '01-01'},
    {'name': 'Epifania', 'date': '01-06'},
    {'name': 'Festa della Liberazione', 'date': '04-25'},
    {'name': 'Festa del Lavoro', 'date': '05-01'},
    {'name': 'Festa della Repubblica', 'date': '06-02'},
    {'name': 'Ferragosto', 'date': '08-15'},
    {'name': 'Ognissanti', 'date': '11-01'},
    {'name': 'Immacolata Concezione', 'date': '12-08'},
    {'name': 'Natale', 'date': '12-25'},
    {'name': 'Santo Stefano', 'date': '12-26'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.currentSeason != null) {
      _focusedDay = DateTime.parse(widget.currentSeason!['start_date']);
    }
  }

  Future<void> _addHoliday(DateTime date, String name,
      {bool affectsAll = true}) async {
    try {
      await _supabase.from('seasonal_holidays').insert({
        'seasonal_schedule_id': widget.currentSeason!['id'],
        'holiday_date': DateFormat('yyyy-MM-dd').format(date),
        'holiday_name': name,
        'affects_all_classes': affectsAll,
        'notes': 'Aggiunto automaticamente',
      });

      widget.onHolidaysUpdated();
      _showSuccessSnackBar('Festività aggiunta: $name');
    } catch (error) {
      _showErrorSnackBar('holidays.add_error'.tr());
    }
  }

  Future<void> _removeHoliday(String holidayId) async {
    try {
      await _supabase.from('seasonal_holidays').delete().eq('id', holidayId);

      widget.onHolidaysUpdated();
      _showSuccessSnackBar('Festività rimossa');
    } catch (error) {
      _showErrorSnackBar('holidays.remove_error'.tr());
    }
  }

  Future<void> _bulkAddNationalHolidays() async {
    if (widget.currentSeason == null) return;

    final startYear = DateTime.parse(widget.currentSeason!['start_date']).year;
    final endYear = DateTime.parse(widget.currentSeason!['end_date']).year;
    final years = startYear == endYear ? [startYear] : [startYear, endYear];

    int addedCount = 0;

    try {
      for (final year in years) {
        for (final holiday in _italianHolidays) {
          final dateParts = holiday['date'].split('-');
          final month = int.parse(dateParts[0]);
          final day = int.parse(dateParts[1]);
          final holidayDate = DateTime(year, month, day);

          // Check if date falls within season
          final seasonStart =
              DateTime.parse(widget.currentSeason!['start_date']);
          final seasonEnd = DateTime.parse(widget.currentSeason!['end_date']);

          if (holidayDate.isAfter(seasonStart.subtract(Duration(days: 1))) &&
              holidayDate.isBefore(seasonEnd.add(Duration(days: 1)))) {
            // Check if holiday doesn't already exist
            final existingHoliday = widget.holidays.any((h) =>
                DateTime.parse(h['holiday_date'])
                    .isAtSameMomentAs(holidayDate));

            if (!existingHoliday) {
              await _supabase.from('seasonal_holidays').insert({
                'seasonal_schedule_id': widget.currentSeason!['id'],
                'holiday_date': DateFormat('yyyy-MM-dd').format(holidayDate),
                'holiday_name': holiday['name'],
                'affects_all_classes': true,
                'notes': 'Festività nazionale italiana',
              });
              addedCount++;
            }
          }
        }
      }

      widget.onHolidaysUpdated();
      _showSuccessSnackBar('Aggiunte $addedCount festività nazionali');
    } catch (error) {
      _showErrorSnackBar('holidays.national_add_error'.tr());
    }
  }

  void _showAddHolidayDialog([DateTime? preselectedDate]) {
    showDialog(
      context: context,
      builder: (context) => _HolidayEditorDialog(
        initialDate: preselectedDate ?? _selectedDay ?? DateTime.now(),
        seasonStart: DateTime.parse(widget.currentSeason!['start_date']),
        seasonEnd: DateTime.parse(widget.currentSeason!['end_date']),
        onSave: (date, name, affectsAll) async {
          await _addHoliday(date, name, affectsAll: affectsAll);
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  bool _isHoliday(DateTime day) {
    return widget.holidays.any(
        (holiday) => isSameDay(DateTime.parse(holiday['holiday_date']), day));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentSeason == null) {
      return _buildNoSeasonWidget();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          SizedBox(height: 3.h),
          _buildCalendarWidget(),
          SizedBox(height: 3.h),
          _buildHolidaysList(),
        ],
      ),
    );
  }

  Widget _buildNoSeasonWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          SizedBox(height: 2.h),
          Text(
            'seasonal_schedule.no_season_title'.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Configura prima una stagione per gestire le festività',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.celebration,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestione Festività',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        'Segna i giorni festivi per cancellare automaticamente le lezioni',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddHolidayDialog(),
                    icon: Icon(Icons.add, size: 16),
                    label: Text('holidays.add_holiday'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _bulkAddNationalHolidays,
                    icon: Icon(Icons.flag, size: 16),
                    label: Text('holidays.national_holidays'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarWidget() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calendario Stagionale',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 2.h),
            TableCalendar<String>(
              firstDay: DateTime.parse(widget.currentSeason!['start_date']),
              lastDay: DateTime.parse(widget.currentSeason!['end_date']),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });

                // Show quick add dialog if clicking on non-holiday date
                if (!_isHoliday(selectedDay)) {
                  _showAddHolidayDialog(selectedDay);
                }
              },
              holidayPredicate: _isHoliday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
                holidayTextStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                holidayDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
                markerDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                titleTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
            ),
            SizedBox(height: 2.h),
            _buildCalendarLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('class_schedule.status_holiday'.tr(), Colors.orange),
        _buildLegendItem('Oggi',
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
        _buildLegendItem(
            'holidays.selected'.tr(), Theme.of(context).colorScheme.secondary),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 1.w),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildHolidaysList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Festività Programmate (${widget.holidays.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        SizedBox(height: 2.h),
        if (widget.holidays.isEmpty)
          _buildEmptyHolidaysWidget()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: widget.holidays.length,
            itemBuilder: (context, index) {
              final holiday = widget.holidays[index];
              return _buildHolidayCard(holiday);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyHolidaysWidget() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: 2.h),
            Text(
              'holidays.no_holidays_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            SizedBox(height: 1.h),
            Text(
              'holidays.no_holidays_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayCard(Map<String, dynamic> holiday) {
    final holidayDate = DateTime.parse(holiday['holiday_date']);
    final isUpcoming = holidayDate.isAfter(DateTime.now());

    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isUpcoming ? Icons.upcoming : Icons.event_busy,
                color: Colors.orange,
                size: 20,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday['holiday_name'],
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    DateFormat('EEEE d MMMM yyyy', 'it_IT').format(holidayDate),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  if (holiday['notes'] != null &&
                      holiday['notes'].isNotEmpty) ...[
                    SizedBox(height: 0.5.h),
                    Text(
                      holiday['notes'],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: () => _removeHoliday(holiday['id']),
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Holiday Editor Dialog
class _HolidayEditorDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime seasonStart;
  final DateTime seasonEnd;
  final Function(DateTime, String, bool) onSave;

  const _HolidayEditorDialog({
    Key? key,
    required this.initialDate,
    required this.seasonStart,
    required this.seasonEnd,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_HolidayEditorDialog> createState() => _HolidayEditorDialogState();
}

class _HolidayEditorDialogState extends State<_HolidayEditorDialog> {
  final _nameController = TextEditingController();
  late DateTime _selectedDate;
  bool _affectsAllClasses = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveHoliday() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('holidays.enter_holiday_name'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    Navigator.pop(context);
    widget.onSave(_selectedDate, _nameController.text, _affectsAllClasses);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'holidays.add_holiday_dialog'.tr(),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nome Festività *',
              hintText: 'es. Natale, Ferragosto',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          SizedBox(height: 2.h),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: widget.seasonStart,
                lastDate: widget.seasonEnd,
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Festività *',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    DateFormat('EEEE d MMMM yyyy', 'it_IT')
                        .format(_selectedDate),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 2.h),
          CheckboxListTile(
            value: _affectsAllClasses,
            onChanged: (value) =>
                setState(() => _affectsAllClasses = value ?? true),
            title: Text(
              'Cancella tutte le lezioni',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              'Deseleziona per configurare discipline specifiche',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _saveHoliday,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
          ),
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}
