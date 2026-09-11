import 'package:equatable/equatable.dart';

class AppRole extends Equatable {
  final String id;
  final String name;
  final String? description;
  final List<String> permissionKeys;

  const AppRole({
    required this.id,
    required this.name,
    required this.description,
    required this.permissionKeys,
  });

  factory AppRole.fromJson(Map<String, dynamic> json) {
    return AppRole(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      permissionKeys: List<String>.from(json['permission_keys'] as List? ?? []),
    );
  }

  @override
  List<Object?> get props => [id, name, description, permissionKeys];
}

class AppPermission extends Equatable {
  final String id;
  final String key;
  final String module;
  final String? description;

  const AppPermission({
    required this.id,
    required this.key,
    required this.module,
    required this.description,
  });

  factory AppPermission.fromJson(Map<String, dynamic> json) {
    return AppPermission(
      id: json['id'] as String,
      key: json['key'] as String,
      module: json['module'] as String,
      description: json['description'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, key, module, description];
}
