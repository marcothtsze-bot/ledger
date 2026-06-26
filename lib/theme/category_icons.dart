import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Maps the design's Material Symbols Rounded ligature names to concrete
/// [IconData] from the material_symbols_icons package.
IconData symbolFor(String ligature) {
  switch (ligature) {
    case 'restaurant':
      return Symbols.restaurant;
    case 'shopping_cart':
      return Symbols.shopping_cart;
    case 'local_cafe':
      return Symbols.local_cafe;
    case 'directions_bus':
      return Symbols.directions_bus;
    case 'local_gas_station':
      return Symbols.local_gas_station;
    case 'shopping_bag':
      return Symbols.shopping_bag;
    case 'home':
      return Symbols.home;
    case 'bolt':
      return Symbols.bolt;
    case 'wifi':
      return Symbols.wifi;
    case 'subscriptions':
      return Symbols.subscriptions;
    case 'movie':
      return Symbols.movie;
    case 'flight':
      return Symbols.flight;
    case 'ecg_heart':
      return Symbols.ecg_heart;
    case 'fitness_center':
      return Symbols.fitness_center;
    case 'school':
      return Symbols.school;
    case 'redeem':
      return Symbols.redeem;
    case 'pets':
      return Symbols.pets;
    case 'child_care':
      return Symbols.child_care;
    case 'savings':
      return Symbols.savings;
    case 'payments':
      return Symbols.payments;
    default:
      return Symbols.help;
  }
}
