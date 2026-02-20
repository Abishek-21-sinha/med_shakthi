import 'package:med_shakthi/src/features/products/presentation/screens/product_page.dart';
import 'package:med_shakthi/src/features/products/data/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/orders/models/order_detail_model.dart';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';
import 'package:med_shakthi/src/features/chat/services/chat_service.dart';
import 'package:med_shakthi/src/features/chat/presentation/screens/unified_chat_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const OrderDetailScreen({super.key, required this.orderData});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  List<OrderDetailModel> _items = [];

  // Stream for real-time order updates (status)
  late final Stream<List<Map<String, dynamic>>> _orderStream;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    // Initialize stream for the parent order
    _orderStream = supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', widget.orderData['id']);
  }

  Future<void> _fetchOrderDetails() async {
    try {
      final orderId = widget.orderData['id']; // UUID of the order
      if (orderId == null) return;

      final res = await supabase
          .from('order_details')
          .select(
            '*, products(*, suppliers(name, supplier_code, id, email, phone))',
          )
          .eq('order_id', orderId);

      final data = List<Map<String, dynamic>>.from(res);
      setState(() {
        _items = data.map((e) => OrderDetailModel.fromMap(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching details: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderGroupId = (widget.orderData['order_group_id'] ?? "N/A")
        .toString();
    final totalAmount = (widget.orderData['total_amount'] ?? 0).toString();
    final deliveryLocation =
        widget.orderData['shipping_address'] ?? "Address info not available";
    final paymentMode = widget.orderData['payment_method'] ?? "Online";
    final Color themeColor = Theme.of(context).primaryColor;
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.orderData['order_number']?.toString() ??
              'Order #${orderGroupId.substring(0, 8).toUpperCase()}',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _orderStream,
              builder: (context, snapshot) {
                // Get latest status from stream, fallback to widget data
                String status = (widget.orderData['status'] ?? "Pending")
                    .toString();
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  status = snapshot.data!.first['status'] ?? status;
                }

                // Get supplier info from the first item (assuming 1 order = 1 supplier)
                OrderDetailModel? firstItem;
                if (_items.isNotEmpty) {
                  firstItem = _items.first;
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Items List
                      const Text(
                        "Items",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._items.map((item) => _buildItemCard(item, themeColor)),

                      if (_items.isEmpty)
                        const Center(
                          child: Text("No items found for this order."),
                        ),

                      const SizedBox(height: 24),

                      // 2. Track Order (Real-time Status)
                      const Text(
                        'Track Order',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTrackOrderStrip(status),
                      const SizedBox(height: 24),

                      // 3. Delivery & Payment
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              title: 'Delivery Location',
                              value: deliveryLocation,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoCard(
                              title: 'Payment Mode',
                              value: paymentMode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 4. Order Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSummaryRow(
                              'Subtotal (Calculated)',
                              '₹${_calculateSubtotal().toStringAsFixed(2)}',
                            ),
                            const Divider(),
                            _buildSummaryRow(
                              'Total Amount',
                              '₹$totalAmount',
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 5. Actions
                      // Pass status and orderId to the new method
                      _buildActionButtonsWithCancellation(
                        context,
                        themeColor,
                        status,
                        widget.orderData['id'] ?? '',
                        firstItem,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  double _calculateSubtotal() {
    return _items.fold(0, (sum, item) => sum + (item.price * item.qty));
  }

  Widget _buildItemCard(OrderDetailModel item, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigate to Product Page with Supplier Details
            final product = Product(
              id: item.productId ?? '',
              name: item.itemName,
              price: item.price,
              image: item.imageUrl,
              category: "General", // Placeholder
              rating: 0.0, // Placeholder
              supplierName: item.supplierName,
              supplierCode: item.supplierCode,
              supplierId: item.supplierId,
            );

            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductPage(product: product)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SmartProductImage(
                    imageUrl: item.imageUrl,
                    category: item.brand,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.brand,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${item.unitSize} x ${item.qty}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (item.supplierName != null &&
                          item.supplierName!.isNotEmpty)
                        Text(
                          'Sold by: ${item.supplierName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${(item.price * item.qty).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Re-defined to accept status
  Widget _buildActionButtonsWithCancellation(
    BuildContext context,
    Color themeColor,
    String currentStatus,
    String orderId,
    OrderDetailModel? firstItem,
  ) {
    final canCancel = [
      'pending',
      'confirmed',
    ].contains(currentStatus.toLowerCase());

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (firstItem != null && firstItem.supplierId != null) {
                    try {
                      final currentUserId =
                          Supabase.instance.client.auth.currentUser!.id;
                      final chatId = await ChatService().getOrCreateChat(
                        orderId: orderId,
                        supplierId: firstItem.supplierId!,
                        userId: currentUserId,
                      );

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UnifiedChatScreen(
                              chatId: chatId,
                              otherUserName:
                                  firstItem.supplierName ?? 'Supplier',
                              otherUserId: firstItem.supplierId!,
                              otherUserImage:
                                  null, // Add supplier image if available in model
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error starting chat: $e')),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Supplier info not available'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.support_agent),
                label: const Text('Contact Supplier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: themeColor,
                  side: BorderSide(color: themeColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invoice download coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        if (canCancel) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showCancelDialog(context, orderId),
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              label: const Text("Cancel Order"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showCancelDialog(BuildContext context, String orderId) {
    final reasons = [
      "Order Created by Mistake",
      "Item Arriving Too Late",
      "Shipping Cost Too High",
      "Found Cheaper Somewhere Else",
      "Need to Change Shipping Address",
      "Other",
    ];

    String? selectedReason;
    final otherReasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Cancel Order"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Please select a reason for cancellation:",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ...reasons.map((reason) {
                    final isSelected = selectedReason == reason;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.red : null,
                        size: 20,
                      ),
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      onTap: () {
                        setDialogState(() {
                          selectedReason = reason;
                        });
                      },
                    );
                  }),
                  if (selectedReason == "Other")
                    TextField(
                      controller: otherReasonController,
                      decoration: const InputDecoration(
                        hintText: "Please specify reason",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 2,
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Keep Order"),
              ),
              ElevatedButton(
                onPressed: selectedReason == null
                    ? null
                    : () {
                        final finalReason = selectedReason == "Other"
                            ? otherReasonController.text
                            : selectedReason!;
                        if (finalReason.trim().isEmpty) return;

                        Navigator.pop(ctx);
                        _cancelOrder(orderId, finalReason);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Confirm Cancel"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cancelOrder(String orderId, String reason) async {
    try {
      if (!mounted) return;

      // Update status to 'cancelled' and save reason
      // Note: 'cancellation_reason' column must exist in 'orders' table
      await supabase
          .from('orders')
          .update({'status': 'cancelled', 'cancellation_reason': reason})
          .eq('id', orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully')),
        );
      }
    } catch (e) {
      debugPrint("Error cancelling order: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cancel order: $e')));
      }
    }
  }

  Widget _buildTrackOrderStrip(String currentStatus) {
    // DB Statuses: pending, confirmed, shipped, delivered, cancelled
    final stages = ['Pending', 'Confirmed', 'Shipped', 'Delivered'];

    final statusLower = currentStatus.toLowerCase();

    // If cancelled, show red strip
    if (statusLower == 'cancelled') {
      // Try to get reason from snapshot data if available (passed via finding it in _items or parent widget)
      // Since we don't have direct access to the 'orders' table stream data for 'cancellation_reason'
      // (as _orderStream gives us a List<Map> but we need to extract the field),
      // we might need to fetch it or rely on what's passed.
      // However, we can also look at the widget.orderData if it was passed initially,
      // OR we can make a small bold assumption that we should fetch it if missing.
      // For now, let's look at the stream snapshot data since we are inside the builder.

      // We need to access the snapshot data from here.
      // We can't access 'snapshot' variable from _buildTrackOrderStrip directly as it's outside scope.
      // We should pass the reason to this method.

      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: _orderStream,
        builder: (context, snapshot) {
          String reason = "Reason not specified";
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            reason = snapshot.data!.first['cancellation_reason'] ?? reason;
          } else {
            // Assuming widget.orderData is accessible and contains the initial order data
            // This might need adjustment based on how widget.orderData is structured and passed
            // For example, if widget.orderData is a Map<String, dynamic> directly
            // and contains 'cancellation_reason' key.
            // If widget.orderData is not available or doesn't contain it, this line might cause issues.
            // A safer approach might be to pass the reason directly to _buildTrackOrderStrip
            // or ensure _orderStream always provides it.
            // For now, keeping the user's logic as is, assuming widget.orderData is available.
            reason = widget.orderData['cancellation_reason'] ?? reason;
          }

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      "Order Cancelled",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Reason: $reason",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );
    }

    int currentIndex = -1;
    if (statusLower == 'pending') {
      currentIndex = 0;
    } else if (statusLower == 'confirmed' || statusLower == 'accepted') {
      currentIndex = 1;
    } else if (statusLower == 'shipped' || statusLower == 'dispatched') {
      currentIndex = 2;
    } else if (statusLower == 'delivered' || statusLower == 'completed') {
      currentIndex = 3;
    }

    // Fallback logic for safety
    if (currentIndex == -1 && statusLower != 'cancelled') currentIndex = 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(stages.length * 2 - 1, (index) {
              if (index % 2 == 0) {
                // Circle
                final circleIndex = index ~/ 2;
                final isCompleted = circleIndex <= currentIndex;

                // Color logic:
                // Completed -> Green (or Status Color)
                // Current -> Status Color
                // Upcoming -> Grey

                Color color;
                if (isCompleted) {
                  color = _getStatusColor(stages[circleIndex]);
                } else {
                  color = Colors.grey.shade300;
                }

                return Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                );
              } else {
                // Line
                final lineIndex = (index - 1) ~/ 2;
                final isCompleted = lineIndex < currentIndex;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: isCompleted
                        ? _getStatusColor(stages[lineIndex])
                        : Colors.grey.shade300,
                  ),
                );
              }
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stages.map((status) {
              final index = stages.indexOf(status);
              final isCurrent = index == currentIndex;
              return Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent ? Colors.black : Colors.grey,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'accepted':
        return Colors.blue;
      case 'shipped':
      case 'dispatched':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
