// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:med_shakthi/src/core/utils/smart_product_image.dart';
import 'package:med_shakthi/src/core/utils/custom_snackbar.dart';
import 'package:med_shakthi/src/features/products/data/models/product_model.dart';
import 'package:med_shakthi/src/features/products/presentation/screens/product_page.dart';
import 'package:med_shakthi/src/features/category/product_filter_sheet.dart';
import 'package:med_shakthi/src/features/category/b2b_product_filter.dart';

class GlobalSearchPage extends StatefulWidget {
  final B2BProductFilter? initialFilter;
  final String? initialSearchQuery;

  const GlobalSearchPage({
    super.key,
    this.initialFilter,
    this.initialSearchQuery,
  });

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> products = [];
  bool loading = false;
  final searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  B2BProductFilter? _currentFilter;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchQuery = widget.initialSearchQuery!;
      searchController.text = _searchQuery;
      _refreshProducts();
    }

    if (widget.initialFilter != null) {
      _currentFilter = widget.initialFilter;
      // If we have a filter, we might want to trigger a search immediately even without a query
      // providing _searchQuery is empty.
      _refreshProducts();
    }
    // Auto-focus the search bar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _refreshProducts() async {
    if (_searchQuery.isEmpty && _currentFilter == null) {
      if (mounted) setState(() => products = []);
      return;
    }

    setState(() => loading = true);

    try {
      dynamic query = supabase
          .from('products')
          .select('''
        *,
        suppliers!inner(name, supplier_code, id)
      ''')
          .eq('is_active', true);

      // Search Filter (Server-side)
      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'name.ilike.%$_searchQuery%,brand.ilike.%$_searchQuery%,category.ilike.%$_searchQuery%',
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
        setState(() {
          products = List<Map<String, dynamic>>.from(response);
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(
          context,
          'Failed to search products: $e',
          isError: true,
        );
        setState(() => loading = false);
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
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: TextField(
          controller: searchController,
          focusNode: _searchFocusNode,
          onChanged: applySearch,
          decoration: const InputDecoration(
            hintText: 'Search medicines, devices...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune,
              color: _currentFilter != null
                  ? const Color(0xff2b9c8f)
                  : Theme.of(context).iconTheme.color,
            ),
            onPressed: () async {
              final newFilter = await showModalBottomSheet<B2BProductFilter>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const ProductFilterSheet(),
              );
              if (newFilter != null) {
                setState(() => _currentFilter = newFilter);
                await _refreshProducts();
              }
            },
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: Theme.of(context).iconTheme.color),
              onPressed: () {
                searchController.clear();
                applySearch("");
              },
            ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xff2b9c8f)),
            )
          : products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).disabledColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Type to search products'
                        : 'No results found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final price =
                    double.tryParse(product['price']?.toString() ?? '0') ?? 0.0;
                return _buildProductCard(product, price);
              },
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
            category: product['category'] ?? "General",
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
          category: product['category'] ?? "General",
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
            if (product['expiry_date'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Expires: ${_formatExpiry(product['expiry_date'])}',
                  style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                ),
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
