import 'package:equatable/equatable.dart';

class PicklistCounts extends Equatable {
  final int total;
  final int pending;
  final int cash;
  final int online;
  final int credit;
  final int cheque;

  const PicklistCounts({
    required this.total,
    required this.pending,
    required this.cash,
    required this.online,
    required this.credit,
    this.cheque = 0,
  });

  factory PicklistCounts.fromJson(Map<String, dynamic> json) {
    return PicklistCounts(
      total: json['total'] as int,
      pending: json['pending'] as int,
      cash: json['cash'] as int,
      online: json['online'] as int,
      credit: json['credit'] as int,
      cheque: json['cheque'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [total, pending, cash, online, credit, cheque];
}

class Picklist extends Equatable {
  final String id;
  final String picklistNo;
  final String deliveryAgentId;
  final String deliveryAgentName;
  final String? psrRoute;
  final double totalAmount;
  final double chequeTotal; // sum of cheque amounts entered on this picklist's rows
  final DateTime createdAt;
  final PicklistCounts counts;

  const Picklist({
    required this.id,
    required this.picklistNo,
    required this.deliveryAgentId,
    required this.deliveryAgentName,
    this.psrRoute,
    required this.totalAmount,
    this.chequeTotal = 0,
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
      chequeTotal: double.parse(json['cheque_total'] as String? ?? '0'),
      createdAt: DateTime.parse(json['created_at'] as String),
      counts: PicklistCounts.fromJson(json['counts'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props =>
      [id, picklistNo, deliveryAgentId, deliveryAgentName, psrRoute, totalAmount, chequeTotal, createdAt, counts];
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
  final String status; // pending | cash | online | credit | cheque
  final double chequeAmount; // only non-zero when status == 'cheque'
  final String? creditSalesmanId; // Salesman chosen to handle a Credit row
  final String? creditSalesmanName;
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
    this.chequeAmount = 0,
    this.creditSalesmanId,
    this.creditSalesmanName,
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
      chequeAmount: double.parse(json['cheque_amount'] as String? ?? '0'),
      creditSalesmanId: json['credit_salesman_id'] as String?,
      creditSalesmanName: json['credit_salesman_name'] as String?,
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
        chequeAmount,
        creditSalesmanId,
        creditSalesmanName,
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
    super.chequeTotal,
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
      chequeTotal: base.chequeTotal,
      createdAt: base.createdAt,
      counts: base.counts,
      items: (json['items'] as List).map((e) => PicklistItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
