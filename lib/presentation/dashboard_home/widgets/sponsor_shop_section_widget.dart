import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_export.dart';
import '../../../services/shop_service.dart';
import '../../../services/sponsor_service.dart';

class SponsorShopSectionWidget extends StatefulWidget {
  const SponsorShopSectionWidget({Key? key}) : super(key: key);

  @override
  State<SponsorShopSectionWidget> createState() =>
      _SponsorShopSectionWidgetState();
}

class _SponsorShopSectionWidgetState extends State<SponsorShopSectionWidget> {
  List<Map<String, dynamic>> _sponsors = [];
  bool _isLoading = true;
  bool _shopEnabledForMe = false;
  Set<String> _sponsorIdsWithShop = {};

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    try {
      final sponsors = await SponsorService.getActiveSponsors();
      if (mounted) {
        setState(() {
          _sponsors = sponsors;
          _isLoading = false;
        });
      }
      _loadShopEligibility(sponsors);
    } catch (error) {
      print('Error loading sponsors: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Il "carrello sponsor" è una funzione aggiuntiva, dietro
  // shop_enabled_for_me(): se il flag è spento, l'utente non è tester, o
  // qualcosa va storto, questa resta semplicemente a false e il banner si
  // comporta esattamente come oggi.
  Future<void> _loadShopEligibility(List<Map<String, dynamic>> sponsors) async {
    if (sponsors.isEmpty) return;
    try {
      final enabled = await ShopService.instance.isEnabledForMe();
      if (!enabled) return;

      final sponsorIds = sponsors
          .map((sponsor) => sponsor['id']?.toString())
          .whereType<String>()
          .toList();
      final idsWithShop =
          await ShopService.instance.getSponsorIdsWithShop(sponsorIds);
      if (mounted) {
        setState(() {
          _shopEnabledForMe = true;
          _sponsorIdsWithShop = idsWithShop;
        });
      }
    } catch (_) {
      // La funzione shop resta nascosta in caso di errore.
    }
  }

  bool _hasShopFor(Map<String, dynamic> sponsor) {
    final sponsorId = sponsor['id']?.toString();
    return _shopEnabledForMe &&
        sponsorId != null &&
        _sponsorIdsWithShop.contains(sponsorId);
  }

  void _openCartScreen(Map<String, dynamic> sponsor) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      AppRoutes.shopCart,
      arguments: {
        'sponsorId': sponsor['id'],
        'sponsorName': sponsor['name'],
      },
    );
  }

  Future<void> _handleBannerTap(Map<String, dynamic> sponsor) async {
    if (_hasShopFor(sponsor)) {
      await _showShopTipDialogIfNeeded(sponsor);
      if (!mounted) return;
    }
    _launchUrl(sponsor['external_url']);
  }

  Future<void> _showShopTipDialogIfNeeded(Map<String, dynamic> sponsor) async {
    final sponsorId = sponsor['id']?.toString();
    if (sponsorId == null) return;

    final alreadyDismissed =
        await ShopService.instance.isShopTipDismissed(sponsorId);
    if (alreadyDismissed || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ordina con lo sconto del team'),
        content: const Text(
          'Per ordinare con lo sconto del team: fai il carrello sul sito, '
          'fai uno screenshot con tutti i prodotti e il totale, poi '
          'caricalo toccando l\'icona del carrello su questo banner.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ShopService.instance.dismissShopTip(sponsorId);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Non mostrare più'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Continua'),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCartIcon(Map<String, dynamic> sponsor) {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _openCartScreen(sponsor),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.shopping_cart,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      // Add vibration feedback
      HapticFeedback.lightImpact();

      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showErrorSnackBar('common.link_open_error'.tr());
      }
    } catch (error) {
      print('Error launching URL: $error');
      _showErrorSnackBar('common.link_open_failed'.tr());
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'dashboard.sponsor_shop'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            SizedBox(height: 2.h),
            Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (_sponsors.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if no sponsors
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'dashboard.sponsor_shop'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              Icon(
                Icons.store,
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.7),
                size: 24,
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'dashboard.sponsor_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: 2.h),

          // Sponsors Grid
          _sponsors.length == 1
              ? _buildSingleSponsorCard(_sponsors.first)
              : _buildSponsorsGrid(),
        ],
      ),
    );
  }

  Widget _buildSingleSponsorCard(Map<String, dynamic> sponsor) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleBannerTap(sponsor),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Sponsor Image
              Container(
                height: 15.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomImageWidget(
                    imageUrl: sponsor['image_url'] ?? '',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: 15.h,
                  ),
                ),
              ),

              SizedBox(height: 3.h),

              // Sponsor Info
              Column(
                children: [
                  Text(
                    sponsor['name'] ?? 'Sponsor',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  if (sponsor['description'] != null &&
                      sponsor['description'].isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    Text(
                      sponsor['description'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  SizedBox(height: 2.h),

                  // Visit Button
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'dashboard.visit_shop'.tr(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(
                          Icons.open_in_new,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 18,
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
    );

    if (!_hasShopFor(sponsor)) return card;

    return Stack(
      children: [
        card,
        Positioned(top: 8, right: 8, child: _buildShopCartIcon(sponsor)),
      ],
    );
  }

  Widget _buildSponsorsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _sponsors.length == 2 ? 2 : 3,
        crossAxisSpacing: 3.w,
        mainAxisSpacing: 2.h,
        childAspectRatio: 1.2,
      ),
      itemCount: _sponsors.length,
      itemBuilder: (context, index) {
        final sponsor = _sponsors[index];
        return _buildSponsorGridItem(sponsor);
      },
    );
  }

  Widget _buildSponsorGridItem(Map<String, dynamic> sponsor) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleBannerTap(sponsor),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image fills entire container
                CustomImageWidget(
                  imageUrl: sponsor['image_url'] ?? '',
                  fit: BoxFit.cover, // CHANGED: cover instead of contain
                  width: double.infinity,
                  height: double.infinity,
                ),
                // Gradient overlay for text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
                // Sponsor name and icon at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sponsor['name'] ?? 'Sponsor',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 0.5.h),
                        Icon(
                          Icons.open_in_new,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!_hasShopFor(sponsor)) return card;

    return Stack(
      children: [
        card,
        Positioned(top: 4, right: 4, child: _buildShopCartIcon(sponsor)),
      ],
    );
  }
}
