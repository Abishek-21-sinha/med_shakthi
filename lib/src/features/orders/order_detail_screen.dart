import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:med_shakthi/src/features/cart/data/cart_data.dart';
import 'package:med_shakthi/src/features/cart/data/cart_item.dart';
import 'package:med_shakthi/src/features/cart/presentation/screens/cart_page.dart';
import 'package:med_shakthi/src/core/utils/custom_snackbar.dart';
import 'package:med_shakthi/src/features/products/presentation/screens/product_page.dart';
import 'package:med_shakthi/src/features/products/data/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/orders/models/order_detail_model.dart';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';
import 'package:med_shakthi/src/features/chat/services/chat_service.dart';
import 'package:med_shakthi/src/features/chat/presentation/screens/unified_chat_screen.dart';
import 'invoice_page.dart';
import 'widgets/delivery_tracking_card.dart';

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
            '*, products(*, suppliers(name, supplier_code, id, email, phone, company_name, company_address, drug_license_number, drug_license_expiry, gst_number))',
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
    final totalAmount =
        (widget.orderData['total_amount'] as num?)?.toDouble() ?? 0.0;
    final shippingFee =
        (widget.orderData['shipping'] as num?)?.toDouble() ?? 0.0;
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
                // Get latest data from stream, fallback to widget data
                String status = (widget.orderData['status'] ?? "Pending")
                    .toString();
                String? awbCode = widget.orderData['awb_code'] as String?;
                String? shipmentId =
                    widget.orderData['shiprocket_shipment_id'] as String?;
                String? courierName =
                    widget.orderData['courier_name'] as String?;
                String? trackingUrl =
                    widget.orderData['tracking_url'] as String?;

                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final latest = snapshot.data!.first;
                  status = latest['status'] ?? status;
                  awbCode = latest['awb_code'] as String? ?? awbCode;
                  shipmentId =
                      latest['shiprocket_shipment_id'] as String? ?? shipmentId;
                  courierName =
                      latest['courier_name'] as String? ?? courierName;
                  trackingUrl =
                      latest['tracking_url'] as String? ?? trackingUrl;
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
                      const SizedBox(height: 16),

                      // 2b. Shiprocket Courier Tracking Card
                      if (awbCode != null ||
                          shipmentId != null ||
                          courierName != null)
                        DeliveryTrackingCard(
                          awbCode: awbCode,
                          shiprocketShipmentId: shipmentId,
                          courierName: courierName,
                          trackingUrl: trackingUrl,
                        ),
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
                            // Items Subtotal
                            _buildSummaryRow(
                              'Items Subtotal',
                              '₹${_calculateSubtotal().toStringAsFixed(2)}',
                            ),
                            const SizedBox(height: 8),
                            // Shipping fee from DB
                            _buildSummaryRow(
                              'Shipping & Handling',
                              shippingFee > 0
                                  ? '₹${shippingFee.toStringAsFixed(2)}'
                                  : 'Free',
                            ),
                            const SizedBox(height: 4),
                            const Divider(),
                            // Grand Total
                            _buildSummaryRow(
                              'Grand Total',
                              '₹${totalAmount.toStringAsFixed(2)}',
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
      bottomNavigationBar: _items.isNotEmpty && !_loading
          ? _buildReorderBottomBar(context, Theme.of(context).primaryColor)
          : null,
    );
  }

  Widget _buildReorderBottomBar(BuildContext context, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _handleReorder(context),
            icon: const Icon(Icons.shopping_cart_checkout),
            label: const Text(
              "Reorder Items",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B894),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReorder(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final cartData = context.read<CartData>();
      int itemsAdded = 0;
      int itemsSkipped = 0;

      for (var item in _items) {
        if (item.productId == null) continue;

        // Fetch fresh product info to check stock and active status
        final pRes = await supabase
            .from('products')
            .select('stock_quantity, is_active, price')
            .eq('id', item.productId!)
            .maybeSingle();

        if (pRes == null) {
          itemsSkipped++;
          continue;
        }

        final isActive = pRes['is_active'] == true;
        final stock = pRes['stock_quantity'] as int? ?? 0;
        final currentPrice = (pRes['price'] as num?)?.toDouble() ?? item.price;

        if (!isActive || stock <= 0) {
          itemsSkipped++;
          continue;
        }

        // Add to cart (limit to stock if previously ordered quantity exceeds current stock)
        final quantityToAdd = item.qty > stock ? stock : item.qty;

        cartData.addItem(
          CartItem(
            id: item.productId!,
            name: item.itemName,
            title: item.itemName,
            brand: "General",
            size: item.unitSize,
            price: currentPrice,
            imagePath: item.imageUrl,
            imageUrl: item.imageUrl,
            quantity: quantityToAdd,
          ),
        );
        itemsAdded++;
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (itemsAdded > 0) {
        showCustomSnackBar(
          context,
          itemsSkipped > 0
              ? "Added $itemsAdded items to cart. Some items were out of stock or unavailable."
              : "All items added to cart successfully!",
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartPage()),
        );
      } else {
        showCustomSnackBar(
          context,
          "Sorry, none of these items are currently available for reorder.",
          isError: true,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      showCustomSnackBar(context, "Failed to reorder items: $e", isError: true);
    }
  }

  double _calculateSubtotal() {
    return _items.fold(0, (sum, item) => sum + (item.price * item.qty));
  }

  String _currentStatus() =>
      (widget.orderData['status'] ?? '').toString().toLowerCase();

  Widget _buildItemCard(OrderDetailModel item, Color themeColor) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius:
                _currentStatus() == 'delivered' && item.productId != null
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  )
                : BorderRadius.circular(12),
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
                final product = Product(
                  id: item.productId ?? '',
                  name: item.itemName,
                  price: item.price,
                  image: item.imageUrl,
                  category: "General",
                  rating: 0.0,
                  supplierName: item.supplierName,
                  supplierCode: item.supplierCode,
                  supplierId: item.supplierId,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductPage(product: product),
                  ),
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
        ),
        // Leave a Review — only shown when Delivered and productId available
        if (_currentStatus() == 'delivered' && item.productId != null)
          _ReviewTrigger(
            orderId: widget.orderData['id'] ?? '',
            productId: item.productId!,
            productName: item.itemName,
          ),
        const SizedBox(height: 12),
      ],
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
                  final itemMaps = _items
                      .map(
                        (item) => {
                          'item_name': item.itemName,
                          'brand': item.brand,
                          'unit_size': item.unitSize,
                          'quantity': item.qty,
                          'price': item.price,
                        },
                      )
                      .toList();
                  final supplierInfo = _items.isNotEmpty
                      ? {
                          'name': _items.first.supplierName ?? '',
                          'company': _items.first.supplierCompany ?? '',
                          'address': _items.first.supplierAddress ?? '',
                          'email': _items.first.supplierEmail ?? '',
                          'phone': _items.first.supplierPhone ?? '',
                          'dl': _items.first.supplierDl ?? '',
                          'dlExpiry': _items.first.supplierDlExpiry ?? '',
                          'gst': _items.first.supplierGst ?? '',
                        }
                      : <String, dynamic>{};

                  final userData =
                      widget.orderData['users'] as Map<String, dynamic>? ?? {};

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InvoicePage(
                        orderData: widget.orderData,
                        items: itemMaps,
                        supplierInfo: supplierInfo,
                        buyerName: userData['name'] ?? '',
                        buyerPhone: userData['phone'] ?? '',
                      ),
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

