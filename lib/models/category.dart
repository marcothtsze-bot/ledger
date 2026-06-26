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

  /// Returns a new Category with the given fields replaced (immutable update).
  Category copyWith({String? name, String? color, String? icon}) => Category(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    icon: icon ?? this.icon,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'color': color,
    'icon': icon,
  };

  factory Category.fromMap(Map<String, Object?> m) => Category(
    id: m['id'] as String,
    name: m['name'] as String,
    color: m['color'] as String,
    icon: m['icon'] as String,
  );
}
