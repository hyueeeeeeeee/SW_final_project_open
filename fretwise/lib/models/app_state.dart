import 'package:flutter/material.dart';
import '../theme.dart';

class AppState extends ChangeNotifier {
  bool _darkMode = false;
  int _coins = 340;
  Set<String> _ownedItems = {'streak_shield_1'};

  bool get darkMode => _darkMode;
  Color get accent => AppColors.accent;
  int get coins => _coins;
  Set<String> get ownedItems => Set.unmodifiable(_ownedItems);

  AppTheme get theme => AppTheme(isDark: _darkMode);

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    notifyListeners();
  }

  void setCoins(int value) {
    _coins = value;
    notifyListeners();
  }

  void spendCoins(int amount) {
    _coins -= amount;
    notifyListeners();
  }

  void addOwnedItem(String id) {
    _ownedItems = {..._ownedItems, id};
    notifyListeners();
  }

  bool ownsItem(String id) => _ownedItems.contains(id);
}
