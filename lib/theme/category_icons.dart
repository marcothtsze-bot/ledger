import 'package:flutter/widgets.dart';

import 'icon_catalog.dart';

/// Maps a Material Symbols Rounded ligature name to a concrete [IconData].
/// Backed by [kIconCatalog] so account icons, category icons, and any
/// user-chosen glyph all resolve through one table.
IconData symbolFor(String ligature) => iconFor(ligature);
