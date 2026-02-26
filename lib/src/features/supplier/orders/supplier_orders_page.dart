import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/supplier/orders/orders_details_page.dart';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';
import 'package:intl/intl.dart';

class SupplierOrdersPage extends StatefulWidget {
  const SupplierOrdersPage({super.key});

  @override
  State<SupplierOrdersPage> createState() => _SupplierOrdersPageState();
}

class _SupplierOrdersPageState extends State<SupplierOrdersPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  String? _errorMessage;

  // Filter state
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final _searchCtrl = TextEditingController();

  // Priority order for status sorting
  static const _statusPriority = {
    'pending': 0,
    'confirmed': 1,
    'shipped': 2,
    'delivered': 3,
    'cancelled': 4,
  };

  static const _filterOptions = [
    'All',
    'Pending',
    'Confirmed',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final supplierData = await _supabase
          .from('suppliers')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (supplierData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final String supplierId = supplierData['id'];

      final response = await _supabase
          .from('order_details')
          .select('''
            *,
            products!inner(name, image_url, supplier_code),
            orders!inner(
              id,
              order_group_id,
              order_number,
              shipping_address,
              created_at,
              user_id,
              cancellation_reason,
              status,
              total_amount,
              payment_method,
              awb_code,
              courier_name,
              tracking_url,
              users:user_id(name, phone)
            )
          ''')
          .eq('supplier_id', supplierId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _getErrorMessage(e.code, e.message);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Unable to load orders. Please check your connection.';
        });
      }
    }
  }

  Future<void> _updateStatus(
    String orderId,
    String newStatus, {
    String? reason,
  }) async {
    try {
      final Map<String, dynamic> updates = {'status': newStatus.toLowerCase()};
      if (reason != null && reason.isNotEmpty) {
        updates['cancellation_reason'] = reason;
      }
      await _supabase.from('orders').update(updates).eq('id', orderId);
      await _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order marked as $newStatus'),
            backgroundColor: _statusColor(newStatus.toLowerCase()),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.code, e.message)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update order. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Filtered + sorted list ───────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredOrders {
    var list = _orders.where((o) {
      final parentOrder = o['orders'] as Map<String, dynamic>?;
      final product = o['products'] as Map<String, dynamic>?;
      if (parentOrder == null) return false;

      final status = (parentOrder['status'] ?? '').toString();

      // Status filter
      if (_selectedFilter != 'All' &&
          status.toLowerCase() != _selectedFilter.toLowerCase()) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final productName = (product?['name'] ?? '').toString().toLowerCase();
        final orderNum = (parentOrder['order_number'] ?? '')
            .toString()
            .toLowerCase();
        final address = (parentOrder['shipping_address'] ?? '')
            .toString()
            .toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!productName.contains(q) &&
            !orderNum.contains(q) &&
            !address.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by priority: pending first, then confirmed, then shipped, etc.
    list.sort((a, b) {
      final aStatus = ((a['orders'] as Map?)!['status'] ?? '').toLowerCase();
      final bStatus = ((b['orders'] as Map?)!['status'] ?? '').toLowerCase();
      final aPrio = _statusPriority[aStatus] ?? 5;
      final bPrio = _statusPriority[bStatus] ?? 5;
      if (aPrio != bPrio) return aPrio.compareTo(bPrio);
      // Within same status: newest first
      final aDate = (a['orders'] as Map?)!['created_at'] ?? '';
      final bDate = (b['orders'] as Map?)!['created_at'] ?? '';
      return bDate.compareTo(aDate);
    });

    return list;
  }

  Map<String, int> get _statusCounts {
    final counts = <String, int>{'All': _orders.length};
    for (final o in _orders) {
      final parentOrder = o['orders'] as Map<String, dynamic>?;
      final status = (parentOrder?['status'] ?? '').toString();
      final key = status[0].toUpperCase() + status.substring(1);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = Color(0xFF4C8077);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Manage Orders',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by product, order #, address...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // ── Filter Chips ────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filterOptions.length,
              separatorBuilder: (_, sep) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filterOptions[i];
                final isActive = f == _selectedFilter;
                final count = _statusCounts[f];
                return FilterChip(
                  selected: isActive,
                  onSelected: (_) => setState(() => _selectedFilter = f),
                  label: Text(
                    count != null && count > 0 ? '$f ($count)' : f,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isActive ? Colors.white : null,
                    ),
                  ),
                  selectedColor: _selectedFilter == 'Pending'
                      ? Colors.orange
                      : _selectedFilter == 'Cancelled'
                      ? Colors.red
                      : primary,
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── Body ────────────────────────────────────────────────
          Expanded(child: _buildBody(primary)),
        ],
      ),
    );
  }

  Widget _buildBody(Color primary) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final orders = _filteredOrders;

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No orders match your search'
                  : '$_selectedFilter orders will appear here',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    // Group by priority header
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: orders.length,
        itemBuilder: (ctx, i) {
          final order = orders[i];
          final prevOrder = i > 0 ? orders[i - 1] : null;

          final parentOrder = order['orders'] as Map<String, dynamic>;
          final prevParent = prevOrder != null
              ? prevOrder['orders'] as Map<String, dynamic>
              : null;
          final status = (parentOrder['status'] ?? '').toLowerCase();
          final prevStatus = prevParent != null
              ? (prevParent['status'] ?? '').toLowerCase()
              : null;

          final showHeader =
              i == 0 || (prevStatus != null && prevStatus != status);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                if (i > 0) const SizedBox(height: 12),
                _StatusHeader(status: status),
                const SizedBox(height: 8),
              ],
              _OrderCard(
                order: order,
                onUpdateStatus: _updateStatus,
                onRefresh: _fetchOrders,
              ),
            ],
          );
        },
      ),
    );
  }

  String _getErrorMessage(String? code, String message) {
    switch (code) {
      case '42P01':
        return 'Configuration error. Please contact support.';
      case '42501':
        return "You don't have permission to update this order.";
      default:
        if (message.contains('JWT')) {
          return 'Session expired. Please log in again.';
        }
        return 'An error occurred. Please try again.';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return const Color(0xFF6366F1);
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

/* ─────────────── Status Section Header ─────────────── */

class _StatusHeader extends StatelessWidget {
  final String status;

  const _StatusHeader({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          _label(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
      ],
    );
  }

  String _label() {
    switch (status) {
      case 'pending':
        return '⚡ NEEDS ACTION — PENDING';
      case 'confirmed':
        return '📦 READY TO SHIP — CONFIRMED';
      case 'shipped':
        return '🚚 IN TRANSIT — SHIPPED';
      case 'delivered':
        return '✅ DELIVERED';
      case 'cancelled':
        return '❌ CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  Color _color() {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return const Color(0xFF6366F1);
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/* ─────────────── Order Card ─────────────── */

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Future<void> Function(String, String, {String? reason}) onUpdateStatus;
  final VoidCallback onRefresh;

  const _OrderCard({
    required this.order,
    required this.onUpdateStatus,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parentOrder = order['orders'] as Map<String, dynamic>;
    final product = order['products'] as Map<String, dynamic>?;

    final orderId = parentOrder['id'] as String? ?? '';
    final status = (parentOrder['status'] ?? '').toString().toLowerCase();
    final productName = product?['name'] ?? 'Unknown Product';
    final imageUrl = product?['image_url'] ?? '';
    final qty = order['quantity'] ?? 0;
    final price = (order['price'] as num?)?.toDouble() ?? 0.0;
    final address = parentOrder['shipping_address'] ?? 'No address';
    final orderNum =
        parentOrder['order_number']?.toString() ??
        'Order #${orderId.substring(0, 8).toUpperCase()}';
    final createdAt = parentOrder['created_at'] as String?;
    final cancellationReason = parentOrder['cancellation_reason'];
    final hasCourier =
        parentOrder['courier_name'] != null || parentOrder['awb_code'] != null;

    final statusColor = _statusColor(status);

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedDate = DateFormat('d MMM, h:mm a').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: status == 'pending'
            ? Border.all(
                color: Colors.orange.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailsPage(orderId: orderId),
            ),
          );
          if (result == true) onRefresh();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: image + info + status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: SmartProductImage(
                        imageUrl: imageUrl,
                        category: productName,
                        width: 58,
                        height: 58,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty: $qty  •  ₹${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          orderNum,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Address + date row
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (formattedDate.isNotEmpty)
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),

              // Courier info badge (view-only tracking indicator)
              if (hasCourier) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00B894).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_rounded,
                        size: 13,
                        color: Color(0xFF00B894),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            if (parentOrder['courier_name'] != null)
                              parentOrder['courier_name'].toString(),
                            if (parentOrder['awb_code'] != null)
                              'AWB: ${parentOrder['awb_code']}',
                          ].join('  •  '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF00B894),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(
                        'VIEW ONLY',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF00B894),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Cancellation reason
              if (status == 'cancelled' && cancellationReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Reason: $cancellationReason',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ],

              // Action buttons — status-driven
              if (status == 'pending' ||
                  status == 'confirmed' ||
                  status == 'shipped') ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _buildActionButtons(context, status, orderId),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    String status,
    String orderId,
  ) {
    if (status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => _showRejectDialog(context, orderId),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => onUpdateStatus(orderId, 'Confirmed'),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4C8077),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      );
    }

    if (status == 'confirmed') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onUpdateStatus(orderId, 'Shipped'),
          icon: const Icon(Icons.local_shipping_rounded, size: 16),
          label: const Text('Mark as Dispatched'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    if (status == 'shipped') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => onUpdateStatus(orderId, 'Delivered'),
          icon: const Icon(Icons.verified_rounded, size: 16),
          label: const Text('Mark as Delivered'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showRejectDialog(BuildContext context, String orderId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Order'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Reason for rejection',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onUpdateStatus(orderId, 'Cancelled', reason: ctrl.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return const Color(0xFF6366F1);
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
