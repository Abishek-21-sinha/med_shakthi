import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/category/category_products_page.dart';
import 'package:med_shakthi/src/features/search/presentation/screens/global_search_page.dart';
import 'package:med_shakthi/src/features/category/product_filter_sheet.dart';
import 'package:med_shakthi/src/features/category/b2b_product_filter.dart';

class CategoryPageNew extends StatefulWidget {
  const CategoryPageNew({super.key});

  @override
  State<CategoryPageNew> createState() => _CategoryPageNewState();
}

class _CategoryPageNewState extends State<CategoryPageNew> {
  final supabase = Supabase.instance.client;
  List<CategoryItem> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      // Fetch distinct categories from products table
      final response = await supabase
          .from('products')
          .select('category')
          .eq('is_active', true)
          .withConverter<List<String>>((data) {
            final list = data as List<dynamic>;
            return list
                .map((e) => e['category'] as String?)
                .where((e) => e != null)
                .cast<String>()
                .toSet()
                .toList();
          });

      if (mounted) {
        setState(() {
          categories = response.map((cat) {
            return CategoryItem(
              title: cat,
              icon: _getIconForCategory(cat),
              skuCountText:
                  'Explore', // Dynamic count is expensive, simplifying
              badgeText: 'Available',
              badgeColor: _getColorForCategory(cat),
            );
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) {
        // Fallback to static data if error
        setState(() {
          categories = [
            ...corePharmacyCategories,
            ...personalCareCategories,
            ...deviceCategories,
          ];
          isLoading = false;
        });
      }
    }
  }

  IconData _getIconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('medicine')) return Icons.medication;
    if (lower.contains('vitamin')) return Icons.wb_sunny;
    if (lower.contains('health')) return Icons.favorite;
    if (lower.contains('care')) return Icons.spa;
    if (lower.contains('device')) return Icons.medical_services;
    if (lower.contains('lab')) return Icons.biotech;
    if (lower.contains('baby')) return Icons.child_care;
    if (lower.contains('surgical')) return Icons.local_hospital;
    return Icons.category;
  }

  Color _getColorForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('medicine')) return Colors.blue;
    if (lower.contains('vitamin')) return Colors.orange;
    if (lower.contains('health')) return Colors.red;
    if (lower.contains('care')) return Colors.green;
    if (lower.contains('device')) return Colors.purple;
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Shop by Category',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SearchAndFilterBar(),
                          SizedBox(height: 20),
                          _CategoryGroupTitle(title: 'All Categories'),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = categories[index];
                        return CategoryCard(item: item, index: index);
                      }, childCount: categories.length),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ),
            ),
    );
  }
}

/// Search + filter row (like modern pharmacy UI)
class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GlobalSearchPage()),
              );
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AbsorbPointer(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search medicines, categories…',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 22,
                      color: Theme.of(
                        context,
                      ).iconTheme.color?.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        /// FILTER BUTTON
        GestureDetector(
          onTap: () async {
            final filters = await showModalBottomSheet<B2BProductFilter>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const ProductFilterSheet(),
            );

            if (filters != null) {
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GlobalSearchPage(initialFilter: filters),
                ),
              );
            }
          },
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4C8077),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4C8077).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryGroupTitle extends StatelessWidget {
  final String title;

  const _CategoryGroupTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// DATA MODEL
class CategoryItem {
  final String title;
  final IconData icon;
  final String skuCountText; // e.g. "120+ SKUs"
  final String badgeText; // e.g. "Fast moving" / "Offer"
  final Color badgeColor;

  CategoryItem({
    required this.title,
    required this.icon,
    required this.skuCountText,
    required this.badgeText,
    required this.badgeColor,
  });
}

// Fallback Data
final List<CategoryItem> corePharmacyCategories = [
  CategoryItem(
    title: 'Medicines',
    icon: Icons.medication,
    skuCountText: '450+ SKUs',
    badgeText: 'Fast moving',
    badgeColor: Colors.green.shade600,
  ),
  CategoryItem(
    title: 'Diabetes',
    icon: Icons.bloodtype,
    skuCountText: '90+ SKUs',
    badgeText: 'High margin',
    badgeColor: Colors.blue.shade600,
  ),
  CategoryItem(
    title: 'BP Monitor',
    icon: Icons.monitor_heart,
    skuCountText: '25 SKUs',
    badgeText: 'Top rated',
    badgeColor: Colors.orange.shade600,
  ),
];

final List<CategoryItem> personalCareCategories = [
  CategoryItem(
    title: 'Face & Beauty',
    icon: Icons.face,
    skuCountText: '120+ SKUs',
    badgeText: 'Up to 20% off',
    badgeColor: Colors.red.shade500,
  ),
  CategoryItem(
    title: 'Hair Care',
    icon: Icons.content_cut,
    skuCountText: '80+ SKUs',
    badgeText: 'Fast moving',
    badgeColor: Colors.green.shade600,
  ),
  CategoryItem(
    title: 'Soaps',
    icon: Icons.clean_hands,
    skuCountText: '140+ SKUs',
    badgeText: 'Best margins',
    badgeColor: Colors.blue.shade600,
  ),
];

final List<CategoryItem> deviceCategories = [
  CategoryItem(
    title: 'Thermometer',
    icon: Icons.thermostat,
    skuCountText: '20 SKUs',
    badgeText: 'Bestseller',
    badgeColor: Colors.orange.shade600,
  ),
  CategoryItem(
    title: 'Oximeter',
    icon: Icons.monitor_weight_outlined,
    skuCountText: '15 SKUs',
    badgeText: 'Only few left',
    badgeColor: Colors.red.shade500,
  ),
  CategoryItem(
    title: 'Weighing Scale',
    icon: Icons.monitor_weight,
    skuCountText: '10 SKUs',
    badgeText: 'New',
    badgeColor: Colors.purple.shade500,
  ),
  CategoryItem(
    title: 'Supplements',
    icon: Icons.medication_liquid,
    skuCountText: '—',
    badgeText: 'Available',
    badgeColor: Colors.green.shade600,
  ),
  CategoryItem(
    title: 'Surgical',
    icon: Icons.local_hospital,
    skuCountText: '—',
    badgeText: 'Available',
    badgeColor: Colors.blue.shade600,
  ),
];

/// CATEGORY CARD WIDGET
class CategoryCard extends StatelessWidget {
  final CategoryItem item;
  final int index;

  const CategoryCard({super.key, required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    // Staggered Entry Animation
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryProductsPage(categoryName: item.title),
            ),
          );
        },
        child: Container(
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Container
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: item.badgeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 30, color: item.badgeColor),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.skuCountText,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
