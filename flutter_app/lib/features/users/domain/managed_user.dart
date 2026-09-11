import 'package:equatable/equatable.dart';

/// A row in the admin's Users management list. Distinct from
/// `features/auth/domain/app_user.dart`'s `AppUser`, which represents the
/// *currently logged-in* user's session profile — this one represents any
/// user record an admin is viewing/editing.
class ManagedUser extends Equatable {
  final String id;
  final String fullName;
  final String? phone;
  final String roleId;
  final String roleName;
  final bool isActive;
  final DateTime createdAt;

  const ManagedUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.roleId,
    required this.roleName,
    required this.isActive,
    required this.createdAt,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      roleId: json['role_id'] as String,
      roleName: json['role_name'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, fullName, phone, roleId, roleName, isActive, createdAt];
}
