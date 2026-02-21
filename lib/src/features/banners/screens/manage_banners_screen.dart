import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/banner_model_supabase.dart';
import '../services/banner_service_supabase.dart';
import 'create_banner_screen.dart';

class ManageBannersScreen extends StatefulWidget {
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  final _bannerService = BannerServiceSupabase();
  late final String _userId;

  StreamSubscription<List<SupabaseBannerModel>>? _bannerSub;
  List<SupabaseBannerModel> _banners = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _subscribeToStream();
  }

  void _subscribeToStream() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _bannerSub?.cancel();
    _bannerSub = _bannerService
        .getSupplierBannersStream(_userId)
        .listen(
          (banners) {
            if (mounted) {
              setState(() {
                _banners = banners
                    .where((b) => b.supplierId == _userId)
                    .toList();
                _isLoading = false;
              });
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                _error = e.toString();
                _isLoading = false;
              });
            }
          },
        );
  }

  @override
  void dispose() {
    _bannerSub?.cancel();
    super.dispose();
  }

  Future<void> _navigateToCreate({SupabaseBannerModel? banner}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateBannerScreen(existingBanner: banner),
      ),
    );
    // Re-subscribe to get fresh data when returning
    _subscribeToStream();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Banners'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
            tooltip: 'Create Banner',
            onPressed: () => _navigateToCreate(),
          ),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load banners',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _subscribeToStream,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_banners.isEmpty) {
      return _buildEmptyState(colorScheme);
    }

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async => _subscribeToStream(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _banners.length,
        itemBuilder: (context, index) {
          return _buildBannerCard(_banners[index], colorScheme);
        },
      ),
    );
  }

  Widget _buildBannerCard(SupabaseBannerModel banner, ColorScheme colorScheme) {
    final now = DateTime.now();
    final isExpired = banner.endDate.isBefore(now);
    final isUpcoming = banner.startDate.isAfter(now);

    Color statusColor;
    String statusLabel;
    if (isExpired) {
      statusColor = colorScheme.error;
      statusLabel = 'EXPIRED';
    } else if (isUpcoming) {
      statusColor = Colors.orange;
      statusLabel = 'UPCOMING';
    } else if (banner.active) {
      statusColor = Colors.green;
      statusLabel = 'ACTIVE';
    } else {
      statusColor = colorScheme.onSurface.withValues(alpha: 0.4);
      statusLabel = 'INACTIVE';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                Image.network(
                  banner.imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          color: colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: colorScheme.onSurfaceVariant,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
                // Status Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Banner Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  banner.subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Category & Dates chips
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.category_outlined,
                      banner.category,
                      colorScheme,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.calendar_today,
                      '${banner.startDate.day}/${banner.startDate.month} - ${banner.endDate.day}/${banner.endDate.month}',
                      colorScheme,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateToCreate(banner: banner),
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        label: Text(
                          'Edit',
                          style: TextStyle(color: colorScheme.primary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleStatus(banner),
                        icon: Icon(
                          banner.active ? Icons.pause : Icons.play_arrow,
                          size: 18,
                          color: banner.active ? Colors.orange : Colors.green,
                        ),
                        label: Text(
                          banner.active ? 'Pause' : 'Activate',
                          style: TextStyle(
                            color: banner.active ? Colors.orange : Colors.green,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: banner.active
                                ? Colors.orange.withValues(alpha: 0.5)
                                : Colors.green.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDelete(banner),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        label: Text(
                          'Delete',
                          style: TextStyle(color: colorScheme.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.error.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(SupabaseBannerModel banner) async {
    try {
      await _bannerService.toggleBannerStatus(banner.id, !banner.active);
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              banner.active
                  ? 'Banner paused successfully'
                  : 'Banner activated successfully',
            ),
            backgroundColor: colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(SupabaseBannerModel banner) async {
    final confirm = await _showDeleteConfirmation();
    if (confirm == true && mounted) {
      try {
        await _bannerService.deleteBanner(banner.id, banner.imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Banner deleted'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildInfoChip(IconData icon, String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.campaign_outlined,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Banners Yet',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first promotional banner',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _navigateToCreate(),
            icon: const Icon(Icons.add),
            label: const Text('Create Banner'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation() {
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Banner',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            'Are you sure you want to delete this banner? This action cannot be undone.',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
