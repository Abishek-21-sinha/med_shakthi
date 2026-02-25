// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'b2b_product_filter.dart';

class ProductFilterSheet extends StatefulWidget {
  const ProductFilterSheet({super.key});

  @override
  State<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<ProductFilterSheet> {
  late final B2BProductFilter filter;
  final minPriceController = TextEditingController();
  final maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filter = B2BProductFilter();
  }

  @override
  void dispose() {
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardColor;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(cardColor),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _sectionCard(
                      context: context,
                      cardColor: cardColor,
                      title: 'Sort By',
                      icon: Icons.sort_rounded,
                      child: Column(
                        children: [
                          _radio('Price: Low → High', 'price_low', primary),
                          _radio('Price: High → Low', 'price_high', primary),
                          _radio('Name: A → Z', 'name_az', primary),
                          _radio('Name: Z → A', 'name_za', primary),
                          _radio('Expiry: Soonest', 'expiry_soon', primary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      context: context,
                      cardColor: cardColor,
                      title: 'Price Range',
                      icon: Icons.currency_rupee_rounded,
                      child: _priceRangeRow(primary),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      context: context,
                      cardColor: cardColor,
                      title: 'Expiry Date',
                      icon: Icons.event_available_rounded,
                      child: Column(
                        children: [
                          _check(
                            'Within 1 Month',
                            filter.expiry1Month,
                            primary,
                            (v) => setState(() => filter.expiry1Month = v),
                          ),
                          _check(
                            'Within 3 Months',
                            filter.expiry3Months,
                            primary,
                            (v) => setState(() => filter.expiry3Months = v),
                          ),
                          _check(
                            'Within 6 Months',
                            filter.expiry6Months,
                            primary,
                            (v) => setState(() => filter.expiry6Months = v),
                          ),
                          _check(
                            'Within 12 Months',
                            filter.expiry12Months,
                            primary,
                            (v) => setState(() => filter.expiry12Months = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      context: context,
                      cardColor: cardColor,
                      title: 'Stock Status',
                      icon: Icons.inventory_2_rounded,
                      child: Column(
                        children: [
                          _check(
                            'Available Only',
                            filter.availableOnly,
                            primary,
                            (v) => setState(() => filter.availableOnly = v),
                          ),
                          _check(
                            'Low Stock (< 10)',
                            filter.lowStock,
                            primary,
                            (v) => setState(() => filter.lowStock = v),
                          ),
                          _check(
                            'Out of Stock',
                            filter.outOfStock,
                            primary,
                            (v) => setState(() => filter.outOfStock = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      context: context,
                      cardColor: cardColor,
                      title: 'Minimum Rating',
                      icon: Icons.star_rounded,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                (filter.minRating ?? 0) > 0
                                    ? '${(filter.minRating ?? 0).toStringAsFixed(1)}+ stars'
                                    : 'Any rating',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: (filter.minRating ?? 0) > 0
                                      ? primary
                                      : Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: filter.minRating ?? 0,
                            min: 0,
                            max: 5,
                            divisions: 10,
                            label:
                                '${(filter.minRating ?? 0).toStringAsFixed(1)}+',
                            activeColor: primary,
                            inactiveColor: primary.withValues(alpha: 0.2),
                            onChanged: (v) =>
                                setState(() => filter.minRating = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildApplyButton(primary),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildHeader(Color cardColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
      child: Row(
        children: [
          const Text(
            'Filter & Sort',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                filter.sortBy = null;
                filter.minPrice = null;
                filter.maxPrice = null;
                filter.expiry1Month = false;
                filter.expiry3Months = false;
                filter.expiry6Months = false;
                filter.expiry12Months = false;
                filter.availableOnly = false;
                filter.lowStock = false;
                filter.outOfStock = false;
                filter.minRating = null;
                minPriceController.clear();
                maxPriceController.clear();
              });
            },
            child: const Text('Reset All'),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required BuildContext context,
    required Color cardColor,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          child,
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _radio(String label, String value, Color primary) {
    return RadioListTile<String>(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      groupValue: filter.sortBy,
      activeColor: primary,
      onChanged: (v) => setState(() => filter.sortBy = v),
    );
  }

  Widget _check(
    String label,
    bool value,
    Color primary,
    void Function(bool) onChanged,
  ) {
    return CheckboxListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      activeColor: primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      onChanged: (bool? v) {
        if (v != null) {
          onChanged(v);
        }
      },
    );
  }

  Widget _priceRangeRow(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: minPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Min',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.6),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
              ),
              onChanged: (v) => filter.minPrice = double.tryParse(v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '—',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: maxPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Max',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.6),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
              ),
              onChanged: (v) => filter.maxPrice = double.tryParse(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 3,
            shadowColor: primary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () => Navigator.pop(context, filter),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 20),
              SizedBox(width: 8),
              Text(
                'Apply Filters',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
