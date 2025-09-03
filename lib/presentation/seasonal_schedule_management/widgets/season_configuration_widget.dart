import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class SeasonConfigurationWidget extends StatefulWidget {
  final Map<String, dynamic>? currentSeason;
  final Function(Map<String, dynamic>) onSeasonCreated;
  final VoidCallback onSeasonUpdated;

  const SeasonConfigurationWidget({
    Key? key,
    this.currentSeason,
    required this.onSeasonCreated,
    required this.onSeasonUpdated,
  }) : super(key: key);

  @override
  State<SeasonConfigurationWidget> createState() =>
      _SeasonConfigurationWidgetState();
}

class _SeasonConfigurationWidgetState extends State<SeasonConfigurationWidget> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 90));
  bool _showStartCalendar = false;
  bool _showEndCalendar = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    if (widget.currentSeason != null) {
      _titleController.text = widget.currentSeason!['title'] ?? '';
      _descriptionController.text = widget.currentSeason!['description'] ?? '';
      _startDate = DateTime.parse(widget.currentSeason!['start_date']);
      _endDate = DateTime.parse(widget.currentSeason!['end_date']);
    }
  }

  void _createOrUpdateSeason() {
    if (_titleController.text.isEmpty) {
      _showErrorMessage('Inserisci il titolo della stagione');
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      _showErrorMessage('La data fine deve essere successiva alla data inizio');
      return;
    }

    final seasonData = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
      'status': 'draft',
    };

    widget.onSeasonCreated(seasonData);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.currentSeason == null) ...[
            _buildCreateSeasonCard(),
            SizedBox(height: 3.h),
          ] else ...[
            _buildExistingSeasonCard(),
            SizedBox(height: 3.h),
          ],
          _buildSeasonDetailsForm(),
        ],
      ),
    );
  }

  Widget _buildCreateSeasonCard() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
            SizedBox(height: 2.h),
            Text(
              'Crea Nuovo Palinsesto Stagionale',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Configura un nuovo periodo stagionale con date di inizio e fine, gestione festività e schema orari automatico',
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

  Widget _buildExistingSeasonCard() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_view_month,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 24,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stagione Attuale',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        widget.currentSeason!['title'] ?? 'Senza titolo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 2.w),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.currentSeason!['start_date']))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.currentSeason!['end_date']))}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonDetailsForm() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurazione Stagione',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 3.h),

            // Season Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Titolo Stagione *',
                hintText: 'es. Stagione Autunno 2025',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            SizedBox(height: 2.h),

            // Season Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descrizione (opzionale)',
                hintText:
                    'Descrivi il contenuto e gli obiettivi della stagione',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            SizedBox(height: 3.h),

            // Date Selection Section
            Text(
              'Periodo Stagionale',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 2.h),

            Row(
              children: [
                Expanded(
                  child: _buildDateSelector(
                    'Data Inizio',
                    _startDate,
                    Icons.event_available,
                    () => setState(
                        () => _showStartCalendar = !_showStartCalendar),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: _buildDateSelector(
                    'Data Fine',
                    _endDate,
                    Icons.event_busy,
                    () => setState(() => _showEndCalendar = !_showEndCalendar),
                  ),
                ),
              ],
            ),

            if (_showStartCalendar) ...[
              SizedBox(height: 2.h),
              _buildCalendarWidget(true),
            ],

            if (_showEndCalendar) ...[
              SizedBox(height: 2.h),
              _buildCalendarWidget(false),
            ],

            SizedBox(height: 4.h),

            // Duration Info
            _buildDurationInfo(),

            SizedBox(height: 4.h),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: ElevatedButton(
                onPressed: _createOrUpdateSeason,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  widget.currentSeason == null
                      ? 'Crea Stagione'
                      : 'Aggiorna Stagione',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(
      String label, DateTime date, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 2.w),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarWidget(bool isStartDate) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TableCalendar<String>(
        firstDay: DateTime.now().subtract(Duration(days: 30)),
        lastDay: DateTime.now().add(Duration(days: 365)),
        focusedDay: isStartDate ? _startDate : _endDate,
        selectedDayPredicate: (day) {
          return isSameDay(isStartDate ? _startDate : _endDate, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            if (isStartDate) {
              _startDate = selectedDay;
              _showStartCalendar = false;
              if (_endDate.isBefore(_startDate)) {
                _endDate = _startDate.add(Duration(days: 90));
              }
            } else {
              _endDate = selectedDay;
              _showEndCalendar = false;
              if (_endDate.isBefore(_startDate)) {
                _startDate = _endDate.subtract(Duration(days: 90));
              }
            }
          });
        },
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.error,
          ),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
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
      ),
    );
  }

  Widget _buildDurationInfo() {
    final duration = _endDate.difference(_startDate);
    final weeks = (duration.inDays / 7).ceil();

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Durata Stagione',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${duration.inDays} giorni • $weeks settimane',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
