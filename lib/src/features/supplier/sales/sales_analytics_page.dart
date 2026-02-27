import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'sales_stats_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';

class SalesAnalyticsPage extends StatefulWidget {
  const SalesAnalyticsPage({super.key});

  @override
  State<SalesAnalyticsPage> createState() => _SalesAnalyticsPageState();
}

class _SalesAnalyticsPageState extends State<SalesAnalyticsPage>
    with SingleTickerProviderStateMixin {
  String _selectedDateRange = 'Month';
  String _selectedCategory = 'All';
  String _selectedPaymentStatus = 'All';
  late AnimationController _animationController;
  late Future<Map<String, dynamic>> _salesStatsFuture;

  // Search and transactions
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _allTransactions = [];
  List<Map<String, String>> _filteredTransactions = [];

  @override
  void initState() {
    super.initState();
    _salesStatsFuture = _fetchStats();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _searchController.addListener(_onSearchChanged);
  }

  Future<Map<String, dynamic>> _fetchStats() {
    return SalesStatsService().fetchSalesStats(dateRange: _selectedDateRange);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTransactions = List.from(_allTransactions);
      } else {
        _filteredTransactions = _allTransactions.where((t) {
          return t['id']!.toLowerCase().contains(query) ||
              t['medicine']!.toLowerCase().contains(query) ||
              t['status']!.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _applyFiltersAndRefetch() {
    setState(() {
      _salesStatsFuture = SalesStatsService().fetchSalesStats(
        dateRange: _selectedDateRange,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
        paymentStatus: _selectedPaymentStatus == 'All'
            ? null
            : _selectedPaymentStatus,
      );
      _searchController.clear();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _salesStatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          setState(() => _salesStatsFuture = _fetchStats()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('No data found.'));
            }
            final data = snapshot.data ?? {};

            // Sync transactions for search
            final transactionsRaw =
                data['recentTransactions'] as List<dynamic>? ?? [];
            _allTransactions = transactionsRaw.map((e) {
              final map = e as Map<String, dynamic>;
              return map.map((key, value) => MapEntry(key, value.toString()));
            }).toList();

            if (_searchController.text.isEmpty) {
              _filteredTransactions = List.from(_allTransactions);
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  elevation: 0,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  title: Text(
                    'Sales Analytics',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: theme.colorScheme.primary,
                      ),
                      tooltip: 'Refresh',
                      onPressed: _applyFiltersAndRefetch,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.filter_list_rounded,
                        color: theme.iconTheme.color,
                      ),
                      onPressed: () => _showFilterBottomSheet(context),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildDateRangeSelector(isDark),
                      const SizedBox(height: 20),
                      _buildSalesSummaryCards(isDark, data),
                      const SizedBox(height: 24),
                      _buildFilterChips(isDark),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Sales Trend', isDark),
                      const SizedBox(height: 16),
                      _buildSalesTrendChart(isDark, data),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Category Performance', isDark),
                      const SizedBox(height: 16),
                      _buildCategoryBarChart(isDark, data),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Top Selling Products', isDark),
                      const SizedBox(height: 16),
                      _buildTopSellingList(isDark, data),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Recent Transactions', isDark),
                      const SizedBox(height: 16),
                      _buildSalesDetailsTable(isDark),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector(bool isDark) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: ['Today', 'Week', 'Month', 'Custom'].map((range) {
          final isSelected = _selectedDateRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                if (range == 'Custom') {
                  await _showCustomDateRange(context);
                } else {
                  setState(() => _selectedDateRange = range);
                  _applyFiltersAndRefetch();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF63B4B7), Color(0xFF4CA6A8)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    range,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black54),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSalesSummaryCards(bool isDark, Map<String, dynamic> data) {
    final revenue = data['totalRevenue'] ?? 0.0;
    final orders = data['totalOrders'] ?? 0;
    final pending = data['pendingOrders'] ?? 0;
    final growth = data['growth'] ?? 0.0;
    final growthStr = growth >= 0
        ? '+${growth.toStringAsFixed(1)}%'
        : '${growth.toStringAsFixed(1)}%';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      mainAxisExtent: 170,
      children: [
        _buildSummaryCard(
          'Total Revenue',
          '₹${(revenue as double).toStringAsFixed(0)}',
          growthStr,
          Icons.trending_up_rounded,
          const Color(0xFF4CA6A8),
          isDark,
        ),
        _buildSummaryCard(
          'Total Orders',
          '$orders',
          'Count',
          Icons.shopping_bag_rounded,
          const Color(0xFF6366F1),
          isDark,
        ),
        _buildSummaryCard(
          'Profit Growth',
          growthStr,
          growthStr,
          Icons.show_chart_rounded,
          const Color(0xFF10B981),
          isDark,
        ),
        _buildSummaryCard(
          'Pending Orders',
          '$pending',
          'Needs Action',
          Icons.pending_actions_rounded,
          const Color(0xFFF59E0B),
          isDark,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title,
      String value,
      String change,
      IconData icon,
      Color color,
      bool isDark,
      ) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🔹 Top Row (Icon + Badge)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: change.startsWith('+')
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        change,
                        style: TextStyle(
                          color: change.startsWith('+')
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// 🔹 Value + Title
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {

    final now = DateTime.now();

    final dateText =
    _selectedDateRange == 'Today'
        ? DateFormat('dd MMM').format(now)
        : _selectedDateRange;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip(
            '$dateText',
            isDark,
                () => _showFilterBottomSheet(context),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            '🗂 Category: $_selectedCategory',
            isDark,
                () => _showFilterBottomSheet(context),
          ),
        ],
      ),
    );
  }
  Widget _buildFilterChip(String label, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF4CA6A8).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildSalesTrendChart(bool isDark, Map<String, dynamic> data) {
    final List<Map<String, dynamic>> salesTrend =
        (data['salesTrend'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    if (salesTrend.isEmpty) {
      return _buildEmptyChart(isDark, 280);
    }

    double maxY = salesTrend
        .map((e) => (e['value'] as num).toDouble())
        .reduce((curr, next) => curr > next ? curr : next);
    if (maxY < 10) maxY = 10;
    maxY *= 1.2;

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: _chartDecoration(isDark),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5 > 0 ? maxY / 5 : 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  String text;
                  if (value >= 100000) {
                    text = '₹${(value / 100000).toStringAsFixed(1)}L';
                  } else if (value >= 1000) {
                    text = '₹${(value / 1000).toStringAsFixed(1)}k';
                  } else {
                    text = '₹${value.toInt()}';
                  }
                  return Text(
                    text,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value != value.toInt()) return const SizedBox.shrink();
                  int idx = value.toInt();
                  if (idx >= 0 && idx < salesTrend.length) {
                    if (salesTrend.length > 15 &&
                        idx % 3 != 0 &&
                        idx != salesTrend.length - 1 &&
                        idx != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        salesTrend[idx]['label'] as String,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (salesTrend.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                salesTrend.length,
                (index) => FlSpot(
                  index.toDouble(),
                  (salesTrend[index]['value'] as num).toDouble(),
                ),
              ),
              isCurved: true,
              gradient: const LinearGradient(
                colors: [Color(0xFF63B4B7), Color(0xFF4CA6A8)],
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF4CA6A8),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4CA6A8).withValues(alpha: 0.3),
                    const Color(0xFF4CA6A8).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FIX: dynamic bar count — no more hardcoded [0],[1],[2],[3]
  Widget _buildCategoryBarChart(bool isDark, Map<String, dynamic> data) {
    final Map<String, double> categoryMap =
        (data['categoryPerformance'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ) ??
        {};

    if (categoryMap.isEmpty) {
      return _buildEmptyChart(isDark, 300, message: 'No category data yet');
    }

    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take up to 6 categories dynamically
    final topEntries = sortedCategories.take(6).toList();
    final topCategoryNames = topEntries.map((e) => e.key).toList();
    final topCategoryValues = topEntries.map((e) => e.value).toList();

    double maxY = topCategoryValues.reduce(
      (curr, next) => curr > next ? curr : next,
    );
    if (maxY < 10) maxY = 10;
    maxY *= 1.2;

    const barColors = [
      Color(0xFF4CA6A8),
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFFEC4899),
    ];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: _chartDecoration(isDark),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => const Color(0xFF4CA6A8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                String label = '';
                if (group.x < topCategoryNames.length) {
                  label = '${topCategoryNames[group.x]}\n';
                }
                return BarTooltipItem(
                  '$label₹${rod.toY.toInt()}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  String text;
                  if (value >= 100000) {
                    text = '₹${(value / 100000).toStringAsFixed(1)}L';
                  } else if (value >= 1000) {
                    text = '₹${(value / 1000).toStringAsFixed(1)}k';
                  } else {
                    text = '₹${value.toInt()}';
                  }
                  return Text(
                    text,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < topCategoryNames.length) {
                    String name = topCategoryNames[idx];
                    if (name.length > 8) name = '${name.substring(0, 7)}…';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5 > 0 ? maxY / 5 : 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          // ✅ Generate bars dynamically — no more hardcoded indices
          barGroups: List.generate(topEntries.length, (i) {
            final color = barColors[i % barColors.length];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: topCategoryValues[i],
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 28,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTopSellingList(bool isDark, Map<String, dynamic> data) {
    var productsRaw = data['topProducts'] as List<dynamic>? ?? [];

    if (productsRaw.isEmpty) {
      return _buildEmptyChart(
        isDark,
        120,
        message: 'No product sales data yet',
      );
    }

    int maxSales = productsRaw
        .map((p) => p['sales'] as int)
        .reduce((a, b) => a > b ? a : b);
    if (maxSales == 0) maxSales = 1;

    final products = productsRaw.map((p) {
      double revenue =
          (p['price'] as num).toDouble() * (p['sales'] as num).toDouble();

      String formatAmt(double amt) {
        if (amt >= 100000) return '₹${(amt / 100000).toStringAsFixed(1)}L';
        if (amt >= 1000) return '₹${(amt / 1000).toStringAsFixed(1)}k';
        return '₹${amt.toInt()}';
      }

      return {
        'name': p['name'].toString(),
        'revenue': formatAmt(revenue),
        'percentage': (p['sales'] as num).toDouble() / maxSales,
      };
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _chartDecoration(isDark),
      child: Column(
        children: products.asMap().entries.map((entry) {
          final index = entry.key;
          final product = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < products.length - 1 ? 16 : 0,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: index == 0
                              ? [
                                  const Color(0xFFFFD700),
                                  const Color(0xFFFFA500),
                                ]
                              : [
                                  const Color(0xFF4CA6A8),
                                  const Color(0xFF63B4B7),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: product['percentage'] as double,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                index == 0
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFF4CA6A8),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      product['revenue'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (index < products.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      height: 1,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ✅ FIX: _filteredTransactions used (with search), not raw data parameter
  Widget _buildSalesDetailsTable(bool isDark) {
    return Container(
      decoration: _chartDecoration(isDark),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ✅ FIX: wired-up search with TextEditingController
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by ID, medicine or status…',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white60 : Colors.black54,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  size: 16,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // ✅ FIX: correct CSV API
                GestureDetector(
                  onTap: () => _exportCSV(_filteredTransactions),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF63B4B7), Color(0xFF4CA6A8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Export',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_filteredTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _searchController.text.isNotEmpty
                    ? 'No transactions match your search'
                    : 'No transactions found',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 14,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02),
                ),
                dataRowColor: WidgetStateProperty.all(Colors.transparent),
                columns: [
                  _tableColumn('Order ID', isDark),
                  _tableColumn('Medicine', isDark),
                  _tableColumn('Qty', isDark),
                  _tableColumn('Amount', isDark),
                  _tableColumn('Status', isDark),
                  _tableColumn('Date', isDark),
                ],
                rows: _filteredTransactions.map((transaction) {
                  final status = transaction['status'] ?? '';
                  final isSuccess = [
                    'paid',
                    'success',
                    'completed',
                  ].contains(status.toLowerCase());
                  final isPending = status.toLowerCase() == 'pending';
                  final statusColor = isSuccess
                      ? const Color(0xFF10B981)
                      : isPending
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444);

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          transaction['id'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CA6A8),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction['medicine'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction['qty'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction['amount'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.isNotEmpty
                                ? status[0].toUpperCase() + status.substring(1)
                                : '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          transaction['date'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  DataColumn _tableColumn(String label, bool isDark) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  BoxDecoration _chartDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildEmptyChart(
    bool isDark,
    double height, {
    String message = 'No data available',
  }) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: _chartDecoration(isDark),
      child: Text(
        message,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black45,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _filterSectionLabel('Date Range', isDark),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ['Today', 'Week', 'Month', 'Custom'].map((range) {
                      return ChoiceChip(
                        label: Text(range),
                        selected: _selectedDateRange == range,
                        selectedColor: const Color(0xFF4CA6A8),
                        labelStyle: TextStyle(
                          color: _selectedDateRange == range
                              ? Colors.white
                              : null,
                        ),
                        onSelected: (selected) {
                          if (range == 'Custom') {
                            Navigator.pop(context);
                            _showCustomDateRange(context);
                          } else {
                            setModalState(() => _selectedDateRange = range);
                            setState(() => _selectedDateRange = range);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  _filterSectionLabel('Category', isDark),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          'All',
                          'Medicines',
                          'Supplements',
                          'Devices',
                          'Baby Care',
                          'Personal Care',
                        ].map((category) {
                          return ChoiceChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            selectedColor: const Color(0xFF4CA6A8),
                            labelStyle: TextStyle(
                              color: _selectedCategory == category
                                  ? Colors.white
                                  : null,
                            ),
                            onSelected: (selected) {
                              setModalState(() => _selectedCategory = category);
                              setState(() => _selectedCategory = category);
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 20),
                  _filterSectionLabel('Payment Status', isDark),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: ['All', 'Paid', 'Pending', 'Failed'].map((
                      status,
                    ) {
                      return ChoiceChip(
                        label: Text(status),
                        selected: _selectedPaymentStatus == status,
                        selectedColor: const Color(0xFF4CA6A8),
                        labelStyle: TextStyle(
                          color: _selectedPaymentStatus == status
                              ? Colors.white
                              : null,
                        ),
                        onSelected: (selected) {
                          setModalState(() => _selectedPaymentStatus = status);
                          setState(() => _selectedPaymentStatus = status);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4CA6A8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // ✅ FIX: apply filters and re-fetch data
                        _applyFiltersAndRefetch();
                      },
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                  ),
                ),
            );
          },
        );
      },
    );
  }

  Widget _filterSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }
  Future<void> _showCustomDateRange(BuildContext context) async {
    final startController = TextEditingController();
    final endController = TextEditingController();

    String? startError;
    String? endError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isValidDate(String input) {
              try {
                final parts = input.split('/');
                if (parts.length != 3) return false;

                int day = int.parse(parts[0]);
                int month = int.parse(parts[1]);
                int year = int.parse(parts[2]);

                if (year < 1900 || year > 2100) return false;
                if (month < 1 || month > 12) return false;
                if (day < 1 || day > 31) return false;

                final date = DateTime(year, month, day);

                return date.day == day &&
                    date.month == month &&
                    date.year == year;
              } catch (e) {
                return false;
              }
            }

            DateTime parseDate(String input) {
              final parts = input.split('/');
              return DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    const Text(
                      "Select Date Range",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 20),

                    /// START DATE
                    TextField(
                      controller: startController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Start Date (DD/MM/YYYY)",
                        errorText: startError,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        DateInputFormatter(),
                      ],
                    ),

                    const SizedBox(height: 15),

                    /// END DATE
                    TextField(
                      controller: endController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "End Date (DD/MM/YYYY)",
                        errorText: endError,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        DateInputFormatter(),
                      ],
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () {
                        final start = startController.text;
                        final end = endController.text;

                        setModalState(() {
                          startError = null;
                          endError = null;
                        });

                        /// Empty check
                        if (start.isEmpty || end.isEmpty) {
                          setModalState(() {
                            if (start.isEmpty) {
                              startError = "Start date required";
                            }
                            if (end.isEmpty) {
                              endError = "End date required";
                            }
                          });
                          return;
                        }

                        /// Format validation
                        if (!isValidDate(start)) {
                          setModalState(() {
                            startError = "Invalid date";
                          });
                          return;
                        }

                        if (!isValidDate(end)) {
                          setModalState(() {
                            endError = "Invalid date";
                          });
                          return;
                        }

                        /// Compare dates
                        DateTime startDate = parseDate(start);
                        DateTime endDate = parseDate(end);

                        if (startDate.isAfter(endDate)) {
                          setModalState(() {
                            endError =
                            "End date must be after start date";
                          });
                          return;
                        }

                        /// SUCCESS
                        Navigator.pop(context);

                        setState(() {
                          _selectedDateRange = 'Custom';
                          _salesStatsFuture =
                              SalesStatsService().fetchSalesStats(
                                dateRange: 'Custom',
                                customStartDate: startDate,
                                customEndDate: endDate,
                              );
                        });
                      },
                      child: const Text("Apply"),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  // ✅ FIX: correct CSV API — ListToCsvConverter().convert()
  Future<void> _exportCSV(List<Map<String, dynamic>> transactions) async {
    try {
      List<List<dynamic>> rows = [
        ['Order ID', 'Medicine', 'Qty', 'Amount', 'Status', 'Date'],
        ...transactions.map(
          (t) => [
            t['id'],
            t['medicine'],
            t['qty'],
            t['amount'],
            t['status'],
            t['date'],
          ],
        ),
      ];

      // Simple CSV encoding — quote any field containing commas or quotes
      String encodeField(dynamic v) {
        final s = v?.toString() ?? '';
        if (s.contains(',') || s.contains('"') || s.contains('\n')) {
          return '"${s.replaceAll('"', '""')}"';
        }
        return s;
      }

      String csvData = rows
          .map((row) => row.map(encodeField).join(','))
          .join('\n');

      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/sales_export_${DateTime.now().millisecondsSinceEpoch}.csv';

      await File(path).writeAsString(csvData);
      await OpenFilex.open(path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV exported successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

}
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue) {

    String text = newValue.text.replaceAll('/', '');

    if (text.length > 8) {
      text = text.substring(0, 8);
    }

    String formatted = '';

    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if ((i == 1 || i == 3) && i != text.length - 1) {
        formatted += '/';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
