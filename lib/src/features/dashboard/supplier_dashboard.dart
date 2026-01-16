import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Added from teammate's code
import 'package:med_shakthi/src/features/supplier/inventory/ui/supplier_inventory_screen.dart';
import '../supplier/orders/orders_page.dart';
import '../profile/presentation/screens/supplier_profile_screen.dart';
import '../supplier/inventory/ui/add_product_page.dart';
import '../supplier/sales/sales_page.dart';


class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierProfileScreen()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage()));
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      // Kept the FAB for adding products as it's a key feature we built
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductPage()),
          );
        },
        backgroundColor: const Color(0xFF4CA6A8),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Product", style: TextStyle(color: Colors.white)),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildTopBar(), // Updated from teammate's code
              const SizedBox(height: 20),
              _buildPromoBanner(),
              const SizedBox(height: 30),
              _buildSectionHeader("Categories"), // Updated label
              const SizedBox(height: 15),
              _buildCategoryList(context), // Updated with Sales & Inventory
              const SizedBox(height: 30),
              _buildSectionHeader("Performance Stats"),
              const SizedBox(height: 15),
              _buildPerformanceGrid(context),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- UI Components ---

  // Updated TopBar from teammate's code (includes Cart Icon)
  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.grid_view_rounded, color: Colors.black54),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                hintText: "Search analytics...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        const Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.shopping_cart_outlined, color: Colors.black),
            ),
            Positioned(
              right: 0,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Color(0xFF4CA6A8),
                child: Text("3", style: TextStyle(fontSize: 10, color: Colors.white)),
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF63B4B7), Color(0xFF4CA6A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Supplier Growth",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Monthly payout is ready",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Action for report
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4CA6A8),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text("View Report"),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
        ),
        const Text(
          "See All",
          style: TextStyle(color: Color(0xFF4CA6A8), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // Merged Category List: Includes "Orders", "Sales", "Inventory" (from us), and "Payouts"
  Widget _buildCategoryList(BuildContext context) {
    final List<Map<String, dynamic>> cats = [
      {"icon": Icons.inventory_2, "label": "Orders"},
      {"icon": Icons.analytics, "label": "Sales"},
      {"icon": Icons.inventory, "label": "Inventory"}, // Our feature
      {"icon": Icons.account_balance_wallet, "label": "Payouts"},
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 25),
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              if (cats[index]['label'] == "Orders") {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage()));
              } else if (cats[index]['label'] == "Inventory") {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierInventoryScreen()));
              }
               else if (cats[index]['label'] == "Sales") {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesPage()));
              }
            },
            borderRadius: BorderRadius.circular(50),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cats[index]['icon'], color: const Color(0xFF4CA6A8)),
                ),
                const SizedBox(height: 8),
                Text(
                  cats[index]['label'],
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPerformanceGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 0.85,
      children: [
        _statItem("Revenue", "₹ 4.5L", "Supplements", "+12%"),
        _statItem("Pending", "14 Units", "Medicine", "Alert"),
      ],
    );
  }

  Widget _statItem(String title, String value, String sub, String badge) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.bar_chart, color: Colors.grey, size: 40),
            ),
          ),
          const SizedBox(height: 12),
          Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(color: Color(0xFF4CA6A8), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CA6A8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF4CA6A8), fontWeight: FontWeight.bold),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF4CA6A8),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Category"),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: "Wishlist"),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Order"),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
      ],
    );
  }
}