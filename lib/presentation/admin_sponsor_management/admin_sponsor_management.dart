import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import 'package:sizer/sizer.dart';

import '../../services/sponsor_service.dart';
import '../../widgets/main_navigation_wrapper.dart';
import './widgets/sponsor_card_widget.dart';
import './widgets/sponsor_form_dialog_widget.dart';
import './widgets/sponsor_stats_widget.dart';

class AdminSponsorManagement extends StatefulWidget {
  const AdminSponsorManagement({Key? key}) : super(key: key);

  @override
  State<AdminSponsorManagement> createState() => _AdminSponsorManagementState();
}

class _AdminSponsorManagementState extends State<AdminSponsorManagement> {
  List<Map<String, dynamic>> _sponsors = [];
  Map<String, int> _stats = {'total': 0, 'active': 0, 'inactive': 0};
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, active, inactive
  String _categoryFilter = 'all'; // all, sponsor, affiliazione

  @override
  void initState() {
    super.initState();
    _loadSponsors();
    _loadStats();
  }

  Future<void> _loadSponsors() async {
    try {
      setState(() => _isLoading = true);
      final sponsors = await SponsorService.getAllSponsors();
      if (mounted) {
        setState(() {
          _sponsors = sponsors;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading sponsors: $error');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorMessage('user_mgmt.load_sponsors_error'.tr());
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await SponsorService.getSponsorStats();
      if (mounted) {
        setState(() => _stats = stats);
      }
    } catch (error) {
      print('Error loading sponsor stats: $error');
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([_loadSponsors(), _loadStats()]);
  }

  List<Map<String, dynamic>> get _filteredSponsors {
    return _sponsors.where((sponsor) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          sponsor['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (sponsor['description']?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false);

      final matchesStatus =
          _statusFilter == 'all' || sponsor['status'] == _statusFilter;

      final matchesCategory =
          _categoryFilter == 'all' || sponsor['category'] == _categoryFilter;

      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();
  }

  void _showCreateSponsorDialog() {
    showDialog(
      context: context,
      builder: (context) => SponsorFormDialogWidget(
        onSponsorCreated: () {
          Navigator.pop(context);
          _refreshData();
          _showSuccessMessage('Sponsor creato con successo');
        },
      ),
    );
  }

  void _showEditSponsorDialog(Map<String, dynamic> sponsor) {
    showDialog(
      context: context,
      builder: (context) => SponsorFormDialogWidget(
        sponsor: sponsor,
        onSponsorUpdated: () {
          Navigator.pop(context);
          _refreshData();
          _showSuccessMessage('Sponsor aggiornato con successo');
        },
      ),
    );
  }

  Future<void> _deleteSponsor(String sponsorId, String sponsorName) async {
    final confirmed = await _showDeleteConfirmationDialog(sponsorName);
    if (!confirmed) return;

    try {
      final success = await SponsorService.deleteSponsor(sponsorId);
      if (success) {
        _refreshData();
        _showSuccessMessage('Sponsor eliminato con successo');
      } else {
        _showErrorMessage('user_mgmt.delete_sponsor_error'.tr());
      }
    } catch (error) {
      print('Error deleting sponsor: $error');
      _showErrorMessage('Errore nell\'eliminazione dello sponsor');
    }
  }

  Future<void> _toggleSponsorStatus(
    String sponsorId,
    String currentStatus,
  ) async {
    try {
      final success = await SponsorService.toggleSponsorStatus(
        sponsorId,
        currentStatus,
      );
      if (success) {
        _refreshData();
        final newStatus = currentStatus == 'active'
            ? 'disattivato'
            : 'attivato';
        _showSuccessMessage('Sponsor $newStatus con successo');
      } else {
        _showErrorMessage('user_mgmt.toggle_sponsor_error'.tr());
      }
    } catch (error) {
      print('Error toggling sponsor status: $error');
      _showErrorMessage('Errore nel cambio di stato dello sponsor');
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String sponsorName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('reminders.delete_confirm_title'.tr()),
            content: Text(
              'Sei sicuro di voler eliminare lo sponsor "$sponsorName"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('common.delete'.tr()),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('admin_sponsor.title'.tr()),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Aggiorna',
            ),
            IconButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.shopAdminOrders),
              icon: const Icon(Icons.shopping_cart),
              tooltip: 'Ordini Shop',
            ),
            IconButton(
              onPressed: _showCreateSponsorDialog,
              icon: const Icon(Icons.add),
              tooltip: 'Aggiungi Sponsor',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: CustomScrollView(
            slivers: [
              // Stats Section
              SliverToBoxAdapter(child: SponsorStatsWidget(stats: _stats)),

              // Search and Filter
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'admin_sponsor.search_hint'.tr(),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                        ),
                      ),

                      SizedBox(height: 2.h),

                      // Status Filter
                      Row(
                        children: [
                          Text(
                            'Stato: ',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Wrap(
                              spacing: 2.w,
                              children: [
                                _buildFilterChip(
                                  'disciplines.all'.tr(),
                                  'all',
                                  isStatus: true,
                                ),
                                _buildFilterChip(
                                  'Attivi',
                                  'active',
                                  isStatus: true,
                                ),
                                _buildFilterChip(
                                  'Inattivi',
                                  'inactive',
                                  isStatus: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 1.h),

                      // Category Filter
                      Row(
                        children: [
                          Text(
                            'Categoria: ',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Wrap(
                              spacing: 2.w,
                              children: [
                                _buildFilterChip(
                                  'Tutti',
                                  'all',
                                  isStatus: false,
                                ),
                                _buildFilterChip(
                                  'Sponsor',
                                  'sponsor',
                                  isStatus: false,
                                ),
                                _buildFilterChip(
                                  'Affiliazioni',
                                  'affiliazione',
                                  isStatus: false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Sponsors List
              _isLoading
                  ? SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : _buildSponsorsListSliver(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateSponsorDialog,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(
            Icons.add,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isStatus = true}) {
    final isSelected = isStatus
        ? _statusFilter == value
        : _categoryFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            if (isStatus) {
              _statusFilter = value;
            } else {
              _categoryFilter = value;
            }
          });
        }
      },
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSponsorsListSliver() {
    final filteredSponsors = _filteredSponsors;

    if (filteredSponsors.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.store_outlined,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              SizedBox(height: 2.h),
              Text(
                _searchQuery.isEmpty && _statusFilter == 'all'
                    ? 'common.no_sponsors'.tr()
                    : 'common.no_results'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                _searchQuery.isEmpty && _statusFilter == 'all'
                    ? 'Aggiungi il primo sponsor cliccando il pulsante +'
                    : 'Prova con criteri di ricerca diversi',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final sponsor = filteredSponsors[index];
          return SponsorCardWidget(
            sponsor: sponsor,
            onEdit: () => _showEditSponsorDialog(sponsor),
            onDelete: () => _deleteSponsor(sponsor['id'], sponsor['name']),
            onToggleStatus: () =>
                _toggleSponsorStatus(sponsor['id'], sponsor['status']),
          );
        }, childCount: filteredSponsors.length),
      ),
    );
  }
}
