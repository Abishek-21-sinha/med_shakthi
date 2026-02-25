import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class SalesStatsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream controller for real-time updates
  final _statsController = StreamController<Map<String, dynamic>>.broadcast();

  // Subscription references
  RealtimeChannel? _ordersSubscription;
  RealtimeChannel? _productsSubscription;
  RealtimeChannel? _inventorySubscription;

  /// Stream of real-time stats updates
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  /// Subscribe to real-time database changes
  Future<void> subscribeToRealtimeUpdates(
    String supplierCode,
    String supplierId,
  ) async {
    try {
      // Subscribe to order_details table changes (which accurately tracks supplier orders)
      _ordersSubscription = _supabase
          .channel('order_details_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'order_details',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'supplier_id',
              value: supplierId,
            ),
            callback: (payload) async {
              // Order detail change detected
              // Fetch fresh stats and emit to stream
              final stats = await fetchSalesStats();
              _statsController.add(stats);
            },
          )
          .subscribe();

      // Subscribe to products table changes
      _productsSubscription = _supabase
          .channel('products_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'supplier_code',
              value: supplierCode,
            ),
            callback: (payload) async {
              // Product change detected
              final stats = await fetchSalesStats();
              _statsController.add(stats);
            },
          )
          .subscribe();

      // Subscribe to inventory table changes
      _inventorySubscription = _supabase
          .channel('inventory_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'inventory',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'supplier_id',
              value: supplierId,
            ),
            callback: (payload) async {
              // Inventory change detected
              final stats = await fetchSalesStats();
              _statsController.add(stats);
            },
          )
          .subscribe();

      // Real-time subscriptions active
    } catch (e) {
      // Error subscribing to real-time updates
    }
  }

  /// Unsubscribe from real-time updates
  Future<void> unsubscribe() async {
    await _ordersSubscription?.unsubscribe();
    await _productsSubscription?.unsubscribe();
    await _inventorySubscription?.unsubscribe();
    // Unsubscribed from real-time updates
  }

  /// Dispose resources
  void dispose() {
    _statsController.close();
    unsubscribe();
  }

  /// Fetch sales statistics for the supplier
  Future<Map<String, dynamic>> fetchSalesStats({
    String dateRange = 'Month',
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? category, // null = All categories
    String? paymentStatus, // null = All payment statuses
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        // No user logged in
        return _getEmptyStats();
      }

      // 1. Get Supplier Information
      final supplierData = await _supabase
          .from('suppliers')
          .select('supplier_code, id, name')
          .eq('user_id', user.id)
          .maybeSingle();

      if (supplierData == null) {
        // Supplier not found
        return _getEmptyStats();
      }

      final String? supplierCode = supplierData['supplier_code'];
      final String? supplierId = supplierData['id'];

      if (supplierCode == null || supplierCode.isEmpty) {
        // Supplier code is null or empty
        return _getEmptyStats();
      }

      if (supplierId == null || supplierId.isEmpty) {
        // Supplier ID is null or empty
        return _getEmptyStats();
      }

      // Fetching stats for supplier

      // 2. Define Date Ranges
      final now = DateTime.now();
      final firstDayThisMonth = DateTime(now.year, now.month, 1);
      final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
      final today = DateTime(now.year, now.month, now.day);

      // 3. Fetch Products Count and Inventory
      final productsResponse = await _supabase
          .from('products')
          .select('id, name, price, image_url, category')
          .eq('supplier_code', supplierCode);

      final List<dynamic> productsList = productsResponse as List<dynamic>;
      final int totalProducts = productsList.length;

      // 4. Fetch Inventory Data
      final inventoryResponse = await _supabase
          .from('inventory')
          .select('product_id, stock_quantity')
          .eq('supplier_id', supplierId);

      final List<dynamic> inventoryList = inventoryResponse as List<dynamic>;
      int lowStockCount = 0;
      int outOfStockCount = 0;
      int totalStock = 0;

      for (var inv in inventoryList) {
        final int stock = (inv['stock_quantity'] as num?)?.toInt() ?? 0;
        totalStock += stock;
        if (stock == 0) {
          outOfStockCount++;
        } else if (stock < 10) {
          lowStockCount++;
        }
      }

      // 5. Fetch Orders Data correctly using order_details inner joined with orders
      final orderDetailsResponse = await _supabase
          .from('order_details')
          .select('''
            id,
            product_id,
            quantity,
            price,
            created_at,
            orders!inner(
              id,
              user_id,
              status,
              payment_status,
              created_at
            )
          ''')
          .eq('supplier_id', supplierId);

      final List<dynamic> orderDetailsList =
          orderDetailsResponse as List<dynamic>;

      double totalRevenue = 0;
      double thisMonthRevenue = 0;
      double lastMonthRevenue = 0;
      double todayRevenue = 0;

      final Set<String> uniqueOrders = {};
      final Set<String> uniqueOrdersThisMonth = {};
      final Map<String, String> orderStatuses = {};
      final Set<String> uniqueClients = {};
      final Map<String, int> productSales = {};

      // Analytics data structures
      final Map<String, double> categoryPerformance = {};
      final List<Map<String, dynamic>> recentTransactions = [];

      DateTime startDate = DateTime(2000); // Default to all time
      DateTime endDate = now;
      int trendDays = 7;

      switch (dateRange) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          trendDays = 7; // Show 7 days trend even for today
          break;
        case 'Week':
          startDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 7));
          trendDays = 7;
          break;
        case 'Month':
          startDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 30));
          trendDays = 30;
          break;
        case 'Custom':
          if (customStartDate != null && customEndDate != null) {
            startDate = customStartDate;
            endDate = customEndDate;
            trendDays = endDate.difference(startDate).inDays + 1;
            if (trendDays <= 0) trendDays = 1;
          } else {
            startDate = DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(const Duration(days: 30));
            trendDays = 30; // Just default to 30 days for now
          }
          break;
      }

      // Initialize sales trend buckets
      List<Map<String, dynamic>> salesTrend = [];
      for (int i = trendDays - 1; i >= 0; i--) {
        DateTime d = endDate.subtract(Duration(days: i));
        salesTrend.add({
          'label': trendDays > 7
              ? '${d.day}/${d.month}'
              : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday -
                    1],
          'value': 0.0,
          'date': DateTime(d.year, d.month, d.day),
        });
      }

      // ── Date range filter helper ────────────────────────────────────────────
      bool inRange(DateTime dt) {
        final d = DateTime(dt.year, dt.month, dt.day);
        final s = DateTime(startDate.year, startDate.month, startDate.day);
        final e = DateTime(endDate.year, endDate.month, endDate.day);
        return !d.isBefore(s) && !d.isAfter(e);
      }

      for (var item in orderDetailsList) {
        final Map<String, dynamic> order =
            item['orders'] as Map<String, dynamic>;

        final double amount =
            ((item['price'] as num?)?.toDouble() ?? 0.0) *
            ((item['quantity'] as num?)?.toInt() ?? 0);

        final String orderId = order['id'] ?? '';
        final String status = (order['status'] ?? 'pending')
            .toString()
            .toLowerCase();
        final DateTime orderCreatedAt = DateTime.parse(order['created_at']);
        final String userId = order['user_id'] ?? '';
        final String productId = item['product_id'] ?? '';

        // ── Skip items outside the selected date range for all aggregations ──
        if (!inRange(orderCreatedAt)) continue;

        if (orderId.isNotEmpty) {
          uniqueOrders.add(orderId);
          orderStatuses[orderId] = status;
          if (orderCreatedAt.isAfter(firstDayThisMonth)) {
            uniqueOrdersThisMonth.add(orderId);
          }
        }

        // Customers: count unique customers with an active order
        if (userId.isNotEmpty &&
            ['pending', 'confirmed', 'shipped', 'cancelled'].contains(status)) {
          uniqueClients.add(userId);
        }

        // Find product info for Category Performance and Recent Transactions
        Map<String, dynamic>? productInfo;
        if (productId.isNotEmpty) {
          productSales[productId] = (productSales[productId] ?? 0) + 1;
          for (var p in productsList) {
            if (p['id'] == productId) {
              productInfo = p as Map<String, dynamic>;
              break;
            }
          }
        }

        // Recent Transactions (apply paymentStatus filter if set)
        final txPaymentStatus = (order['payment_status'] ?? 'Pending')
            .toString();
        final matchesPayment =
            paymentStatus == null ||
            txPaymentStatus.toLowerCase() == paymentStatus.toLowerCase();
        if (matchesPayment) {
          recentTransactions.add({
            'id':
                '#ORD-${orderId.length >= 5 ? orderId.substring(0, 5).toUpperCase() : orderId.toUpperCase()}',
            'medicine': productInfo?['name'] ?? 'Unknown Product',
            'qty': item['quantity'].toString(),
            'amount': '₹${amount.toStringAsFixed(0)}',
            'status': txPaymentStatus,
            'date':
                '${orderCreatedAt.day.toString().padLeft(2, '0')} ${_getMonthAbbr(orderCreatedAt.month)} ${orderCreatedAt.year}',
          });
        }

        // Revenue: only count delivered orders
        if (status == 'delivered') {
          // Time-agnostic metrics for comparison periods
          if (orderCreatedAt.isAfter(today)) todayRevenue += amount;
          if (orderCreatedAt.isAfter(firstDayThisMonth)) {
            thisMonthRevenue += amount;
          } else if (orderCreatedAt.isAfter(firstDayLastMonth) &&
              orderCreatedAt.isBefore(firstDayThisMonth)) {
            lastMonthRevenue += amount;
          }

          totalRevenue += amount;

          // Sales trend bucket
          final Duration diff =
              DateTime(endDate.year, endDate.month, endDate.day).difference(
                DateTime(
                  orderCreatedAt.year,
                  orderCreatedAt.month,
                  orderCreatedAt.day,
                ),
              );
          int daysAgo = diff.inDays;
          if (daysAgo >= 0 && daysAgo < trendDays) {
            int idx = trendDays - 1 - daysAgo;
            if (idx >= 0 && idx < trendDays) {
              salesTrend[idx]['value'] =
                  (salesTrend[idx]['value'] as double) + amount;
            }
          }

          // Category Performance (apply category filter if set)
          final String itemCategory = productInfo?['category'] ?? 'Others';
          final matchesCategory =
              category == null ||
              itemCategory.toLowerCase() == category.toLowerCase();
          if (matchesCategory) {
            categoryPerformance[itemCategory] =
                (categoryPerformance[itemCategory] ?? 0) + amount;
          }
        }
      }

      // Sort recent transactions by date (newest first)
      // Recent transactions are already in order of orderDetailsList (which is likely order of insertion/date if fetched without explicit order, but good enough for now).
      // We will reverse and take the latest 10 when putting into the return map.

      int pendingOrders = 0;
      int confirmedOrders = 0;
      int shippedOrders = 0;
      int deliveredOrders = 0;

      for (var status in orderStatuses.values) {
        if (status == 'pending') {
          pendingOrders++;
        } else if (status == 'confirmed') {
          confirmedOrders++;
        } else if (status == 'shipped') {
          shippedOrders++;
        } else if (status == 'delivered') {
          deliveredOrders++;
        }
      }

      int totalOrdersCount = uniqueOrders.length;

      // 6. Calculate Growth Percentage
      double growth = 0;
      if (lastMonthRevenue > 0) {
        growth =
            ((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100;
      } else if (thisMonthRevenue > 0) {
        growth = 100.0;
      }

      // 7. Calculate Average Order Value (Running Month) - User requested order count
      int ordersThisMonthCount = uniqueOrdersThisMonth.length;
      double avgOrderValue = ordersThisMonthCount.toDouble();

      // 8. Monthly Payout (92% after platform fees)
      double monthlyPayout = thisMonthRevenue * 0.92;

      // 9. Find top selling products
      List<Map<String, dynamic>> topProducts = [];
      if (productSales.isNotEmpty) {
        final sortedProducts = productSales.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (var entry in sortedProducts.take(3)) {
          dynamic product;
          for (var p in productsList) {
            if (p['id'] == entry.key) {
              product = p;
              break;
            }
          }
          if (product != null) {
            topProducts.add({
              'id': product['id'],
              'name': product['name'],
              'sales': entry.value,
              'image': product['image_url'],
              'price': product['price'],
            });
          }
        }
      }

      return {
        // Revenue Metrics
        'totalRevenue': totalRevenue,
        'thisMonthRevenue': thisMonthRevenue,
        'todayRevenue': todayRevenue,
        'growth': growth,
        'monthlyPayout': monthlyPayout,
        'avgOrderValue': avgOrderValue,

        // Order Metrics
        'totalOrders': totalOrdersCount,
        'pendingOrders': pendingOrders,
        'confirmedOrders': confirmedOrders,
        'shippedOrders': shippedOrders,
        'deliveredOrders': deliveredOrders,

        // Customer Metrics
        'totalClients': uniqueClients.length,

        // Product & Inventory Metrics
        'totalProducts': totalProducts,
        'totalStock': totalStock,
        'lowStockCount': lowStockCount,
        'outOfStockCount': outOfStockCount,
        'topProducts': topProducts,

        // Analytics specific
        'salesTrend': salesTrend,
        'categoryPerformance': categoryPerformance,
        'recentTransactions': recentTransactions.reversed
            .take(10)
            .toList(), // Take latest 10
        // Metadata
        'updatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      // Error in fetchSalesStats
      return _getEmptyStats();
    }
  }

  Map<String, dynamic> _getEmptyStats() {
    return {
      'totalRevenue': 0.0,
      'thisMonthRevenue': 0.0,
      'todayRevenue': 0.0,
      'growth': 0.0,
      'pendingOrders': 0,
      'confirmedOrders': 0,
      'shippedOrders': 0,
      'deliveredOrders': 0,
      'totalOrders': 0,
      'totalClients': 0,
      'monthlyPayout': 0.0,
      'avgOrderValue': 0.0,
      'totalProducts': 0,
      'totalStock': 0,
      'lowStockCount': 0,
      'outOfStockCount': 0,
      'topProducts': [],
      'salesTrend7Days': List.filled(7, 0.0),
      'categoryPerformance': <String, double>{},
      'paymentStatusBreakdown': {'paid': 0.0, 'pending': 0.0, 'failed': 0.0},
      'recentTransactions': [],
    };
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
