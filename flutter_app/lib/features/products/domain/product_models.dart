import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String? sku;
  final String unit;
  final double defaultPrice;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    this.sku,
    required this.unit,
    required this.defaultPrice,
    required this.isActive,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      unit: json['unit'] as String,
      defaultPrice: double.parse(json['default_price'] as String),
      isActive: json['is_active'] as bool,
    );
  }

  @override
  List<Object?> get props => [id, name, sku, unit, defaultPrice, isActive];
}
