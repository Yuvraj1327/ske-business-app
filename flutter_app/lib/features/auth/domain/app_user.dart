import 'package:equatable/equatable.dart';

/// The authenticated user's app-domain profile, as returned by
/// GET /auth/me. This is the source of truth for role/permissions in the UI —
/// never inferred from the Supabase JWT directly.
class AppUser extends Equatable {
  final String id;
  final String fullName;
  final String roleName;
  final bool isActive;
  final Set<String> permissions;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.roleName,
    required this.isActive,
    required this.permissions,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      roleName: json['role_name'] as String,
      isActive: json['is_active'] as bool,
      permissions: Set<String>.from(json['permissions'] as List? ?? []),
    );
  }

  bool get isAdmin => roleName == 'admin';

  bool hasPermission(String key) => permissions.contains(key);

  @override
  List<Object?> get props => [id, fullName, roleName, isActive, permissions];
}
