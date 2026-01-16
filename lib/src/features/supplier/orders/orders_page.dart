import 'package:flutter/material.dart';
import 'package:med_shakthi/src/features/supplier/orders/orders_details_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String selectedStatus = "All";

  final List<String> statusList = [
    "All",
    "Pending",
    "Accepted",
    "Packed",
    "Dispatched",
    "Delivered",
    "Cancelled",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          "Orders",
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search order ID or pharmacy",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // 🏷 Status Filters
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: statusList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final status = statusList[index];
                final isSelected = selectedStatus == status;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedStatus = status;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4CA6A8)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // 📦 Orders List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: 6,
              itemBuilder: (context, index) {
                return _orderCard(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🧾 Order Card
  Widget _orderCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Order #ORD1023",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              _statusBadge("Pending"),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            "ABC Medicals",
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),

          const SizedBox(height: 6),

          const Text(
            "₹4,560 • 12 items",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 4),

          const Text(
            "Ordered on 08 Jan 2026",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsPage(),
                    ),
                  );
                },
                child: const Text(
                  "View Details",
                  style: TextStyle(
                    color: Color(0xFF4CA6A8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Accept order logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CA6A8),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: const Text("Accept"),
              ),
            ],
          )
        ],
      ),
    );
  }

  // 🟢 Status Badge
  Widget _statusBadge(String status) {
    Color color;

    switch (status) {
      case "Pending":
        color = Colors.orange;
        break;
      case "Delivered":
        color = Colors.green;
        break;
      case "Cancelled":
        color = Colors.red;
        break;
      default:
        color = const Color(0xFF4CA6A8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
