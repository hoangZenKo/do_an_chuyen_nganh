import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Id of the property currently scoped in landlord-facing property screens.
final selectedPropertyProvider = StateProvider<String?>((ref) => null);
