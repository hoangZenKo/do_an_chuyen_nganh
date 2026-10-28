import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

/// Id of the property currently scoped in landlord-facing property screens.
final selectedPropertyProvider = StateProvider<String?>((ref) {
  ref.watch(sessionIdentityProvider);
  return null;
});
