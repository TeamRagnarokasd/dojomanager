import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../services/child_profile_service.dart';
import '../../services/competitions_service.dart';
import './widgets/competition_calendar_upload_screen.dart';
import './widgets/competition_edit_sheet.dart';
import './widgets/competition_list_item.dart';
import './widgets/competition_participants_sheet.dart';

/// "Gare" (MMA / BJJ-Grappling / Sambo): calendario gare letto da
/// `competitions`, con interesse/iscrizione dell'allievo. Per admin, un
/// pulsante in AppBar apre "Carica calendario gare".
class GareScreen extends StatefulWidget {
  const GareScreen({super.key});

  @override
  State<GareScreen> createState() => _GareScreenState();
}

class _GareScreenState extends State<GareScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isAdmin = false;

  final Map<String, List<Map<String, dynamic>>> _competitionsByCategory = {};
  Map<String, Map<String, dynamic>> _interest = {};
  final Set<String> _loadingCategories = {};
  final Set<String> _pendingCompetitionIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: CompetitionsService.categories.length,
      vsync: this,
    );
    _checkAdmin();
    _loadCategory(CompetitionsService.categories[0]);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      final category = CompetitionsService.categories[_tabController.index];
      _loadCategory(category);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await CompetitionsService.instance.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadCategory(String category) async {
    if (_competitionsByCategory.containsKey(category)) return;
    setState(() => _loadingCategories.add(category));
    try {
      final competitions = await CompetitionsService.instance.getCompetitions(
        category: category,
      );
      final userId = ChildProfileService.getActiveUserId();
      final interest = userId == null
          ? <String, Map<String, dynamic>>{}
          : await CompetitionsService.instance.getInterestFor(userId);
      if (!mounted) return;
      setState(() {
        _competitionsByCategory[category] = competitions;
        _interest = {..._interest, ...interest};
        _loadingCategories.remove(category);
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories.remove(category));
    }
  }

  Future<void> _reloadCurrentCategory() async {
    final category = CompetitionsService.categories[_tabController.index];
    _competitionsByCategory.remove(category);
    await _loadCategory(category);
  }

  Future<void> _toggleInterested(String competitionId, bool value) async {
    final userId = ChildProfileService.getActiveUserId();
    if (userId == null) return;
    setState(() => _pendingCompetitionIds.add(competitionId));
    try {
      await CompetitionsService.instance.setInterest(
        competitionId: competitionId,
        userId: userId,
        interested: value,
      );
      final existing = _interest[competitionId] ?? <String, dynamic>{};
      setState(() {
        _interest = {
          ..._interest,
          competitionId: {...existing, 'interested': value},
        };
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) {
        setState(() => _pendingCompetitionIds.remove(competitionId));
      }
    }
  }

  Future<void> _toggleSelfRegistered(String competitionId, bool value) async {
    final userId = ChildProfileService.getActiveUserId();
    if (userId == null) return;
    setState(() => _pendingCompetitionIds.add(competitionId));
    try {
      await CompetitionsService.instance.setSelfRegistered(
        competitionId: competitionId,
        userId: userId,
        registered: value,
      );
      final existing = _interest[competitionId] ?? <String, dynamic>{};
      setState(() {
        _interest = {
          ..._interest,
          competitionId: {...existing, 'self_registered': value},
        };
      });
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) {
        setState(() => _pendingCompetitionIds.remove(competitionId));
      }
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openUploadCalendar() async {
    final published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CompetitionCalendarUploadScreen()),
    );
    if (published == true) {
      _competitionsByCategory.clear();
      _loadCategory(CompetitionsService.categories[_tabController.index]);
    }
  }

  void _showParticipants(Map<String, dynamic> competition) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompetitionParticipantsSheet(
        competitionId: competition['id'].toString(),
        competitionName: (competition['name'] ?? '').toString(),
      ),
    );
  }

  void _openEditCompetition(Map<String, dynamic> competition) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompetitionEditSheet(
        competition: competition,
        onSaved: _reloadCurrentCategory,
        onDeleted: _reloadCurrentCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gare'),
        actions: [
          if (_isAdmin)
            IconButton(
              onPressed: _openUploadCalendar,
              icon: const Icon(Icons.upload_file),
              tooltip: 'Carica calendario gare',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: CompetitionsService.categories
              .map((c) => Tab(text: CompetitionsService.categoryLabel(c)))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: CompetitionsService.categories
            .map((category) => _buildCategoryTab(category))
            .toList(),
      ),
    );
  }

  Widget _buildCategoryTab(String category) {
    if (_loadingCategories.contains(category) &&
        !_competitionsByCategory.containsKey(category)) {
      return const Center(child: CircularProgressIndicator());
    }

    final competitions = _competitionsByCategory[category] ?? [];
    if (competitions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reloadCurrentCategory,
        child: ListView(
          children: [
            SizedBox(height: 20.h),
            Center(
              child: Text(
                'Nessuna gara in programma',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadCurrentCategory,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: competitions.length,
        itemBuilder: (context, index) {
          final competition = competitions[index];
          final competitionId = competition['id'].toString();
          final row = _interest[competitionId];
          return CompetitionListItem(
            competition: competition,
            isInterested: row?['interested'] as bool? ?? false,
            isSelfRegistered: row?['self_registered'] as bool? ?? false,
            isPending: _pendingCompetitionIds.contains(competitionId),
            onToggleInterested: (value) =>
                _toggleInterested(competitionId, value),
            onToggleSelfRegistered: (value) =>
                _toggleSelfRegistered(competitionId, value),
            showParticipantsButton: _isAdmin,
            onShowParticipants: () => _showParticipants(competition),
            showEditButton: _isAdmin,
            onEdit: () => _openEditCompetition(competition),
          );
        },
      ),
    );
  }
}
