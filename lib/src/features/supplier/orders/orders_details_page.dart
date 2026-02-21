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

  @override
  void initState() {
    super.initState();
    fetchOrderDetails();
  }

  Future<void> fetchOrderDetails() async {
    try {
      // Use !inner on users to ensure we get order only if user exists,
      // or left join (default) is fine but we need to debug the response.
      // Explicitly selecting fields helps.
      final response = await supabase
          .from('orders')
          .select('''
            *,
            order_details (*),
            users:user_id (name, phone)
          ''')
          .eq('id', widget.orderId)
          .single();

      debugPrint("Order Details Response: $response");

      if (mounted) {
        setState(() {
          order = response;
          isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      debugPrint("Supabase error: ${e.message}");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading order: ${e.message}")),
        );
      }
    } catch (e) {
      debugPrint("Error fetching order details: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading order: $e")));
      }
    }
  }

  Future<void> updateOrderStatus(String newStatus) async {
    try {
      // Optimistic update
      setState(() {
        order!['status'] = newStatus;
      });

      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', widget.orderId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Order marked as $newStatus")));
        Navigator.pop(context, true); // Return true to refresh parent list
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
      // Revert optimistic update
      fetchOrderDetails();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error updating status: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Order Details")),
        body: const Center(child: Text("Order not found")),
      );
    }

    final createdAt = DateTime.parse(order!['created_at']);
    final formattedDate = DateFormat('dd MMM yyyy').format(createdAt);
    final status = order!['status'] ?? 'Unknown';
    final items = order!['order_details'] as List<dynamic>;

    // Fetch buyer details from the joined 'users' table
    final userData = order!['users'] as Map<String, dynamic>?;
    final address = order!['shipping_address'] ?? 'Address not available';
    final buyerName = userData?['name'] ?? 'Unknown Buyer';
    final phone = userData?['phone'] ?? 'Phone not available';

    return Scaffold(
      appBar: AppBar(title: const Text("Order Details"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... inside build method
            // Shipping Address Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Merging Buyer Details into Address Card for context
                  if (buyerName != 'Unknown Buyer') ...[
                    Text(
                      buyerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (phone != 'Phone not available')
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    address,
                    style: TextStyle(color: Colors.grey.shade800, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 💬 Chat Action (Preserved)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (order != null && order!['user_id'] != null) {
                    try {
                      final currentUser =
                          Supabase.instance.client.auth.currentUser;
                      if (currentUser == null) return;

                      final supplierRes = await Supabase.instance.client
                          .from('suppliers')
                          .select('id')
                          .eq('user_id', currentUser.id)
                          .maybeSingle();

                      if (supplierRes == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Supplier profile not found'),
                            ),
                          );
                        }
                        return;
                      }

                      final String currentSupplierId = supplierRes['id'];

                      final chatId = await ChatService().getOrCreateChat(
                        orderId: widget.orderId,
                        supplierId: currentSupplierId,
                        userId: order!['user_id'],
                      );

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UnifiedChatScreen(
                              chatId: chatId,
                              otherUserName: buyerName,
                              otherUserId: order!['user_id'],
                              otherUserImage: null,
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
                        content: Text('Customer info not available'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.chat),
                label: const Text('Chat with Customer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📦 Order Summary
            _sectionTitle("Order Summary"),
            _infoRow(
              "Order ID",
              order!['order_number'] ?? widget.orderId.substring(0, 8),
            ),
            _infoRow("Order Date", formattedDate),
            _infoRow("Status", status),
            _infoRow("Payment", "Credit (30 Days)"),
            const SizedBox(height: 20),

            // Removed "Pharmacy Details" section as requested

            // 💊 Items Ordered
            _sectionTitle("Items Ordered"),
            ...items.map((item) {
              // Now using the Rich Item Card
              return _buildItemCard(context, item);
            }),
            const SizedBox(height: 20),

            // 💰 Billing Summary
            _sectionTitle("Billing Summary"),
            Builder(
              builder: (context) {
                // Compute items subtotal from order_details list
                final itemsList =
                    order!['order_details'] as List<dynamic>? ?? [];
                final itemsSubtotal = itemsList.fold<double>(
                  0,
                  (sum, item) =>
                      sum +
                      ((item['price'] as num? ?? 0) *
                          (item['quantity'] as num? ?? 0)),
                );
                final shippingFee =
                    (order!['shipping'] as num?)?.toDouble() ?? 0.0;
                final grandTotal =
                    (order!['total_amount'] as num?)?.toDouble() ?? 0.0;
                return Column(
                  children: [
                    _infoRow(
                      "Items Subtotal",
                      "₹${itemsSubtotal.toStringAsFixed(2)}",
                    ),
                    _infoRow(
                      "Shipping & Handling",
                      shippingFee > 0
                          ? "₹${shippingFee.toStringAsFixed(2)}"
                          : "Free",
                    ),
                    const Divider(height: 20),
                    _infoRow(
                      "Grand Total",
                      "₹${grandTotal.toStringAsFixed(2)}",
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),

            // 🚚 Actions
            if (status == 'Pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () => updateOrderStatus('Cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Reject'),
                  ),
                  ElevatedButton(
                    onPressed: () => updateOrderStatus('Confirmed'),
                    child: const Text('Accept Order'),
                  ),
                ],
              )
            else if (status == 'Confirmed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => updateOrderStatus('Shipped'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: const Text('Mark as Shipped'),
                ),
              )
            else if (status == 'Shipped')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => updateOrderStatus('Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Mark as Delivered'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Widgets ----------

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item) {
    // Extract product data from the joined 'products' table
    final product = item['products'] as Map<String, dynamic>? ?? {};
    final imageUrl = product['image_url'];
    final category = product['category'] ?? 'Medicine';

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
                imageUrl: imageUrl,
                category: category,
                fit: BoxFit.cover,
                width: 60,
                height: 60,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['item_name'] ?? 'Unknown Product',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item['brand'] ?? 'N/A', // Using brand as subtext
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Qty: ${item['quantity']} | Unit: ${item['unit_size'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${item['price']}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
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
