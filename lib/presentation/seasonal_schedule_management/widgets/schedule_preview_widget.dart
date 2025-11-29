import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class SchedulePreviewWidget extends StatefulWidget {
  final Map<String, dynamic>? currentSeason;
  final List<Map<String, dynamic>> scheduleInstances;
  final List<Map<String, dynamic>> holidays;
  final VoidCallback onGenerateSchedule;

  const SchedulePreviewWidget({
    Key? key,
    this.currentSeason,
    required this.scheduleInstances,
    required this.holidays,
    required this.onGenerateSchedule,
  }) : super(key: key);

  @override
  State<SchedulePreviewWidget> createState() => _SchedulePreviewWidgetState();
}

class _SchedulePreviewWidgetState extends State<SchedulePreviewWidget>
    with SingleTickerProviderStateMixin {
  late TabController _previewTabController;
  String _selectedFilter = 'all';
  DateTime _selectedWeek = DateTime.now();

  final Map<String, String> _disciplineLabels = {
    'bjj': 'BJJ',
    'mma': 'MMA',
    'sambo': 'SAMBO',
    'grappling': 'Grappling',
    'fitness': 'Fitness',
  };

  final Map<String, Color> _disciplineColors = {
    'bjj': Colors.blue,
    'mma': Colors.red,
    'sambo': Colors.green,
    'grappling': Colors.orange,
    'fitness': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _previewTabController = TabController(length: 3, vsync: this);
    if (widget.currentSeason != null) {
      _selectedWeek = DateTime.parse(widget.currentSeason!['start_date']);
    }
  }

  @override
  void dispose() {
    _previewTabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredInstances {
    if (_selectedFilter == 'all') return widget.scheduleInstances;
    return widget.scheduleInstances
        .where((instance) => instance['discipline'] == _selectedFilter)
        .toList();
  }

  List<Map<String, dynamic>> get _weekInstances {
    final weekStart = _getWeekStart(_selectedWeek);
    final weekEnd = weekStart.add(Duration(days: 6));

    return _filteredInstances.where((instance) {
      final instanceDate = DateTime.parse(instance['class_date']);
      return instanceDate.isAfter(weekStart.subtract(Duration(days: 1))) &&
          instanceDate.isBefore(weekEnd.add(Duration(days: 1)));
    }).toList();
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  Map<String, dynamic> get _scheduleStats {
    final total = widget.scheduleInstances.length;
    final cancelled =
        widget.scheduleInstances
            .where(
              (i) =>
                  i['is_cancelled'] == true || i['is_holiday_affected'] == true,
            )
            .length;
    final active = total - cancelled;

    final byDiscipline = <String, int>{};
    for (final instance in widget.scheduleInstances) {
      final discipline = instance['discipline'] as String;
      byDiscipline[discipline] = (byDiscipline[discipline] ?? 0) + 1;
    }

    return {
      'total': total,
      'active': active,
      'cancelled': cancelled,
      'byDiscipline': byDiscipline,
      'holidays': widget.holidays.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentSeason == null) {
      return _buildNoSeasonWidget();
    }

    // Show content immediately, even if empty
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildPreviewHeader(),
          SizedBox(height: 2.h),
          Expanded(
            child: TabBarView(
              controller: _previewTabController,
              children: [
                _buildOverviewTab(),
                _buildWeeklyPreviewTab(),
                _buildStatisticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSeasonWidget() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Card(
          margin: EdgeInsets.all(6.w),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(8.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.preview,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.6),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Nessuna Stagione Configurata',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Prima di visualizzare l\'anteprima, configura una stagione nella sezione "Schema Orari"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 3.h),
                ElevatedButton.icon(
                  onPressed: () {
                    // Switch to first tab (Schema Orari)
                    final parentTabController =
                        context.findAncestorStateOfType<State>() as dynamic;
                    if (parentTabController?.mounted == true) {
                      try {
                        parentTabController._tabController.animateTo(0);
                      } catch (e) {
                        // Fallback - just show message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Vai alla sezione "Schema Orari" per configurare la stagione',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.settings),
                  label: Text('Configura Stagione'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewHeader() {
    return Card(
      margin: EdgeInsets.all(4.w),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.preview,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 28,
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anteprima Palinsesto',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        widget.scheduleInstances.isEmpty
                            ? 'Genera il palinsesto per visualizzare l\'anteprima'
                            : 'Visualizza il calendario completo prima della pubblicazione',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.scheduleInstances.isEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      widget.onGenerateSchedule();
                    },
                    icon: Icon(Icons.auto_awesome, size: 16),
                    label: Text('Genera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _previewTabController,
            labelColor: Theme.of(context).colorScheme.secondary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.secondary,
            tabs: [
              Tab(text: 'Panoramica'),
              Tab(text: 'Settimanale'),
              Tab(text: 'Statistiche'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.scheduleInstances.isEmpty)
              _buildEmptyScheduleWidget()
            else ...[
              _buildQuickStatsRow(),
              SizedBox(height: 3.h),
              _buildFilterChips(),
              SizedBox(height: 2.h),
              _buildInstancesList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScheduleWidget() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: Theme.of(context).colorScheme.secondary,
            ),
            SizedBox(height: 2.h),
            Text(
              'Palinsesto da Generare',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Genera automaticamente tutto il palinsesto stagionale basato sui template orari configurati nella sezione "Schema Orari"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onGenerateSchedule();
                },
                icon: Icon(Icons.auto_awesome),
                label: Text('Genera Palinsesto Automatico'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    final stats = _scheduleStats;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Lezioni Totali',
            '${stats['total']}',
            Icons.event,
            Theme.of(context).colorScheme.secondary,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: _buildStatCard(
            'Attive',
            '${stats['active']}',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: _buildStatCard(
            'Festività',
            '${stats['holidays']}',
            Icons.celebration,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 1.h),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 2.w,
      children: [
        FilterChip(
          label: Text('Tutte'),
          selected: _selectedFilter == 'all',
          onSelected: (_) => setState(() => _selectedFilter = 'all'),
        ),
        ..._disciplineLabels.entries.map((entry) {
          return FilterChip(
            label: Text(entry.value),
            selected: _selectedFilter == entry.key,
            onSelected: (_) => setState(() => _selectedFilter = entry.key),
            backgroundColor: (_disciplineColors[entry.key] ?? Colors.grey)
                .withValues(alpha: 0.1),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInstancesList() {
    final instances = _filteredInstances.take(50).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prossime Lezioni (${_filteredInstances.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: instances.length,
          itemBuilder: (context, index) {
            final instance = instances[index];
            return _buildInstanceCard(instance);
          },
        ),
        if (_filteredInstances.length > 50) ...[
          SizedBox(height: 2.h),
          Center(
            child: Text(
              'Mostrando prime 50 di ${_filteredInstances.length} lezioni',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInstanceCard(Map<String, dynamic> instance) {
    final classDate = DateTime.parse(instance['class_date']);
    final startTime = TimeOfDay.fromDateTime(
      DateFormat('HH:mm:ss').parse(instance['start_time']),
    );
    final endTime = TimeOfDay.fromDateTime(
      DateFormat('HH:mm:ss').parse(instance['end_time']),
    );
    final discipline = instance['discipline'];
    final isCancelled =
        instance['is_cancelled'] == true ||
        instance['is_holiday_affected'] == true;

    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isCancelled
                  ? Colors.red.withValues(alpha: 0.3)
                  : (_disciplineColors[discipline] ?? Colors.grey).withValues(
                    alpha: 0.3,
                  ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 6.h,
              decoration: BoxDecoration(
                color:
                    isCancelled
                        ? Colors.red
                        : (_disciplineColors[discipline] ?? Colors.grey),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 4.w),

            // Instance info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.w,
                          vertical: 0.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: (_disciplineColors[discipline] ?? Colors.grey)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _disciplineLabels[discipline] ?? discipline,
                          style: TextStyle(
                            color: _disciplineColors[discipline] ?? Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (isCancelled) ...[
                        SizedBox(width: 2.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 2.w,
                            vertical: 0.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            instance['is_holiday_affected'] == true
                                ? 'FESTIVITÀ'
                                : 'CANCELLATA',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    DateFormat('EEEE d MMMM yyyy', 'it_IT').format(classDate),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        '${startTime.format(context)} - ${endTime.format(context)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        instance['location'] ?? 'N/A',
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
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyPreviewTab() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          children: [
            _buildWeekSelector(),
            SizedBox(height: 3.h),
            _buildWeeklySchedule(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedWeek = _selectedWeek.subtract(Duration(days: 7));
                });
              },
              icon: Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${DateFormat('d MMM', 'it_IT').format(_getWeekStart(_selectedWeek))} - ${DateFormat('d MMM yyyy', 'it_IT').format(_getWeekStart(_selectedWeek).add(Duration(days: 6)))}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedWeek = _selectedWeek.add(Duration(days: 7));
                });
              },
              icon: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySchedule() {
    final weekDays = List.generate(
      7,
      (index) => _getWeekStart(_selectedWeek).add(Duration(days: index)),
    );

    return Column(
      children:
          weekDays.map((day) {
            final dayInstances =
                _weekInstances
                    .where(
                      (instance) => isSameDay(
                        DateTime.parse(instance['class_date']),
                        day,
                      ),
                    )
                    .toList();

            return _buildDaySchedule(day, dayInstances);
          }).toList(),
    );
  }

  Widget _buildDaySchedule(DateTime day, List<Map<String, dynamic>> instances) {
    final isToday = isSameDay(day, DateTime.now());
    final hasHoliday = widget.holidays.any(
      (holiday) => isSameDay(DateTime.parse(holiday['holiday_date']), day),
    );

    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isToday
                ? BorderSide(
                  color: Theme.of(context).colorScheme.secondary,
                  width: 2,
                )
                : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color:
                  hasHoliday
                      ? Colors.orange.withValues(alpha: 0.1)
                      : isToday
                      ? Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.1)
                      : Theme.of(context).cardColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('EEEE d', 'it_IT').format(day),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        hasHoliday
                            ? Colors.orange
                            : isToday
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                if (hasHoliday)
                  Icon(Icons.celebration, color: Colors.orange, size: 16)
                else if (isToday)
                  Icon(
                    Icons.today,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 16,
                  ),
                SizedBox(width: 2.w),
                Text(
                  '${instances.length} lezioni',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (instances.isEmpty)
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Text(
                hasHoliday
                    ? 'Giorno festivo - Nessuna lezione'
                    : 'Nessuna lezione programmata',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...instances
                .map((instance) => _buildWeeklyInstanceItem(instance))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildWeeklyInstanceItem(Map<String, dynamic> instance) {
    final startTime = TimeOfDay.fromDateTime(
      DateFormat('HH:mm:ss').parse(instance['start_time']),
    );
    final endTime = TimeOfDay.fromDateTime(
      DateFormat('HH:mm:ss').parse(instance['end_time']),
    );
    final discipline = instance['discipline'];
    final isCancelled =
        instance['is_cancelled'] == true ||
        instance['is_holiday_affected'] == true;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4.h,
            decoration: BoxDecoration(
              color:
                  isCancelled
                      ? Colors.red
                      : (_disciplineColors[discipline] ?? Colors.grey),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Row(
              children: [
                Text(
                  '${startTime.format(context)}-${endTime.format(context)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: (_disciplineColors[discipline] ?? Colors.grey)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _disciplineLabels[discipline] ?? discipline,
                    style: TextStyle(
                      color: _disciplineColors[discipline] ?? Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (isCancelled) ...[
                  SizedBox(width: 2.w),
                  Icon(Icons.cancel, color: Colors.red, size: 14),
                ],
                Spacer(),
                Text(
                  instance['location'] ?? '',
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
    );
  }

  Widget _buildStatisticsTab() {
    final stats = _scheduleStats;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiche Palinsesto',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),
            _buildStatsOverview(stats),
            SizedBox(height: 3.h),
            _buildDisciplineBreakdown(stats['byDiscipline']),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(Map<String, dynamic> stats) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panoramica Generale',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(
                    'Lezioni Totali',
                    '${stats['total']}',
                    Icons.event,
                  ),
                ),
                Expanded(
                  child: _buildStatRow(
                    'Attive',
                    '${stats['active']}',
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(
                    'Cancellate/Festività',
                    '${stats['cancelled']}',
                    Icons.cancel,
                  ),
                ),
                Expanded(
                  child: _buildStatRow(
                    'Giorni Festivi',
                    '${stats['holidays']}',
                    Icons.celebration,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: 2.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisciplineBreakdown(Map<String, int> byDiscipline) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribuzione per Disciplina',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),
            ...byDiscipline.entries.map((entry) {
              final discipline = entry.key;
              final count = entry.value;
              final color = _disciplineColors[discipline] ?? Colors.grey;

              return Container(
                margin: EdgeInsets.only(bottom: 2.h),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      _disciplineLabels[discipline] ?? discipline,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '$count lezioni',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
