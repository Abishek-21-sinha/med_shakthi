import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';

// Internal Imports
import '../profile/presentation/screens/supplier_category_page.dart';
import '../profile/presentation/screens/supplier_payout_page.dart';
import '../banners/screens/manage_banners_screen.dart';
import '../profile/presentation/screens/supplier_profile_screen.dart';
import '../supplier/inventory/ui/add_product_page.dart';
import '../supplier/orders/supplier_orders_page.dart';
import '../supplier/sales/sales_analytics_page.dart';
import '../../core/theme/theme_provider.dart';
import '../supplier/inventory/ui/my_products_page.dart';
import '../supplier/sales/sales_stats_service.dart';

// -----------------------------------------------------------------------------
// MAIN DASHBOARD SCREEN
// -----------------------------------------------------------------------------

class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});
  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncOneSignalId();
  }

  Future<void> _syncOneSignalId() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId != null && playerId.isNotEmpty) {
        await Supabase.instance.client
            .from('suppliers')
            .update({'onesignal_player_id': playerId})
            .eq('user_id', user.id);
        debugPrint(
          "Successfully synced OneSignal Player ID on dashboard load.",
        );
      }
    } catch (e) {
      debugPrint("Failed to sync OneSignal ID: $e");
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddProductPage()),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  late final List<Widget> _pages = [
    SupplierDashboardHome(),
    const SupplierCategoryPage(),
    const SizedBox(), // Placeholder for Add Product (handled by onTap)
    const SupplierOrdersPage(),
    const MyProductsPage(),
  ];

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black54,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CA6A8), Color(0xFF2E8B8E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CA6A8).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Close Supplier Panel?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your orders and inventory will keep\nrunning in the background.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF4CA6A8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Stay',
                            style: TextStyle(
                              color: Color(0xFF4CA6A8),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF4CA6A8),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Exit',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // If not on home tab, navigate back to home first
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }
        final shouldExit = await _showExitDialog(context);
        if (shouldExit && mounted) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: IndexedStack(index: _selectedIndex, children: _pages),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    const activeColor = Color(0xFF4CA6A8);

    final navItems = [
      {'icon': Icons.home_filled, 'label': 'Home'},
      {'icon': Icons.grid_view, 'label': 'Category'},
      {'icon': Icons.add, 'label': 'Add'},
      {'icon': Icons.receipt_long, 'label': 'Order'},
      {'icon': Icons.inventory_2_outlined, 'label': 'Products'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              return _buildNavItem(
                item['icon'] as IconData,
                item['label'] as String,
                index,
                activeColor,
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    Color activeColor,
  ) {
    final isSelected = _selectedIndex == index;

    if (index == 2) {
      // THE ADD BUTTON (FAB STYLE)
      return GestureDetector(
        onTap: () => _onItemTapped(index),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: activeColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 26),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HOME SCREEN WITH ANIMATIONS & STATE
// -----------------------------------------------------------------------------

class SupplierDashboardHome extends StatefulWidget {
  const SupplierDashboardHome({super.key});

  @override
  State<SupplierDashboardHome> createState() => _SupplierDashboardHomeState();
}

class _SupplierDashboardHomeState extends State<SupplierDashboardHome> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic>? _data;

  // Mock Categories loading
  List<Map<String, dynamic>> _categories = [];
  bool _isCategoriesLoading = true;

  Timer? _refreshTimer;
  final SalesStatsService _statsService = SalesStatsService();
  StreamSubscription? _statsSubscription;
  String? _supplierCode;
  String? _supplierId;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    // ⏲️ Set up a periodic refresh for backup (in case real-time fails)
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadAllData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statsSubscription?.cancel();
    _statsService.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    // Only show full loading spinner for the first load
    if (_data == null) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }
    }

    try {
      // Parallel fetching
      final statsFuture = _statsService.fetchSalesStats();
      final categoryFuture = _fetchCategories();

      final results = await Future.wait([statsFuture, categoryFuture]);

      if (mounted) {
        setState(() {
          _data = results[0] as Map<String, dynamic>;
          _isLoading = false;
        });

        // Set up real-time subscription after first load
        if (_statsSubscription == null && _data != null) {
          await _setupRealtimeSubscription();
        }
      }
    } catch (e) {
      if (mounted && _data == null) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Set up real-time subscription to database changes
  Future<void> _setupRealtimeSubscription() async {
    try {
      // Get supplier info from Supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final supplierData = await Supabase.instance.client
          .from('suppliers')
          .select('supplier_code, id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (supplierData != null) {
        _supplierCode = supplierData['supplier_code'];
        _supplierId = supplierData['id'];

        // Subscribe to real-time updates
        await _statsService.subscribeToRealtimeUpdates(
          _supplierCode!,
          _supplierId!,
        );

        // Listen to the stats stream
        _statsSubscription = _statsService.statsStream.listen((newStats) {
          if (mounted) {
            setState(() {
              _data = newStats;
            });

            // Show a subtle notification that data updated
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Dashboard updated with latest data'),
                  ],
                ),
                backgroundColor: const Color(0xFF4CA6A8),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        });

        // Real-time dashboard updates enabled
      }
    } catch (e) {
      // Error setting up real-time subscription
    }
  }

  Future<void> _fetchCategories() async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _categories = [
          {
            'icon': Icons.inventory,
            'name': 'Inventory',
            'page': const MyProductsPage(),
            'color': Colors.blue,
          },
          {
            'icon': Icons.shopping_bag,
            'name': 'Orders',
            'page': const SupplierOrdersPage(),
            'color': Colors.orange,
          },
          {
            'icon': Icons.analytics,
            'name': 'Analytics',
            'page': const SalesAnalyticsPage(),
            'color': Colors.purple,
          },
          {
            'icon': Icons.campaign,
            'name': 'Banners',
            'page': const ManageBannersScreen(),
            'color': Colors.red,
          },
          {
            'icon': Icons.account_balance_wallet,
            'name': 'Payouts',
            'page': const SupplierPayoutPage(),
            'color': Colors.green,
          },
        ];
        _isCategoriesLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If error, show retry
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text("Failed to load dashboard data"),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAllData, child: const Text("Retry")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: const Color(0xFF4CA6A8),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildTopBar(context),
            const SizedBox(height: 20),
            _buildPromoBanner(context),
            const SizedBox(height: 30),
            _buildSectionHeader(context, "Categories"),
            const SizedBox(height: 15),
            _buildCategoryList(context),
            const SizedBox(height: 30),
            _buildSectionHeader(context, "Performance Stats"),
            const SizedBox(height: 15),
            _buildPerformanceGrid(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupplierProfileScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.person_outline,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
        ),
        const SizedBox(width: 15),
        const Spacer(),
        const SizedBox(width: 15),
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return GestureDetector(
              onTap: () {
                themeProvider.toggleTheme();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPromoBanner(BuildContext context) {
    if (_isLoading) {
      return ShimmerWidget.rectangular(height: 180, borderRadius: 30);
    }

    final double growth = _data?['growth'] ?? 0.0;
    final double revenue = (_data?['totalRevenue'] as num?)?.toDouble() ?? 0.0;

    // Determine growth color
    Color growthColor = Colors.white;
    IconData growthIcon = Icons.trending_flat;

    if (growth > 0) {
      growthColor = Colors.greenAccent;
      growthIcon = Icons.trending_up;
    } else if (growth < 0) {
      growthColor = const Color(
        0xFFFF8A80,
      ); // Lighter red (RedAccent.100 equivalent) for better contrast on teal
      growthIcon = Icons.trending_down;
    }

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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CA6A8).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Supplier Growth",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(growthIcon, color: growthColor, size: 16),
                    const SizedBox(width: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: growth),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, child) {
                        return Text(
                          "${val > 0 ? '+' : ''}${val.toStringAsFixed(1)}%",
                          style: TextStyle(
                            color: growthColor,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Total Revenue",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          // Animated Revenue
          AnimatedCurrencyCounter(
            value: revenue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesAnalyticsPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4CA6A8),
              shape: const StadiumBorder(),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              "View Report",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        InkWell(
          onTap: () {}, // Optional: Navigate to a full list page
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "See All",
              style: TextStyle(
                color: Color(0xFF4CA6A8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(BuildContext context) {
    if (_isCategoriesLoading) {
      return SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 25),
          itemBuilder: (context, index) =>
              const ShimmerWidget.circular(size: 70),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return FadeInAnimation(
            delay: index * 100, // Staggered animation
            child: _CategoryItem(
              icon: cat['icon'],
              label: cat['name'],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => cat['page']),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPerformanceGrid(BuildContext context) {
    if (_isLoading) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.85,
        children: const [
          ShimmerWidget.rectangular(height: 150),
          ShimmerWidget.rectangular(height: 150),
          ShimmerWidget.rectangular(height: 150),
          ShimmerWidget.rectangular(height: 150),
        ],
      );
    }

    // Extract all metrics from data
    final thisMonthRevenue =
        (_data?['thisMonthRevenue'] as num?)?.toDouble() ?? 0.0;
    final growth = (_data?['growth'] as num?)?.toDouble() ?? 0.0;
    final pendingOrders = (_data?['pendingOrders'] as num?)?.toInt() ?? 0;
    final deliveredOrders = (_data?['deliveredOrders'] as num?)?.toInt() ?? 0;
    final totalOrdersCount = (_data?['totalOrders'] as num?)?.toInt() ?? 0;
    final totalClients = (_data?['totalClients'] as num?)?.toInt() ?? 0;
    final avgOrderValue = (_data?['avgOrderValue'] as num?)?.toDouble() ?? 0.0;
    final totalProducts = (_data?['totalProducts'] as num?)?.toInt() ?? 0;
    final lowStockCount = (_data?['lowStockCount'] as num?)?.toInt() ?? 0;
    final outOfStockCount = (_data?['outOfStockCount'] as num?)?.toInt() ?? 0;

    // Calculate fulfillment rate
    final fulfillmentRate = totalOrdersCount > 0
        ? ((deliveredOrders / totalOrdersCount) * 100).toStringAsFixed(0)
        : "0";

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 0.85,
      children: [
        // Revenue Card
        _StatCard(
          title: "Revenue",

          valueWidget: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : AnimatedCurrencyCounter(
                  value: thisMonthRevenue,
                  style: const TextStyle(
                    color: Color(0xFF4CA6A8),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  compact: true,
                ),
          subtitle: "This Month",
          badge: "${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%",
          icon: Icons.currency_rupee,
          isAlert: false,
        ),
        // Pending Orders Card
        _StatCard(
          title: "Pending",
          valueWidget: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  "$pendingOrders Orders",
                  style: const TextStyle(
                    color: Color(0xFF4CA6A8),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
          subtitle: "To Process",
          badge: pendingOrders > 0 ? "Action Needed" : "All Good",
          icon: Icons.schedule,
          isAlert: pendingOrders > 0,
        ),

        // Inventory Alert Card
        _StatCard(
          title: "Inventory",
          valueWidget: Text(
            "$totalProducts Items",
            style: const TextStyle(
              color: Color(0xFF4CA6A8),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: "Total Products",
          badge: lowStockCount > 0 || outOfStockCount > 0
              ? "${lowStockCount + outOfStockCount} Low Stock"
              : "Stock OK",
          icon: Icons.inventory_2,
          isAlert: lowStockCount > 0 || outOfStockCount > 0,
        ),

        // Customers Card
        _StatCard(
          title: "Customers",
          valueWidget: _isLoading
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Text(
                  "$totalClients Clients",
                  style: const TextStyle(
                    color: Color(0xFF4CA6A8),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
          subtitle: "Active Buyers",
          badge: totalClients > 0 ? "Connected" : "No Customers",
          icon: Icons.people,
          isAlert: false,
        ),

        // Order Fulfillment Card
        _StatCard(
          title: "Fulfillment",
          valueWidget: Text(
            "$fulfillmentRate%",
            style: const TextStyle(
              color: Color(0xFF4CA6A8),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: "Delivery Rate",
          badge: "$deliveredOrders Delivered",
          icon: Icons.local_shipping,
          isAlert: false,
        ),

        // Average Order Value Card
        _StatCard(
          title: "Avg Order",
          valueWidget: Text(
            "${avgOrderValue.toInt()} Orders",
            style: const TextStyle(
              color: Color(0xFF4CA6A8),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: "Per Transaction",
          badge: totalOrdersCount > 0 ? "$totalOrdersCount Total" : "No Data",
          icon: Icons.receipt_long,
          isAlert: false,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
// -----------------------------------------------------------------------------

class _CategoryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF4CA6A8), size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Widget valueWidget;
  final String subtitle;
  final String badge;
  final IconData icon;
  final bool isAlert;

  const _StatCard({
    required this.title,
    required this.valueWidget,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.isAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.grey, size: 24),
              ),
              if (isAlert)
                TwinklingAlertBadge(label: badge)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CA6A8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF4CA6A8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const Spacer(),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          valueWidget,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ANIMATION WIDGETS
// -----------------------------------------------------------------------------

class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final ShapeBorder shape;

  const ShimmerWidget.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
    double borderRadius = 15,
  }) : shape = const RoundedRectangleBorder(
         borderRadius: BorderRadius.all(Radius.circular(15)),
       );

  const ShimmerWidget.circular({super.key, required double size})
    : width = size,
      height = size,
      shape = const CircleBorder();

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shape,
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}

class AnimatedCurrencyCounter extends StatelessWidget {
  final double value;
  final TextStyle style;
  final bool compact;

  const AnimatedCurrencyCounter({
    super.key,
    required this.value,
    required this.style,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutExpo,
      builder: (context, val, child) {
        final formatter = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: val >= 1000 ? 0 : 2,
        );
        return Text(formatter.format(val), style: style);
      },
    );
  }
}

class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final int delay;

  const FadeInAnimation({super.key, required this.child, this.delay = 0});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class TwinklingAlertBadge extends StatefulWidget {
  final String label;
  const TwinklingAlertBadge({super.key, required this.label});

  @override
  State<TwinklingAlertBadge> createState() => _TwinklingAlertBadgeState();
}

class _TwinklingAlertBadgeState extends State<TwinklingAlertBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _colorAnimation = ColorTween(
      begin: Colors.red.withValues(alpha: 0.1),
      end: Colors.red.withValues(alpha: 0.4),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
