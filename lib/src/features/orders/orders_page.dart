import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_detail_screen.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final supabase = Supabase.instance.client;

  String selectedStatus = "All";
  String searchText = "";

  bool _loading = false;
  List<Map<String, dynamic>> _orders = [];

  final List<String> statusList = [
    "All",
    "Pending",
    "Accepted",
    "Dispatched",
    "Delivered",
    "Cancelled",
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _orders = [];
      });
      return;
    }

    setState(() => _loading = true);

    try {
      // ✅ Fetch user orders with Supplier details (latest first)
      final res = await supabase
          .from('orders')
          .select('*, suppliers(company_name)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
        res,
      );

      setState(() {
        _orders = list;
      });
    } catch (e) {
      debugPrint("Fetch orders error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(" Failed to fetch orders: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Group orders by order_group_id
  List<List<Map<String, dynamic>>> get _groupedOrders {
    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (var order in _orders) {
      // Status filter
      if (selectedStatus != "All") {
        final statusDb = (order["status"] ?? "").toString().toLowerCase();
        if (statusDb != selectedStatus.toLowerCase()) continue;
      }

      // Search filter
      if (searchText.trim().isNotEmpty) {
        final q = searchText.toLowerCase();
        final orderId = (order["order_group_id"] ?? "")
            .toString()
            .toLowerCase();
        final itemName = (order["item_name"] ?? "").toString().toLowerCase();
        // Check supplier name if available
        final supplier = order['suppliers'] as Map<String, dynamic>?;
        final supplierName = (supplier?['company_name'] ?? "")
            .toString()
            .toLowerCase();

        if (!orderId.contains(q) &&
            !itemName.contains(q) &&
            !supplierName.contains(q)) {
          continue;
        }
      }

      final groupId = (order["order_group_id"] ?? "unknown").toString();
      groups.putIfAbsent(groupId, () => []).add(order);
    }

    // Sort groups by the created_at of the first item (should be latest due to fetch order)
    final sortedGroups = groups.values.toList();
    // Assuming the fetch order handled the primary sort, but re-sorting by 'latest in group' is safer
    sortedGroups.sort((a, b) {
      final aDate = DateTime.parse(a.first['created_at']);
      final bDate = DateTime.parse(b.first['created_at']);
      return bDate.compareTo(aDate);
    });

    return sortedGroups;
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return "";
    final dt = DateTime.tryParse(createdAt.toString());
    if (dt == null) return "";
    return "${dt.day.toString().padLeft(2, "0")}-${dt.month.toString().padLeft(2, "0")}-${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final groupedOrders = _groupedOrders;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders"),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _fetchOrders, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) {
                setState(() => searchText = v);
              },
              decoration: InputDecoration(
                hintText: "Search ID, Item, or Supplier",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // 🏷 Status Filters
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: statusList.length,
              itemBuilder: (context, index) {
                final status = statusList[index];
                final isSelected = selectedStatus == status;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => selectedStatus = status);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // ✅ Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : groupedOrders.isEmpty
                ? const Center(child: Text("No orders found."))
                : ListView.builder(
                    itemCount: groupedOrders.length,
                    itemBuilder: (context, index) {
                      return _orderGroupCard(groupedOrders[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ✅ Grouped Order Card
  Widget _orderGroupCard(List<Map<String, dynamic>> group) {
    if (group.isEmpty) return const SizedBox.shrink();

    // Common details from the first order in the group
    final firstOrder = group.first;
    final orderGroupId = (firstOrder["order_group_id"] ?? "").toString();
    final date = _formatDate(firstOrder["created_at"]);

    // Calculate total for the ENTIRE group
    double groupTotal = 0;
    for (var o in group) {
      groupTotal += (o['total_amount'] ?? 0);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Group ID and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  firstOrder["order_number"]?.toString() ??
                      "Order #${orderGroupId.isEmpty ? "N/A" : "ORD-${orderGroupId.substring(0, 8).toUpperCase()}"}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Total: ₹${groupTotal.toStringAsFixed(2)}",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.teal,
              ),
            ),

            const Divider(),

            // List of Shipments (Sub-orders)
            ...group.map((order) {
              final status = (order["status"] ?? "pending").toString();
              // Try to get supplier name
              final supplier = order['suppliers'] as Map<String, dynamic>?;
              final supplierName =
                  supplier?['company_name'] ?? "Unknown Supplier";
              final total = (order['total_amount'] ?? 0).toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Shipment from $supplierName",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Amount: ₹$total",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(status),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 14),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(orderData: order),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ✅ Status Badge
  Widget _statusBadge(String status) {
    final s = status.toLowerCase();
    Color color;

    switch (s) {
      case "pending":
        color = Colors.orange;
        break;
      case "accepted":
      case "confirmed":
        color = Colors.blue;
        break;
      case "dispatched":
      case "shipped":
        color = Colors.purple;
        break;
      case "delivered":
      case "completed":
        color = Colors.green;
        break;
      case "cancelled":
      case "rejected":
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(), // Display in caps for better visibility
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
