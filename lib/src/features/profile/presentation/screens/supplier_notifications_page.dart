import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SupplierNotificationsPage extends StatefulWidget {
  const SupplierNotificationsPage({super.key});

  @override
  State<SupplierNotificationsPage> createState() =>
      _SupplierNotificationsPageState();
}

class _SupplierNotificationsPageState extends State<SupplierNotificationsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSavingPrefs = false;

  // Notification preference toggles
  bool _newOrders = true;
  bool _lowStock = true;
  bool _paymentUpdates = true;
  bool _promotions = false;
  bool _systemAlerts = true;

  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchPreferences(), _fetchNotifications()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchPreferences() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('supplier_notification_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _newOrders = data['new_orders'] ?? true;
          _lowStock = data['low_stock'] ?? true;
          _paymentUpdates = data['payment_updates'] ?? true;
          _promotions = data['promotions'] ?? false;
          _systemAlerts = data['system_alerts'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notification preferences: $e');
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .eq('role', 'supplier')
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() => _notifications = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSavingPrefs = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('supplier_notification_preferences').upsert({
        'user_id': user.id,
        'new_orders': _newOrders,
        'low_stock': _lowStock,
        'payment_updates': _paymentUpdates,
        'promotions': _promotions,
        'system_alerts': _systemAlerts,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved!'),
            backgroundColor: Color(0xFF4C8077),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingPrefs = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      setState(() {
        final index = _notifications.indexWhere(
          (n) => n['id'] == notificationId,
        );
        if (index != -1) _notifications[index]['is_read'] = true;
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to clear all notifications? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('notifications')
          .delete()
          .eq('user_id', user.id)
          .eq('role', 'supplier');

      setState(() => _notifications.clear());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared.'),
            backgroundColor: Color(0xFF4C8077),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  IconData _iconForType(String? type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'low_stock':
        return Icons.inventory_2_outlined;
      case 'payment':
        return Icons.payment_outlined;
      case 'promotion':
        return Icons.local_offer_outlined;
      case 'system':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'order':
        return const Color(0xFF4C8077);
      case 'low_stock':
        return Colors.orange;
      case 'payment':
        return Colors.blue;
      case 'promotion':
        return Colors.purple;
      case 'system':
        return Colors.grey;
      default:
        return const Color(0xFF4C8077);
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  // ─── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((n) => n['is_read'] != true)
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All',
              onPressed: _clearAllNotifications,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF4C8077),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Notification Preferences Card ───────────────────
                    _buildExpansionCard(
                      title: 'Notification Preferences',
                      icon: Icons.tune,
                      initiallyExpanded: true,
                      children: [
                        _buildToggleTile(
                          icon: Icons.shopping_bag_outlined,
                          label: 'New Orders',
                          subtitle: 'Get notified when you receive new orders',
                          value: _newOrders,
                          color: const Color(0xFF4C8077),
                          onChanged: (v) => setState(() => _newOrders = v),
                        ),
                        _buildToggleTile(
                          icon: Icons.inventory_2_outlined,
                          label: 'Low Stock Alerts',
                          subtitle:
                              'Alert when product inventory is running low',
                          value: _lowStock,
                          color: Colors.orange,
                          onChanged: (v) => setState(() => _lowStock = v),
                        ),
                        _buildToggleTile(
                          icon: Icons.payment_outlined,
                          label: 'Payment Updates',
                          subtitle:
                              'Notifications for payouts and transactions',
                          value: _paymentUpdates,
                          color: Colors.blue,
                          onChanged: (v) => setState(() => _paymentUpdates = v),
                        ),
                        _buildToggleTile(
                          icon: Icons.local_offer_outlined,
                          label: 'Promotions & Offers',
                          subtitle: 'Platform deals and promotional updates',
                          value: _promotions,
                          color: Colors.purple,
                          onChanged: (v) => setState(() => _promotions = v),
                        ),
                        _buildToggleTile(
                          icon: Icons.shield_outlined,
                          label: 'System Alerts',
                          subtitle: 'Important updates about your account',
                          value: _systemAlerts,
                          color: Colors.grey.shade600,
                          onChanged: (v) => setState(() => _systemAlerts = v),
                          isLast: true,
                        ),
                        // Save button inside expansion
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _isSavingPrefs
                                  ? null
                                  : _savePreferences,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4C8077),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              child: _isSavingPrefs
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save Preferences',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Recent Notifications Card ─────────────────────────
                    _buildExpansionCard(
                      title: 'Recent Notifications',
                      icon: Icons.notifications_outlined,
                      initiallyExpanded: true,
                      trailingBadge: unreadCount > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4C8077),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$unreadCount unread',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      children: _notifications.isEmpty
                          ? [_buildEmptyState()]
                          : _notifications
                                .map((n) => _buildNotificationTile(n))
                                .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  /// Matches the exact style of _buildExpansionSection in supplier_profile_screen.dart
  Widget _buildExpansionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
    Widget? trailingBadge,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4C8077).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF4C8077), size: 20),
          ),
          title: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              if (trailingBadge != null) ...[
                const SizedBox(width: 8),
                trailingBadge,
              ],
            ],
          ),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                activeTrackColor: const Color(
                  0xFF4C8077,
                ).withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFF4C8077),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 52),
      ],
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notification) {
    final bool isRead = notification['is_read'] == true;
    final String? type = notification['type'];
    final color = _colorForType(type);
    final icon = _iconForType(type);

    return GestureDetector(
      onTap: () {
        if (!isRead) _markAsRead(notification['id'].toString());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead
              ? Theme.of(context).cardColor
              : const Color(0xFF4C8077).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? Theme.of(context).dividerColor.withValues(alpha: 0.08)
                : const Color(0xFF4C8077).withValues(alpha: 0.25),
          ),
          boxShadow: isRead
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF4C8077).withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with unread dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (!isRead)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4C8077),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(notification['created_at']),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['body'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large bell with red badge — matches reference image
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C8077).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    size: 54,
                    color: Color(0xFF4C8077),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Nothing here!!!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the notification settings button\nbelow and check again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 210,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.tune, size: 18, color: Colors.white),
                label: const Text(
                  'Notification Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C8077),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
