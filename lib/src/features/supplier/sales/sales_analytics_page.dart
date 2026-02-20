import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'sales_stats_service.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
// permission_handler removed (unused)
import 'package:open_filex/open_filex.dart';

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

  @override
  void initState() {
    super.initState();
    _salesStatsFuture = SalesStatsService().fetchSalesStats();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('No data found.'));
            }
            final data = snapshot.data ?? {};

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
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
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  actions: [
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

                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Date Range Selector
                      _buildDateRangeSelector(isDark),
                      const SizedBox(height: 20),

                      // Sales Summary Cards
                      _buildSalesSummaryCards(isDark, data),
                      const SizedBox(height: 24),

                      // Filter Chips
                      _buildFilterChips(isDark),
                      const SizedBox(height: 24),

                      // Sales Trend Chart
                      _buildSectionTitle('Sales Trend', isDark),
                      const SizedBox(height: 16),
                      _buildSalesTrendChart(isDark, data),
                      const SizedBox(height: 24),

                      // Category-wise Sales
                      _buildSectionTitle('Category Performance', isDark),
                      const SizedBox(height: 16),
                      _buildCategoryBarChart(isDark, data),
                      const SizedBox(height: 24),

                      // Top Selling Medicines
                      _buildSectionTitle('Top Selling Products', isDark),
                      const SizedBox(height: 16),
                      _buildTopSellingList(isDark, data),
                      const SizedBox(height: 24),

                      // Sales Details Table
                      _buildSectionTitle('Recent Transactions', isDark),
                      const SizedBox(height: 16),
                      _buildSalesDetailsTable(isDark, data),
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
              onTap: () {
                if (range == 'Custom') {
                  _showDateRangePicker(context);
                } else {
                  setState(() {
                    _selectedDateRange = range;
                    _salesStatsFuture = SalesStatsService().fetchSalesStats(
                      dateRange: _selectedDateRange,
                    );
                  });
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

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildSummaryCard(
          'Total Revenue',
          '₹${revenue.toStringAsFixed(0)}',
          '+$growth%',
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
          '$growth%',
          '+$growth%',
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                Container(
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
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('📅 $_selectedDateRange', isDark, () => {}),
          const SizedBox(width: 8),
          _buildFilterChip(
            '🗂 Category: $_selectedCategory',
            isDark,
            () => _showCategoryFilter(context),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            '💳 Payment: $_selectedPaymentStatus',
            isDark,
            () => _showPaymentFilter(context),
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
      return Container(
        height: 280,
        alignment: Alignment.center,
        child: const Text('No data available'),
      );
    }

    double maxY = salesTrend
        .map((e) => (e['value'] as num).toDouble())
        .reduce((curr, next) => curr > next ? curr : next);
    if (maxY < 10) maxY = 10; // Minimum Y axis
    maxY *= 1.2; // Add some headroom

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
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
      ),
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
                  // Don't show max/min edge values if they overlap
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
                  // Only show labels for integer values to avoid duplicate labels
                  if (value != value.toInt()) {
                    return const SizedBox.shrink();
                  }

                  int idx = value.toInt();
                  if (idx >= 0 && idx < salesTrend.length) {
                    // For 30 days, we might want to skip some labels to avoid crowding
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

  Widget _buildCategoryBarChart(bool isDark, Map<String, dynamic> data) {
    final Map<String, double> categoryMap =
        (data['categoryPerformance'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ) ??
        {};

    // We map categories to these fixed 4 slots for simplicity, or we can use dynamic slots
    // For now, let's take the top 4 categories
    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final List<String> topCategoryNames = [];
    final List<double> topCategoryValues = [];

    for (int i = 0; i < 4; i++) {
      if (i < sortedCategories.length) {
        topCategoryNames.add(sortedCategories[i].key);
        topCategoryValues.add(sortedCategories[i].value);
      } else {
        topCategoryNames.add('N/A');
        topCategoryValues.add(0);
      }
    }

    double maxY = topCategoryValues.isEmpty
        ? 10
        : topCategoryValues.reduce((curr, next) => curr > next ? curr : next);
    if (maxY < 10) maxY = 10;
    maxY *= 1.2;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
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
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => const Color(0xFF4CA6A8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '₹${rod.toY.toInt()}',
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
                  if (value.toInt() >= 0 &&
                      value.toInt() < topCategoryNames.length) {
                    String name = topCategoryNames[value.toInt()];
                    if (name.length > 10) {
                      name =
                          '${name.substring(0, 8)}...'; // Truncate long names
                    }
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
                  return const SizedBox();
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
          barGroups: [
            _buildBarGroup(0, topCategoryValues[0], const Color(0xFF4CA6A8)),
            _buildBarGroup(1, topCategoryValues[1], const Color(0xFF6366F1)),
            _buildBarGroup(2, topCategoryValues[2], const Color(0xFF10B981)),
            _buildBarGroup(3, topCategoryValues[3], const Color(0xFFF59E0B)),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 30, // Make slightly narrower to fit text
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ],
    );
  }

  Widget _buildTopSellingList(bool isDark, Map<String, dynamic> data) {
    var productsRaw = data['topProducts'] as List<dynamic>? ?? [];

    int maxSales = productsRaw.isEmpty
        ? 1
        : productsRaw
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
      decoration: BoxDecoration(
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
      ),
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

  Widget _buildSalesDetailsTable(bool isDark, Map<String, dynamic> data) {
    final transactionsRaw = data['recentTransactions'] as List<dynamic>? ?? [];
    final List<Map<String, String>> transactions = transactionsRaw.map((e) {
      final map = e as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(key, value.toString()));
    }).toList();

    return Container(
      decoration: BoxDecoration(
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
      ),
      child: Column(
        children: [
          // Header with search and export
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
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
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white60 : Colors.black54,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _exportCSV(transactions),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF63B4B7), Color(0xFF4CA6A8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
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

          // Table
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
                DataColumn(
                  label: Text(
                    'Order ID',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Medicine',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Qty',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
              rows: transactions.map((transaction) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        transaction['id']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4CA6A8),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        transaction['medicine']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        transaction['qty']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        transaction['amount']!,
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
                          color:
                              transaction['status']!.toLowerCase() == 'paid' ||
                                  transaction['status']!.toLowerCase() ==
                                      'success' ||
                                  transaction['status']!.toLowerCase() ==
                                      'completed'
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : transaction['status']!.toLowerCase() ==
                                    'pending'
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                              : const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          // Capitalize first letter of status
                          transaction['status']![0].toUpperCase() +
                              transaction['status']!.substring(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                transaction['status']!.toLowerCase() ==
                                        'paid' ||
                                    transaction['status']!.toLowerCase() ==
                                        'success' ||
                                    transaction['status']!.toLowerCase() ==
                                        'completed'
                                ? const Color(0xFF10B981)
                                : transaction['status']!.toLowerCase() ==
                                      'pending'
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        transaction['date']!,
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

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['Today', 'Week', 'Month', 'Custom'].map((range) {
                  return ChoiceChip(
                    label: Text(range),
                    selected: _selectedDateRange == range,
                    onSelected: (selected) {
                      setState(() => _selectedDateRange = range);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['All', 'Medicines', 'Supplements', 'Devices'].map((
                  category,
                ) {
                  return ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = category);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Payment Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['All', 'Paid', 'Pending', 'Failed'].map((status) {
                  return ChoiceChip(
                    label: Text(status),
                    selected: _selectedPaymentStatus == status,
                    onSelected: (selected) {
                      setState(() => _selectedPaymentStatus = status);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: const Color(0xFF4CA6A8)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _selectedDateRange = 'Custom';
        _salesStatsFuture = SalesStatsService().fetchSalesStats(
          dateRange: 'Custom',
          customStartDate: picked.start,
          customEndDate: picked.end,
        );
      });
    } else {
      // If user cancelled, maybe revert to previous range if needed, or do nothing
    }
  }

  void _showCategoryFilter(BuildContext context) {
    _showFilterBottomSheet(context);
  }

  void _showPaymentFilter(BuildContext context) {
    _showFilterBottomSheet(context);
  }

  Future<void> _exportCSV(List<Map<String, dynamic>> transactions) async {
    try {
      // CSV rows
      List<List<dynamic>> rows = [];

      rows.add(["Order ID", "Medicine", "Qty", "Amount", "Status", "Date"]);

      for (var t in transactions) {
        rows.add([
          t['id'],
          t['medicine'],
          t['qty'],
          t['amount'],
          t['status'],
          t['date'],
        ]);
      }

      // Convert to CSV
      String csvData = const ListToCsvConverter().convert(rows);

      // Save in app directory (NO PERMISSION REQUIRED)
      final directory = await getApplicationDocumentsDirectory();

      final path =
          "${directory.path}/sales_export_${DateTime.now().millisecondsSinceEpoch}.csv";

      final file = File(path);

      await file.writeAsString(csvData);

      // Open file
      await OpenFilex.open(path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("CSV Exported Successfully")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Export failed: $e")));
    }
  }
}
