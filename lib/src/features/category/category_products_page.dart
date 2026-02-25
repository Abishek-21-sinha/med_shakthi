import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'product_filter_sheet.dart';
import 'b2b_product_filter.dart';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';
import 'package:med_shakthi/src/core/utils/custom_snackbar.dart';
import 'package:med_shakthi/src/features/products/data/models/product_model.dart';
import 'package:med_shakthi/src/features/products/presentation/screens/product_page.dart';

class CategoryProductsPage extends StatefulWidget {
  final String categoryName;

  const CategoryProductsPage({super.key, required this.categoryName});

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> visibleProducts = [];
  bool loading = false;
  bool _isFirstLoad = true;
  final searchController = TextEditingController();

  B2BProductFilter? _currentFilter;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  Future<void> _refreshProducts() async {
    if (_isFirstLoad) {
      setState(() => loading = true);
    } else {
      setState(() => loading = true); // Still set loading true for progress bar
    }

    try {
      dynamic query = supabase
          .from('products')
          .select('''
        *,
        suppliers!inner(name, supplier_code, id)
      ''')
          .eq('is_active', true);

      // Category Filter (Always apply)
      query = query.ilike('category', '%${widget.categoryName}%');

      // Search Filter (Server-side)
      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'name.ilike.%$_searchQuery%,brand.ilike.%$_searchQuery%',
        );
      }

      // Apply saved filter if exists
      if (_currentFilter != null) {
        final filter = _currentFilter!;
        // Price range filters
        if (filter.minPrice != null && filter.minPrice! > 0) {
          query = query.gte('price', filter.minPrice!);
        }
        if (filter.maxPrice != null && filter.maxPrice! > 0) {
          query = query.lte('price', filter.maxPrice!);
        }

        // Expiry filter
        if (filter.expiryBefore != null) {
          query = query.lt(
            'expiry_date',
            filter.expiryBefore!.toIso8601String(),
          );
        }

        // Sorting
        if (filter.sortBy != null && filter.sortBy!.isNotEmpty) {
          if (filter.sortBy == 'price_low') {
            query = query.order('price', ascending: true);
          } else if (filter.sortBy == 'price_high') {
            query = query.order('price', ascending: false);
          } else if (filter.sortBy == 'name_az') {
            query = query.order('name', ascending: true);
          } else if (filter.sortBy == 'name_za') {
            query = query.order('name', ascending: false);
          } else if (filter.sortBy == 'expiry_soon') {
            query = query.order('expiry_date', ascending: true);
          } else {
            query = query.order('created_at', ascending: false);
          }
        }
      }

      final response = await query.limit(100);

      if (mounted) {
        products = List<Map<String, dynamic>>.from(response);
        visibleProducts = List<Map<String, dynamic>>.from(products);
        setState(() {
          loading = false;
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(
          context,
          'Failed to fetch products: $e',
          isError: true,
        );
        setState(() {
          loading = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  String _formatExpiry(String? expiryDate) {
    if (expiryDate == null) return 'N/A';
    try {
      final date = DateTime.parse(expiryDate);
      return '${date.day}/${date.month}';
    } catch (e) {
      return 'N/A';
    }
  }

  Timer? _debounce;

  void applySearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      _refreshProducts();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.categoryName,
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: _buildCategoryIntro(context),
            ),
            backgroundColor: Theme.of(context).cardColor,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.tune,
                  color: Theme.of(context).iconTheme.color,
                ),
                onPressed: () async {
                  final newFilter =
                      await showModalBottomSheet<B2BProductFilter>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (_) => const ProductFilterSheet(),
                      );
                  if (newFilter != null) {
                    await _refreshProducts();
                  }
                },
              ),
            ],
            bottom: loading && !_isFirstLoad
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xff2b9c8f),
                      ),
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                onChanged: applySearch,
                decoration: InputDecoration(
                  hintText: 'Search products by name, brand, SKU...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xff2b9c8f),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          if (_isFirstLoad && loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xff2b9c8f)),
              ),
            )
          else if (visibleProducts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      searchController.text.isNotEmpty
                          ? Icons.search_off
                          : Icons.inventory_2_outlined,
                      size: 64,
                      color: Theme.of(context).disabledColor,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        searchController.text.isNotEmpty
                            ? 'No products found matching your search'
                            : 'No products available in this category',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = visibleProducts[index];
                  final price =
                      double.tryParse(product['price']?.toString() ?? '0') ??
                      0.0;
                  return _buildProductCard(product, price);
                }, childCount: visibleProducts.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryIntro(BuildContext context) {
    // Customize intro based on category
    String description = "Browse our collection";
    List<Color> gradientColors = [Colors.blue.shade200, Colors.blue.shade50];
    IconData icon = Icons.category;

    if (widget.categoryName == "Medicines") {
      description = "Essential medicines for your health";
      gradientColors = [const Color(0xFFE0F7FA), const Color(0xFFB2EBF2)];
      icon = Icons.medication;
    } else if (widget.categoryName == "Vitamins") {
      description = "Boost your immunity naturally";
      gradientColors = [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)];
      icon = Icons.wb_sunny;
    } else if (widget.categoryName == "Health") {
      description = "Take care of your well-being";
      gradientColors = [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)];
      icon = Icons.favorite;
    } else if (widget.categoryName == "Care") {
      description = "Personal care & hygiene products";
      gradientColors = [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)];
      icon = Icons.spa;
    } else if (widget.categoryName == "Devices") {
      description = "Medical devices & equipment";
      gradientColors = [const Color(0xFFF3E5F5), const Color(0xFFE1BEE7)];
      icon = Icons.medical_services;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.black54),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, double price) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () {
          final supplierData = product['suppliers'] as Map<String, dynamic>?;
          final productModel = Product(
            id: product['id']?.toString() ?? '',
            name: product['name'] ?? 'Unknown Product',
            price: price,
            image: product['image_url'] ?? '',
            category: product['category'] ?? widget.categoryName,
            rating: 0.0,
            supplierName: supplierData?['name'] as String?,
            supplierCode: supplierData?['supplier_code'] as String?,
            supplierId: supplierData?['id'] as String?,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductPage(product: productModel),
            ),
          );
        },
        leading: SmartProductImage(
          imageUrl: product['image_url'],
          category: product['category'] ?? widget.categoryName,
          width: 56,
          height: 56,
        ),
        title: Text(
          product['name'] ?? 'Unknown Product',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['brand'] ?? 'Generic',
              style: const TextStyle(fontSize: 14, color: Color(0xFF757575)),
            ),
            const SizedBox(height: 4),
            // Supplier info
            if (product['suppliers'] != null) ...[
              Row(
                children: [
                  const Icon(Icons.store, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'by ${product['suppliers']['name']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              '₹${price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xff2b9c8f),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Expires: ${_formatExpiry(product['expiry_date'])}',
                    style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Color(0xFF757575),
        ),
      ),
    );
  }
}
