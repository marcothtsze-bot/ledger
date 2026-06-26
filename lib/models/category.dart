/// A spending/income category. Immutable, pure Dart.
///
/// [icon] is a Material Symbols Rounded ligature name (e.g. `restaurant`); the
/// UI maps it to a concrete glyph. [color] is a hex string resolved by the UI.
class Category {
  final String id;
  final String name;
  final String color;
  final String icon;

  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });
}
