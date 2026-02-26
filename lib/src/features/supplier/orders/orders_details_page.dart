import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:med_shakthi/src/features/chat/services/chat_service.dart';
import 'package:med_shakthi/src/features/chat/presentation/screens/unified_chat_screen.dart';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, dynamic>? order;

  static const _teal = Color(0xFF4C8077);

  @override
  void initState() {
    super.initState();
    fetchOrderDetails();
  }

  Future<void> fetchOrderDetails() async {
    try {
      final response = await supabase
          .from('orders')
          .select('''
            *,
            order_details (*,
              products(name, image_url, category)
            ),
            users:user_id (name, phone)
          ''')
          .eq('id', widget.orderId)
          .single();

      if (mounted) {
        setState(() {
          order = response;
          isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading order: $e')));
      }
    }
  }

  Future<void> updateOrderStatus(String newStatus, {String? reason}) async {
    try {
      final update = <String, dynamic>{'status': newStatus};
      if (reason != null && reason.isNotEmpty) {
        update['cancellation_reason'] = reason;
      }
      await supabase.from('orders').update(update).eq('id', widget.orderId);
      await fetchOrderDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order marked as $newStatus'),
            backgroundColor: _statusColor(newStatus.toLowerCase()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  Future<void> _showCancelDialog() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Out of stock',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await updateOrderStatus('cancelled', reason: reasonCtrl.text.trim());
    }
  }

  Color _statusColor(String s) {
    switch (s) {
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

  IconData _statusIcon(String s) {
    switch (s) {
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final createdAt = DateTime.parse(order!['created_at']).toLocal();
    final formattedDate = DateFormat('d MMM yyyy, h:mm a').format(createdAt);
    final status = (order!['status'] ?? 'unknown').toString().toLowerCase();
    final items = (order!['order_details'] as List<dynamic>?) ?? [];
    final userData = order!['users'] as Map<String, dynamic>?;
    final buyerName = (userData?['name'] as String?)?.trim();
    final buyerNameDisplay = (buyerName != null && buyerName.isNotEmpty)
        ? buyerName
        : 'Customer';
    final phone = (userData?['phone'] as String?)?.trim() ?? '';
    final address = order!['shipping_address'] ?? 'Address not available';
    final orderNum =
        order!['order_number'] ?? widget.orderId.substring(0, 8).toUpperCase();
    final statusColor = _statusColor(status);
    final paymentMethod = order!['payment_method'] ?? 'Online';

    // Billing
    final itemsList = order!['order_details'] as List<dynamic>? ?? [];
    final subtotal = itemsList.fold<double>(
      0,
      (s, i) => s + ((i['price'] as num? ?? 0) * (i['quantity'] as num? ?? 0)),
    );
    final shippingFee = (order!['shipping'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (order!['total_amount'] as num?)?.toDouble() ?? subtotal;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Order $orderNum',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: fetchOrderDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── STATUS BADGE ───────────────────────────────────
              _StatusBadgeCard(
                status: status,
                statusColor: statusColor,
                statusIcon: _statusIcon(status),
                formattedDate: formattedDate,
                orderNum: orderNum,
                paymentMethod: paymentMethod,
              ),
              const SizedBox(height: 16),

              // ─── BUYER INFO ─────────────────────────────────────
              _SectionCard(
                title: 'Buyer Information',
                icon: Icons.person_outline,
                iconColor: _teal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: _teal.withValues(alpha: 0.12),
                          child: Text(
                            buyerNameDisplay[0].toUpperCase(),
                            style: const TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                buyerNameDisplay,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              if (phone.isNotEmpty)
                                Text(
                                  phone,
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Chat button inline
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            color: _teal,
                          ),
                          tooltip: 'Chat with Customer',
                          onPressed: () => _openChat(buyerNameDisplay),
                        ),
                      ],
                    ),
                    if (address.isNotEmpty) ...[
                      const Divider(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _teal,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodyMedium?.color,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── ACTION BUTTONS ─────────────────────────────────
              _buildActionButtons(status),
              const SizedBox(height: 16),

              // ─── ITEMS ORDERED ──────────────────────────────────
              _SectionCard(
                title: 'Items Ordered',
                icon: Icons.inventory_2_outlined,
                iconColor: _teal,
                child: Column(
                  children: items.isEmpty
                      ? [const Center(child: Text('No items found'))]
                      : items
                            .map<Widget>((item) => _buildItemRow(item, theme))
                            .toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ─── BILLING SUMMARY ────────────────────────────────
              _SectionCard(
                title: 'Billing Summary',
                icon: Icons.receipt_long_outlined,
                iconColor: _teal,
                child: Column(
                  children: [
                    _BillingRow(
                      label: 'Items Subtotal',
                      value: '₹${subtotal.toStringAsFixed(2)}',
                    ),
                    _BillingRow(
                      label: 'Shipping & Handling',
                      value: shippingFee > 0
                          ? '₹${shippingFee.toStringAsFixed(2)}'
                          : 'Free',
                    ),
                    const Divider(height: 20),
                    _BillingRow(
                      label: 'Grand Total',
                      value: '₹${grandTotal.toStringAsFixed(2)}',
                      bold: true,
                      color: _teal,
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

  Widget _buildActionButtons(String status) {
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showCancelDialog,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => updateOrderStatus('confirmed'),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Accept Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
          onPressed: () => updateOrderStatus('shipped'),
          icon: const Icon(Icons.local_shipping_outlined, size: 18),
          label: const Text(
            'Mark as Shipped',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    if (status == 'shipped') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => updateOrderStatus('delivered'),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text(
            'Mark as Delivered',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _openChat(String displayName) async {
    if (order == null || order!['user_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer info not available')),
      );
      return;
    }
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final supplierRes = await supabase
          .from('suppliers')
          .select('id')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (supplierRes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier profile not found')),
          );
        }
        return;
      }

      final chatId = await ChatService().getOrCreateChat(
        orderId: widget.orderId,
        supplierId: supplierRes['id'],
        userId: order!['user_id'],
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UnifiedChatScreen(
              chatId: chatId,
              otherUserName: displayName,
              otherUserId: order!['user_id'],
              otherUserImage: null,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
      }
    }
  }

  Widget _buildItemRow(Map<String, dynamic> item, ThemeData theme) {
    final product = item['products'] as Map<String, dynamic>? ?? {};
    final imageUrl = product['image_url'];
    final category = product['category'] ?? 'Medicine';
    final qty = item['quantity'] ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final lineTotal = qty * price;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SmartProductImage(
              imageUrl: imageUrl,
              category: category,
              fit: BoxFit.cover,
              width: 54,
              height: 54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['item_name'] ?? 'Unknown Product',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['brand'] ?? ''} ${item['unit_size'] != null ? "• ${item['unit_size']}" : ""}'
                      .trim(),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: $qty  ×  ₹${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _teal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Section Card ─────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 14, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─── Status Badge Card ─────────────────────────────────────────────────────

class _StatusBadgeCard extends StatelessWidget {
  final String status;
  final Color statusColor;
  final IconData statusIcon;
  final String formattedDate;
  final String orderNum;
  final String paymentMethod;

  const _StatusBadgeCard({
    required this.status,
    required this.statusColor,
    required this.statusIcon,
    required this.formattedDate,
    required this.orderNum,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'ORDER',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.5,
                    ),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  orderNum,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    paymentMethod,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
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
}

// ─── Billing Row ───────────────────────────────────────────────────────────

class _BillingRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _BillingRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
      color:
          color ?? (bold ? null : Theme.of(context).textTheme.bodySmall?.color),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
