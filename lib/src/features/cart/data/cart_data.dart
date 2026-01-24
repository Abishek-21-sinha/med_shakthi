import 'package:flutter/material.dart';
import 'cart_item.dart';


class CartData extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get subTotal =>
      _items.fold(0, (t, i) => t + i.price * i.quantity);

  void addItem(CartItem item) {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void increment(int index) {
    _items[index].quantity++;
    notifyListeners();
  }

  void decrement(int index) {
    if (_items[index].quantity > 1) {
      _items[index].quantity--;
      notifyListeners();
    }
  }

  void remove(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    items.clear();
    notifyListeners();
  }
}
