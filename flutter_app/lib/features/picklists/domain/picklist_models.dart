import 'package:equatable/equatable.dart';

class PicklistCounts extends Equatable {
  final int total;
  final int pending;
  final int cash;
  final int online;
  final int credit;

  const PicklistCounts({
    required this.total,
    required this.pending,
    required this.cash,
    required this.online,
    required this.credit,
  });

  factory PicklistCounts.fromJson(Map<String, dynamic> json) {
    return PicklistCounts(
      total: json['total'] as int,
      pending: json['pending'] as int,
      cash: json['cash'] as int,
      online: json['online'] as int,
      credit: json['credit'] as int,
    );
  }

  @override
  List<Object?> get props => [total, pending, cash, online, credit];
}

class Picklist extends Equatable {
  final String id;
  final String picklistNo;
  final String deliveryAgentId;
  final String deliveryAgentName;
  final String? psrRoute;
  final double totalAmount;
  final DateTime createdAt;
  final PicklistCounts counts;

  const Picklist({
    required this.id,
    required this.picklistNo,
    required this.deliveryAgentId,
    required this.deliveryAgentName,
    this.psrRoute,
    required this.totalAmount,
    required this.createdAt,
    required this.counts,
  });

  factory Picklist.fromJson(Map<String, dynamic> json) {
    return Picklist(
      id: json['id'] as String,
      picklistNo: json['picklist_no'] as String,
      deliveryAgentId: json['delivery_agent_id'] as String,
      deliveryAgentName: json['delivery_agent_name'] as String,
      psrRoute: json['psr_route'] as String?,
      totalAmount: double.parse(json['total_amount'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      counts: PicklistCounts.fromJson(json['counts'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props =>
      [id, picklistNo, deliveryAgentId, deliveryAgentName, psrRoute, totalAmount, createdAt, counts];
}

class PicklistItem extends Equatable {
  final String id;
  final int rowNo;
  final String invoiceNumber;
  final String? customerCode;
  final String customerName;
  final String? salesmanLabel;
  final double amountPayable;
  final String? customerId;
  final String? saleId;
  final String status; // pending | cash | online | credit
  final DateTime? collectedAt;

  const PicklistItem({
    required this.id,
    required this.rowNo,
    required this.invoiceNumber,
    this.customerCode,
    required this.customerName,
    this.salesmanLabel,
    required this.amountPayable,
    this.customerId,
    this.saleId,
    required this.status,
    this.collectedAt,
  });

  factory PicklistItem.fromJson(Map<String, dynamic> json) {
    return PicklistItem(
      id: json['id'] as String,
      rowNo: json['row_no'] as int,
      invoiceNumber: json['invoice_number'] as String,
      customerCode: json['customer_code'] as String?,
      customerName: json['customer_name'] as String,
      salesmanLabel: json['salesman_label'] as String?,
      amountPayable: double.parse(json['amount_payable'] as String),
      customerId: json['customer_id'] as String?,
      saleId: json['sale_id'] as String?,
      status: json['status'] as String,
      collectedAt: json['collected_at'] != null ? DateTime.parse(json['collected_at'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        rowNo,
        invoiceNumber,
        customerCode,
        customerName,
        salesmanLabel,
        amountPayable,
        customerId,
        saleId,
        status,
        collectedAt,
      ];
}

class PicklistDetail extends Picklist {
  final List<PicklistItem> items;

  const PicklistDetail({
    required super.id,
    required super.picklistNo,
    required super.deliveryAgentId,
    required super.deliveryAgentName,
    super.psrRoute,
    required super.totalAmount,
    required super.createdAt,
    required super.counts,
    required this.items,
  });

  factory PicklistDetail.fromJson(Map<String, dynamic> json) {
    final base = Picklist.fromJson(json);
    return PicklistDetail(
      id: base.id,
      picklistNo: base.picklistNo,
      deliveryAgentId: base.deliveryAgentId,
      deliveryAgentName: base.deliveryAgentName,
      psrRoute: base.psrRoute,
      totalAmount: base.totalAmount,
      createdAt: base.createdAt,
      counts: base.counts,
      items: (json['items'] as List).map((e) => PicklistItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
