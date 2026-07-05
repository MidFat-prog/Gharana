import 'package:flutter/material.dart';

/// Maps category names to icons/colors, including user-defined custom
/// categories (registered at runtime by AppState from persisted storage).
class CatHelper {
  // Curated choices a user can pick from when creating a custom category.
  // Stored as indices (not raw IconData/Color) so they persist safely and
  // survive icon tree-shaking.
  static const List<IconData> iconChoices = [
    Icons.category_rounded,
    Icons.shopping_cart_rounded,
    Icons.fastfood_rounded,
    Icons.pets_rounded,
    Icons.build_rounded,
    Icons.fitness_center_rounded,
    Icons.flight_rounded,
    Icons.local_hospital_rounded,
    Icons.celebration_rounded,
    Icons.savings_rounded,
    Icons.sports_esports_rounded,
    Icons.child_care_rounded,
    Icons.spa_rounded,
    Icons.directions_car_rounded,
    Icons.book_rounded,
    Icons.card_giftcard_rounded,
    Icons.local_cafe_rounded,
    Icons.water_drop_rounded,
  ];

  static const List<Color> colorChoices = [
    Color(0xFF6B8F71),
    Color(0xFFD4A853),
    Color(0xFFB85C38),
    Color(0xFF8B6BAE),
    Color(0xFF4A90D9),
    Color(0xFFD4607A),
    Color(0xFF4AB8C1),
    Color(0xFFD4845A),
    Color(0xFFC47A9E),
    Color(0xFF6B82AE),
  ];

  // Populated at runtime by AppState from the persisted custom-category list.
  static final Map<String, int> _customIconIdx  = {};
  static final Map<String, int> _customColorIdx = {};

  static void registerCustom(String name, int iconIndex, int colorIndex) {
    _customIconIdx[name]  = iconIndex.clamp(0, iconChoices.length - 1);
    _customColorIdx[name] = colorIndex.clamp(0, colorChoices.length - 1);
  }

  static void unregisterCustom(String name) {
    _customIconIdx.remove(name);
    _customColorIdx.remove(name);
  }

  static void clearCustom() {
    _customIconIdx.clear();
    _customColorIdx.clear();
  }

  static bool isCustom(String name) => _customIconIdx.containsKey(name);

  static IconData icon(String cat) {
    if (_customIconIdx.containsKey(cat)) return iconChoices[_customIconIdx[cat]!];
    switch (cat) {
      case 'Ration':       return Icons.shopping_basket_rounded;
      case 'Bijli Bill':   return Icons.bolt_rounded;
      case 'Gas Bill':     return Icons.local_fire_department_rounded;
      case 'Rickshaw':     return Icons.electric_rickshaw_rounded;
      case 'School Fee':   return Icons.school_rounded;
      case 'Medicine':     return Icons.medical_services_rounded;
      case 'Internet':     return Icons.wifi_rounded;
      case 'Salary':       return Icons.account_balance_wallet_rounded;
      case 'Freelance':    return Icons.laptop_rounded;
      case 'Mobile Credit':return Icons.sim_card_rounded;
      case 'Clothes':      return Icons.checkroom_rounded;
      case 'Eating Out':   return Icons.restaurant_rounded;
      case 'Petrol':       return Icons.local_gas_station_rounded;
      case 'Rent':         return Icons.home_rounded;
      default:             return Icons.receipt_long_rounded;
    }
  }

  static Color color(String cat) {
    if (_customColorIdx.containsKey(cat)) return colorChoices[_customColorIdx[cat]!];
    switch (cat) {
      case 'Ration':       return const Color(0xFF6B8F71);
      case 'Bijli Bill':   return const Color(0xFFD4A853);
      case 'Gas Bill':     return const Color(0xFFB85C38);
      case 'Rickshaw':     return const Color(0xFF8B6BAE);
      case 'School Fee':   return const Color(0xFF4A90D9);
      case 'Medicine':     return const Color(0xFFD4607A);
      case 'Internet':     return const Color(0xFF4AB8C1);
      case 'Salary':       return const Color(0xFF6B8F71);
      case 'Freelance':    return const Color(0xFF5A9E6F);
      case 'Mobile Credit':return const Color(0xFFD4845A);
      case 'Clothes':      return const Color(0xFFC47A9E);
      case 'Eating Out':   return const Color(0xFFD4A053);
      case 'Petrol':       return const Color(0xFF8C7B6B);
      case 'Rent':         return const Color(0xFF6B82AE);
      default:             return const Color(0xFF8C7B6B);
    }
  }
}
