import 'package:flutter/material.dart';

enum ExpenseCategory {
  repair,
  utilities,
  internet,
  cleaning,
  furniture,
  salary,
  tax,
  other;

  String get label => switch (this) {
        ExpenseCategory.repair => 'Sửa chữa',
        ExpenseCategory.utilities => 'Điện nước tổng',
        ExpenseCategory.internet => 'Internet',
        ExpenseCategory.cleaning => 'Vệ sinh',
        ExpenseCategory.furniture => 'Nội thất',
        ExpenseCategory.salary => 'Lương quản lý',
        ExpenseCategory.tax => 'Thuế/phí',
        ExpenseCategory.other => 'Khác',
      };

  IconData get icon => switch (this) {
        ExpenseCategory.repair => Icons.home_repair_service_rounded,
        ExpenseCategory.utilities => Icons.bolt_rounded,
        ExpenseCategory.internet => Icons.wifi_rounded,
        ExpenseCategory.cleaning => Icons.cleaning_services_rounded,
        ExpenseCategory.furniture => Icons.chair_rounded,
        ExpenseCategory.salary => Icons.badge_rounded,
        ExpenseCategory.tax => Icons.receipt_rounded,
        ExpenseCategory.other => Icons.more_horiz_rounded,
      };

  static ExpenseCategory fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return ExpenseCategory.values.firstWhere(
      (category) => category.name == raw,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class ExpenseSummary {
  const ExpenseSummary({required this.totalAmount, required this.count});

  final int totalAmount;
  final int count;

  factory ExpenseSummary.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const ExpenseSummary(totalAmount: 0, count: 0);
    }
    return ExpenseSummary(
      totalAmount: _int(json['totalAmount']),
      count: _int(json['count']),
    );
  }
}

class ExpenseListResult {
  const ExpenseListResult({required this.items, required this.summary});

  final List<Expense> items;
  final ExpenseSummary summary;

  factory ExpenseListResult.fromJson(Object? json) {
    if (json is List) {
      return ExpenseListResult(
        items: json
            .whereType<Map<String, dynamic>>()
            .map(Expense.fromJson)
            .toList(growable: false),
        summary: ExpenseSummary(totalAmount: 0, count: json.length),
      );
    }
    if (json is! Map<String, dynamic>) {
      return const ExpenseListResult(
        items: [],
        summary: ExpenseSummary(totalAmount: 0, count: 0),
      );
    }
    final raw = json['data'] is List ? json['data'] as List : const [];
    return ExpenseListResult(
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(Expense.fromJson)
          .toList(growable: false),
      summary: ExpenseSummary.fromJson(json['summary']),
    );
  }
}

class Expense {
  const Expense({
    required this.id,
    required this.propertyId,
    required this.category,
    required this.amount,
    required this.expenseDate,
    required this.title,
    this.propertyName,
    this.roomId,
    this.roomName,
    this.note,
    this.receiptUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String? propertyName;
  final String? roomId;
  final String? roomName;
  final ExpenseCategory category;
  final int amount;
  final DateTime? expenseDate;
  final String title;
  final String? note;
  final String? receiptUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Expense.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return Expense(
      id: data['id'] as String,
      propertyId: data['propertyId'] as String? ?? '',
      propertyName: data['propertyName'] as String?,
      roomId: data['roomId'] as String?,
      roomName: data['roomName'] as String?,
      category: ExpenseCategory.fromWire(data['category']),
      amount: _int(data['amount']),
      expenseDate: _date(data['expenseDate']),
      title: data['title'] as String? ?? 'Chi phí',
      note: data['note'] as String?,
      receiptUrl: data['receiptUrl'] as String?,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
