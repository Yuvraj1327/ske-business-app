import 'package:equatable/equatable.dart';

class SettlementSheetSummary extends Equatable {
  final int totalItems;
  final int delivered;
  final int notDelivered;
  final int pending;
  final double totalInvoiceAmount;
  final double totalCollected;
  final double totalCreditOutstanding;

  const SettlementSheetSummary({
    required this.totalItems,
    required this.delivered,
    required this.notDelivered,
    required this.pending,
    required this.totalInvoiceAmount,
    required this.totalCollected,
    required this.totalCreditOutstanding,
  });

  factory SettlementSheetSummary.fromJson(Map<String, dynamic> json) {
    return SettlementSheetSummary(
      totalItems: json['total_items'] as int,
      delivered: json['delivered'] as int,
      notDelivered: json['not_delivered'] as int,
      pending: json['pending'] as int,
      totalInvoiceAmount: double.parse(json['total_invoice_amount'] as String),
      totalCollected: double.parse(json['total_collected'] as String),
      totalCreditOutstanding: double.parse(json['total_credit_outstanding'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [totalItems, delivered, notDelivered, pending, totalInvoiceAmount, totalCollected, totalCreditOutstanding];
}

class SettlementSheet extends Equatable {
  final String id;
  final String sheetNo;
  final DateTime sheetDate;
  final String deliveryAgentId;
  final String deliveryAgentName;
  final String salesmanId;
  final String salesmanName;
  final String status; // draft | in_progress | completed
  final String? notes;
  // General / reconciliation fields — manually entered by Admin.
  final String? pickSheetNo;
  final double pickSheetValue;
  final double returnsGoods;
  final double damageReturn;
  final double discount;
  final double cashAmount;
  final double onlineAmount;
  final double chequeAmount;
  final double creditBills;
  final double oldShort;
  final SettlementSheetSummary summary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SettlementSheet({
    required this.id,
    required this.sheetNo,
    required this.sheetDate,
    required this.deliveryAgentId,
    required this.deliveryAgentName,
    required this.salesmanId,
    required this.salesmanName,
    required this.status,
    this.notes,
    this.pickSheetNo,
    required this.pickSheetValue,
    required this.returnsGoods,
    required this.damageReturn,
    required this.discount,
    required this.cashAmount,
    required this.onlineAmount,
    required this.chequeAmount,
    required this.creditBills,
    required this.oldShort,
    required this.summary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SettlementSheet.fromJson(Map<String, dynamic> json) {
    return SettlementSheet(
      id: json['id'] as String,
      sheetNo: json['sheet_no'] as String,
      sheetDate: DateTime.parse(json['sheet_date'] as String),
      deliveryAgentId: json['delivery_agent_id'] as String,
      deliveryAgentName: json['delivery_agent_name'] as String,
      salesmanId: json['salesman_id'] as String,
      salesmanName: json['salesman_name'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      pickSheetNo: json['pick_sheet_no'] as String?,
      pickSheetValue: double.parse(json['pick_sheet_value'] as String),
      returnsGoods: double.parse(json['returns_goods'] as String),
      damageReturn: double.parse(json['damage_return'] as String),
      discount: double.parse(json['discount'] as String),
      cashAmount: double.parse(json['cash_amount'] as String),
      onlineAmount: double.parse(json['online_amount'] as String),
      chequeAmount: double.parse(json['cheque_amount'] as String),
      creditBills: double.parse(json['credit_bills'] as String),
      oldShort: double.parse(json['old_short'] as String),
      summary: SettlementSheetSummary.fromJson(json['summary'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        sheetNo,
        sheetDate,
        deliveryAgentId,
        deliveryAgentName,
        salesmanId,
        salesmanName,
        status,
        notes,
        pickSheetNo,
        pickSheetValue,
        returnsGoods,
        damageReturn,
        discount,
        cashAmount,
        onlineAmount,
        chequeAmount,
        creditBills,
        oldShort,
        summary,
        createdAt,
        updatedAt,
      ];
}

class SettlementSheetItem extends Equatable {
  final String id;
  final int rowNo;
  final String customerId;
  final String? customerCode;
  final String customerName;
  final double invoiceAmount;
  final String deliveryStatus; // pending | delivered | not_delivered
  final double cashAmount;
  final double onlineAmount;
  final double chequeAmount;
  final double totalCollected;
  final String? agentNotes;
  final double creditAmount;
  final double creditCollected;
  final double creditOutstanding;
  final String? salesmanNotes;
  final DateTime updatedAt;

  const SettlementSheetItem({
    required this.id,
    required this.rowNo,
    required this.customerId,
    this.customerCode,
    required this.customerName,
    required this.invoiceAmount,
    required this.deliveryStatus,
    required this.cashAmount,
    required this.onlineAmount,
    required this.chequeAmount,
    required this.totalCollected,
    this.agentNotes,
    required this.creditAmount,
    required this.creditCollected,
    required this.creditOutstanding,
    this.salesmanNotes,
    required this.updatedAt,
  });

  factory SettlementSheetItem.fromJson(Map<String, dynamic> json) {
    return SettlementSheetItem(
      id: json['id'] as String,
      rowNo: json['row_no'] as int,
      customerId: json['customer_id'] as String,
      customerCode: json['customer_code'] as String?,
      customerName: json['customer_name'] as String,
      invoiceAmount: double.parse(json['invoice_amount'] as String),
      deliveryStatus: json['delivery_status'] as String,
      cashAmount: double.parse(json['cash_amount'] as String),
      onlineAmount: double.parse(json['online_amount'] as String),
      chequeAmount: double.parse(json['cheque_amount'] as String),
      totalCollected: double.parse(json['total_collected'] as String),
      agentNotes: json['agent_notes'] as String?,
      creditAmount: double.parse(json['credit_amount'] as String),
      creditCollected: double.parse(json['credit_collected'] as String),
      creditOutstanding: double.parse(json['credit_outstanding'] as String),
      salesmanNotes: json['salesman_notes'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        rowNo,
        customerId,
        customerCode,
        customerName,
        invoiceAmount,
        deliveryStatus,
        cashAmount,
        onlineAmount,
        chequeAmount,
        totalCollected,
        agentNotes,
        creditAmount,
        creditCollected,
        creditOutstanding,
        salesmanNotes,
        updatedAt,
      ];
}

class SettlementSheetDetail extends SettlementSheet {
  final List<SettlementSheetItem> items;

  const SettlementSheetDetail({
    required super.id,
    required super.sheetNo,
    required super.sheetDate,
    required super.deliveryAgentId,
    required super.deliveryAgentName,
    required super.salesmanId,
    required super.salesmanName,
    required super.status,
    super.notes,
    super.pickSheetNo,
    required super.pickSheetValue,
    required super.returnsGoods,
    required super.damageReturn,
    required super.discount,
    required super.cashAmount,
    required super.onlineAmount,
    required super.chequeAmount,
    required super.creditBills,
    required super.oldShort,
    required super.summary,
    required super.createdAt,
    required super.updatedAt,
    required this.items,
  });

  factory SettlementSheetDetail.fromJson(Map<String, dynamic> json) {
    final base = SettlementSheet.fromJson(json);
    return SettlementSheetDetail(
      id: base.id,
      sheetNo: base.sheetNo,
      sheetDate: base.sheetDate,
      deliveryAgentId: base.deliveryAgentId,
      deliveryAgentName: base.deliveryAgentName,
      salesmanId: base.salesmanId,
      salesmanName: base.salesmanName,
      status: base.status,
      notes: base.notes,
      pickSheetNo: base.pickSheetNo,
      pickSheetValue: base.pickSheetValue,
      returnsGoods: base.returnsGoods,
      damageReturn: base.damageReturn,
      discount: base.discount,
      cashAmount: base.cashAmount,
      onlineAmount: base.onlineAmount,
      chequeAmount: base.chequeAmount,
      creditBills: base.creditBills,
      oldShort: base.oldShort,
      summary: base.summary,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      items: (json['items'] as List).map((e) => SettlementSheetItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// A single row while being built in the "New Settlement Sheet" form,
/// before it's ever sent to the API — holds the resolved Customer alongside
/// the two entered amounts.
class DraftSettlementRow extends Equatable {
  final String customerId;
  final String? customerCode;
  final String customerName;
  final double invoiceAmount;
  final double creditAmount;

  const DraftSettlementRow({
    required this.customerId,
    this.customerCode,
    required this.customerName,
    required this.invoiceAmount,
    required this.creditAmount,
  });

  @override
  List<Object?> get props => [customerId, customerCode, customerName, invoiceAmount, creditAmount];
}