/* ─────────────────── REVIEW TRIGGER ─────────────────── */

class _ReviewTrigger extends StatefulWidget {
  final String orderId;
  final String productId;
  final String productName;

  const _ReviewTrigger({
    required this.orderId,
    required this.productId,
    required this.productName,
  });

  @override
  State<_ReviewTrigger> createState() => _ReviewTriggerState();
}

class _ReviewTriggerState extends State<_ReviewTrigger> {
  bool _hasReviewed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkIfReviewed();
  }

  Future<void> _checkIfReviewed() async {
    try {
      final res = await Supabase.instance.client
          .from('product_reviews')
          .select('id')
          .eq('order_id', widget.orderId)
          .eq('product_id', widget.productId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _hasReviewed = res != null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openReviewSheet() async {
    final reviewed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewBottomSheet(
        orderId: widget.orderId,
        productId: widget.productId,
        productName: widget.productName,
      ),
    );
    if (reviewed == true && mounted) {
      setState(() => _hasReviewed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: _hasReviewed
            ? Colors.green.withValues(alpha: 0.08)
            : primary.withValues(alpha: 0.07),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: InkWell(
        onTap: _hasReviewed ? null : _openReviewSheet,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                _hasReviewed ? Icons.check_circle : Icons.rate_review_outlined,
                size: 18,
                color: _hasReviewed ? Colors.green : primary,
              ),
              const SizedBox(width: 8),
              Text(
                _hasReviewed ? 'Review submitted' : 'Leave a Review',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _hasReviewed ? Colors.green : primary,
                ),
              ),
              if (!_hasReviewed) ...[
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 12, color: primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────── REVIEW BOTTOM SHEET ─────────────────── */

class _ReviewBottomSheet extends StatefulWidget {
  final String orderId;
  final String productId;
  final String productName;

  const _ReviewBottomSheet({
    required this.orderId,
    required this.productId,
    required this.productName,
  });

  @override
  State<_ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<_ReviewBottomSheet> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('product_reviews').insert({
        'product_id': widget.productId,
        'order_id': widget.orderId,
        'user_id': userId,
        'rating': _rating,
        'review_text': _reviewController.text.trim().isEmpty
            ? null
            : _reviewController.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not submit review: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Rate ${widget.productName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              'Verified Purchase',
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
            const SizedBox(height: 20),

            // Star Rating Row
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 42,
                        color: i < _rating ? Colors.amber : Colors.grey[400],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _rating == 0
                    ? 'Tap a star to rate'
                    : [
                        '',
                        'Poor',
                        'Fair',
                        'Good',
                        'Very Good',
                        'Excellent',
                      ][_rating],
                style: TextStyle(
                  fontSize: 13,
                  color: _rating > 0 ? Colors.amber.shade800 : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Review Text
            TextField(
              controller: _reviewController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Write a review (optional)...',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
