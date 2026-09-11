import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';

/// Convenience provider for UI-level permission checks — e.g. hiding a
/// "Delete Customer" button if the user lacks `customers.delete`.
///
/// IMPORTANT: this only controls what's shown in the UI. The real
/// enforcement always happens server-side in FastAPI (see
/// app/core/permissions.py). Never rely on this alone for security.
final hasPermissionProvider = Provider.family<bool, String>((ref, permissionKey) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;
  if (user.isAdmin) return true;
  return user.hasPermission(permissionKey);
});
