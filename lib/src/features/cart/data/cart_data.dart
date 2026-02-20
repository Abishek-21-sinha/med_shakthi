import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_item.dart';

class CartData extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _isLoading = true;

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;

  double get subTotal => _items.fold(0, (t, i) => t + i.price * i.quantity);

  double get selectedSubTotal => _items
      .where((item) => item.isSelected)
      .fold(0, (sum, item) => sum + item.price * item.quantity);

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _cartStreamSubscription;

  CartData() {
    _init();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _init(); // Re-init on login to load user cart
      } else if (event == AuthChangeEvent.signedOut) {
        _clearStateOnLogout(); // Clear on logout
      }
    });
  }

  Future<void> _init() async {
    _isLoading = true;
    // notifyListeners(); // Avoid notifying during build if called from constructor
    await _loadLocalCart();
    _isLoading = false;
    notifyListeners();
    _syncWithRemote();
  }

  void _clearStateOnLogout() {
    _items = [];
    _cartStreamSubscription?.cancel();
    _cartStreamSubscription = null;
    notifyListeners();
    // Optionally load guest cart here if you support it
    _loadLocalCart();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cartStreamSubscription?.cancel();
    super.dispose();
  }

  // --- LOCAL STORAGE (SharedPreferences) ---

  Future<void> _loadLocalCart() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      // If no user, fallback to generic 'local_cart' or just empty
      final String key = user != null ? 'cart_${user.id}' : 'local_cart';

      final prefs = await SharedPreferences.getInstance();
      final String? cartJson = prefs.getString(key);
      if (cartJson != null) {
        final List<dynamic> decodedList = jsonDecode(cartJson);
        _items = decodedList.map((e) => CartItem.fromMap(e)).toList();
      } else {
        _items = [];
      }
    } catch (e) {
      debugPrint("Error loading local cart: $e");
    }
  }

  Future<void> _saveLocalCart() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final String key = user != null ? 'cart_${user.id}' : 'local_cart';

      final prefs = await SharedPreferences.getInstance();
      final String cartJson = jsonEncode(_items.map((e) => e.toMap()).toList());
      await prefs.setString(key, cartJson);
    } catch (e) {
      debugPrint("Error saving local cart: $e");
    }
  }

  // --- REMOTE SYNC (Supabase) ---

  Future<void> _syncWithRemote() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final supabase = Supabase.instance.client;

      // 1. Listen to Realtime Changes
      // 1. Listen to Realtime Changes
      _cartStreamSubscription?.cancel();
      _cartStreamSubscription = supabase
          .from('cart_items')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .listen((List<Map<String, dynamic>> data) {
            _items = data.map((e) {
              return CartItem(
                id: e['product_id'] ?? e['id'], // Handle schema variations
                name: e['name'] ?? 'Unknown',
                price: (e['price'] as num).toDouble(),
                imagePath: e['image'],
                quantity: e['quantity'] ?? 1,
                isSelected: true,
              );
            }).toList();
            _saveLocalCart();
            notifyListeners();
          });

      // Initial fetch is handled by the stream immediately
    } catch (e) {
      debugPrint("Error syncing cart: $e");
    }
  }

  Future<void> _addToRemote(CartItem item) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Upsert
      await Supabase.instance.client.from('cart_items').upsert({
        'user_id': user.id,
        'product_id': item.id, // Assuming CartItem.id is product_id
        'quantity': item.quantity,
        'name': item.name,
        'price': item.price,
        'image': item.imagePath ?? item.imageUrl,
      }, onConflict: 'user_id, product_id');
    } catch (e) {
      debugPrint("Error adding to remote: $e");
    }
  }

  Future<void> _removeFromRemote(String itemId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('cart_items')
          .delete()
          .eq('user_id', user.id)
          .eq('product_id', itemId); // Assuming id corresponds to product_id
    } catch (e) {
      debugPrint("Error removing from remote: $e");
    }
  }

  // --- PUBLIC METHODS ---

  Future<void> addItem(CartItem item) async {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(item);
    }
    notifyListeners();
    _saveLocalCart();
    _addToRemote(index != -1 ? _items[index] : item);
  }

  Future<void> increment(int index) async {
    _items[index].quantity++;
    notifyListeners();
    _saveLocalCart();
    _addToRemote(_items[index]);
  }

  Future<void> decrement(int index) async {
    if (_items[index].quantity > 1) {
      _items[index].quantity--;
      notifyListeners();
      _saveLocalCart();
      _addToRemote(_items[index]);
    }
  }

  Future<void> remove(int index) async {
    final item = _items[index];
    _items.removeAt(index);
    notifyListeners();
    _saveLocalCart();
    _removeFromRemote(item.id);
  }

  Future<void> clearCart() async {
    _items.clear();
    notifyListeners();
    _saveLocalCart();
    // Optional: Clear remote too? Usually yes.
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client
          .from('cart_items')
          .delete()
          .eq('user_id', user.id);
    }
  }

  void toggleSelection(int index, bool value) {
    _items[index].isSelected = value;
    notifyListeners();
    _saveLocalCart();
  }

  // New method for logout
  Future<void> clearLocalStateOnly() async {
    _items.clear();
    notifyListeners();
    // Do not delete from DB, just clear memory and maybe local storage ref
    // But local storage is keyed by user ID, so next login won't see it anyway.
    // We can explicitly remove the file if we want to be clean.
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cart_${user.id}');
    }
  }
}
