import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'order_detail_screen.dart';


// --- DATA MODEL ---
class OrderItem {
  final String id;
  final String title;
  final String brand;
  final String size;
  final double price;
  final String imagePath;
  final int quantity;
  final String
  status; // 'orderaccepted', 'packagingandshipping', 'in transit', 'packageDelivered'
  final String orderDate;
  final String deliveryLocation;
  final String paymentMode;

  OrderItem({
    required this.id,
    required this.title,
    required this.brand,
    required this.size,
    required this.price,
    required this.imagePath,
    required this.quantity,
    required this.status,
    required this.orderDate,
    required this.deliveryLocation,
    required this.paymentMode,
  });
}

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  // Theme color
  final Color themeColor = const Color(0xFF4C8077);
  final Color backgroundColor = const Color(0xFFF5F7F9);

  // Fake Data
  final List<OrderItem> _orders = [
    OrderItem(
      id: '1',
      title: 'Dietary Antioxidant Protection',
      brand: 'SAN Pharma',
      size: '120 count',
      price: 18.99,
      imagePath: 'assets/images/cart_image_1.jpg',
      quantity: 1,
      status: 'orderaccepted',
      orderDate: '2024-01-10',
      deliveryLocation: '123 Main St, City, State',
      paymentMode: 'Credit Card',
    ),
    OrderItem(
      id: '2',
      title: 'Milk Thistle Liver Care',
      brand: 'Bronson Pharma',
      size: '60 count',
      price: 15.99,
      imagePath: 'assets/images/milk_thistle.png',
      quantity: 2,
      status: 'packagingandshipping',
      orderDate: '2024-01-08',
      deliveryLocation: '456 Elm St, City, State',
      paymentMode: 'PayPal',
    ),
    OrderItem(
      id: '3',
      title: 'Vitamin D3 Supplement',
      brand: 'Nature Made',
      size: '100 count',
      price: 12.99,
      imagePath: 'assets/images/vitamin_d3.png',
      quantity: 1,
      status: 'in transit',
      orderDate: '2024-01-05',
      deliveryLocation: '789 Oak St, City, State',
      paymentMode: 'Cash on Delivery',
    ),
    OrderItem(
      id: '4',
      title: 'Omega 3 Fish Oil',
      brand: 'Kirkland',
      size: '200 count',
      price: 22.99,
      imagePath: 'assets/images/omega3.png',
      quantity: 1,
      status: 'packageDelivered',
      orderDate: '2024-01-01',
      deliveryLocation: '321 Pine St, City, State',
      paymentMode: 'Debit Card',
    ),
  ];

  String _getStatusText(String status) {
    switch (status) {
      case 'orderaccepted':
        return 'Order Accepted';
      case 'packagingandshipping':
        return 'Packaging & Shipping';
      case 'in transit':
        return 'In Transit';
      case 'packageDelivered':
        return 'Package Delivered';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'orderaccepted':
        return Colors.orange;
      case 'packagingandshipping':
        return Colors.blue;
      case 'in transit':
        return Colors.purple;
      case 'packageDelivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _orders.isEmpty ? _buildEmptyState() : _buildOrdersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your order history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailScreen(order: order),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        order.imagePath,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.brand,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${order.size} x ${order.quantity}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(order.status),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(order.status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Ordered on ${order.orderDate}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    // Chat button
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: Color(0xFF4C8077), size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              supplier: SupplierProfile(
                                id: 'supplier_${order.id}',
                                name: order.brand,
                                profileImage: '',
                                phone: '+91 9876543210',
                                email:
                                '${order.brand.toLowerCase()}@medstore.com',
                                isOnline: true,
                              ),
                            ),
                          ),
                        );
                      },
                      tooltip: 'Chat with Supplier',
                    ),
                    // Call button
                    IconButton(
                      icon: const Icon(Icons.call_outlined,
                          color: Color(0xFF4C8077), size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Calling supplier...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Call Supplier',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Reorder logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Reordered successfully!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Reorder'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
