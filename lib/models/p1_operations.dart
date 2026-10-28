import 'package:flutter/material.dart';

enum TurnoverStage { returned, inspection, repair, cleaning, ready }

extension TurnoverStageX on TurnoverStage {
  String get wire => name.toUpperCase();
  String get label => switch (this) {
        TurnoverStage.returned => 'Đã trả phòng',
        TurnoverStage.inspection => 'Kiểm tra',
        TurnoverStage.repair => 'Sửa chữa',
        TurnoverStage.cleaning => 'Vệ sinh',
        TurnoverStage.ready => 'Sẵn sàng cho thuê',
      };
  IconData get icon => switch (this) {
        TurnoverStage.returned => Icons.key_off_rounded,
        TurnoverStage.inspection => Icons.fact_check_rounded,
        TurnoverStage.repair => Icons.build_rounded,
        TurnoverStage.cleaning => Icons.cleaning_services_rounded,
        TurnoverStage.ready => Icons.check_circle_rounded,
      };
  static TurnoverStage parse(Object? value) => TurnoverStage.values.firstWhere(
        (stage) => stage.wire == value?.toString().toUpperCase(),
        orElse: () => TurnoverStage.returned,
      );
}

class TurnoverStep {
  const TurnoverStep(
      {required this.stage, required this.title, this.completedAt, this.note});
  final TurnoverStage stage;
  final String title;
  final DateTime? completedAt;
  final String? note;
  factory TurnoverStep.fromJson(Map<String, dynamic> json) => TurnoverStep(
        stage: TurnoverStageX.parse(json['stage']),
        title: json['title'] as String? ?? '',
        completedAt: _date(json['completedAt']),
        note: json['note'] as String?,
      );
}

class RoomTurnover {
  const RoomTurnover(
      {required this.id,
      required this.roomId,
      required this.roomName,
      required this.stage,
      required this.status,
      required this.version,
      this.propertyName,
      this.steps = const []});
  final String id;
  final String roomId;
  final String roomName;
  final String? propertyName;
  final TurnoverStage stage;
  final String status;
  final int version;
  final List<TurnoverStep> steps;
  factory RoomTurnover.fromJson(Map<String, dynamic> json) => RoomTurnover(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        roomName: (json['room'] as Map<String, dynamic>?)?['name'] as String? ??
            'Phòng',
        propertyName:
            (json['property'] as Map<String, dynamic>?)?['name'] as String?,
        stage: TurnoverStageX.parse(json['stage']),
        status: json['status']?.toString().toLowerCase() ?? 'active',
        version: _int(json['version']),
        steps: (json['steps'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(TurnoverStep.fromJson)
                .toList(growable: false) ??
            const [],
      );
}

class OperationTask {
  const OperationTask(
      {required this.id,
      required this.title,
      required this.kind,
      required this.dueAt,
      required this.version,
      required this.status,
      this.roomName,
      this.checklist = const []});
  final String id;
  final String title;
  final String kind;
  final DateTime dueAt;
  final int version;
  final String status;
  final String? roomName;
  final List<ChecklistItem> checklist;
  factory OperationTask.fromJson(Map<String, dynamic> json) => OperationTask(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        dueAt: _date(json['dueAt']) ?? DateTime.now(),
        version: _int(json['version']),
        status: json['status']?.toString().toLowerCase() ?? 'pending',
        roomName: (json['room'] as Map<String, dynamic>?)?['name'] as String?,
        checklist: (json['checklist'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(ChecklistItem.fromJson)
                .toList(growable: false) ??
            const [],
      );
}

class ChecklistItem {
  const ChecklistItem({required this.title, required this.done});
  final String title;
  final bool done;
  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
      title: json['title'] as String? ?? '', done: json['done'] == true);
}

class AnnouncementItem {
  const AnnouncementItem(
      {required this.id,
      required this.title,
      required this.body,
      required this.status,
      required this.sendAt,
      this.readAt,
      this.recipientCount = 0,
      this.readCount = 0});
  final String id;
  final String title;
  final String body;
  final String status;
  final DateTime sendAt;
  final DateTime? readAt;
  final int recipientCount;
  final int readCount;
  bool get isRead => readAt != null;
  factory AnnouncementItem.fromJson(Map<String, dynamic> json) =>
      AnnouncementItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        status: json['status']?.toString().toLowerCase() ?? 'scheduled',
        recipientCount: (json['recipients'] as List?)?.length ?? 0,
        readCount: (json['recipients'] as List?)
                ?.where((item) => item is Map && item['readAt'] != null)
                .length ??
            0,
        sendAt: _date(json['sendAt'] ?? json['sentAt']) ?? DateTime.now(),
        readAt: _date(
            (json['recipients'] as List?)?.firstOrNull is Map<String, dynamic>
                ? ((json['recipients'] as List).first
                    as Map<String, dynamic>)['readAt']
                : json['readAt']),
      );
}

class PaymentLinkInfo {
  const PaymentLinkInfo(
      {required this.status,
      this.provider = 'DEMO_CARD',
      this.demo = true,
      this.invoiceIsDemo = false,
      this.canCreateDemoInvoice = false,
      this.unavailableReason,
      this.checkoutUrl,
      this.qrCode,
      this.amount,
      this.expiresAt,
      this.bankBin,
      this.accountName,
      this.accountNumber,
      this.description,
      this.invoiceStatus,
      this.paidAmount,
      this.remainingAmount,
      this.reviewRequired = false,
      this.canPay = false,
      this.canCreateLink = false});
  final String status;
  final String provider;
  final bool demo;
  final bool invoiceIsDemo;
  final bool canCreateDemoInvoice;
  final String? unavailableReason;
  final String? checkoutUrl;
  final String? qrCode;
  final int? amount;
  final DateTime? expiresAt;
  final String? bankBin;
  final String? accountName;
  final String? accountNumber;
  final String? description;
  final String? invoiceStatus;
  final int? paidAmount;
  final int? remainingAmount;
  final bool reviewRequired;
  final bool canPay;
  final bool canCreateLink;
  bool get invoicePaid =>
      invoiceStatus == 'paid' ||
      (remainingAmount == 0 && invoiceStatus != 'cancelled');
  bool get invoiceCancelled => invoiceStatus == 'cancelled';
  factory PaymentLinkInfo.fromJson(Map<String, dynamic> json) =>
      PaymentLinkInfo(
          status: json['status']?.toString().toLowerCase() ?? 'pending',
          provider: json['provider']?.toString() ?? 'DEMO_CARD',
          demo: json['demo'] == true,
          invoiceIsDemo:
              (json['invoice'] as Map<String, dynamic>?)?['isDemo'] == true,
          canCreateDemoInvoice: json['canCreateDemoInvoice'] == true,
          unavailableReason: json['unavailableReason'] as String?,
          checkoutUrl: json['checkoutUrl'] as String?,
          qrCode: json['qrCode'] as String?,
          amount: _nullableInt(json['amount']),
          expiresAt: _date(json['expiresAt']),
          bankBin: json['bankBin'] as String?,
          accountName: json['accountName'] as String?,
          accountNumber: json['accountNumber'] as String?,
          description: json['description'] as String?,
          invoiceStatus: (json['invoice'] as Map<String, dynamic>?)?['status']
              ?.toString()
              .toLowerCase(),
          paidAmount: _nullableInt(
              (json['invoice'] as Map<String, dynamic>?)?['paidAmount']),
          remainingAmount: _nullableInt(
              (json['invoice'] as Map<String, dynamic>?)?['remainingAmount']),
          reviewRequired: json['reviewRequired'] == true,
          canPay: json['canPay'] == true,
          canCreateLink: json['canCreateLink'] == true);
}

class P1Page<T> {
  const P1Page({required this.items, required this.total, required this.page});
  final List<T> items;
  final int total;
  final int page;
  bool get hasNext => page * 20 < total;
}

class RecurringOperation {
  const RecurringOperation(
      {required this.id,
      required this.title,
      required this.frequency,
      required this.nextRunAt,
      required this.isEnabled});
  final String id;
  final String title;
  final String frequency;
  final DateTime nextRunAt;
  final bool isEnabled;
  factory RecurringOperation.fromJson(Map<String, dynamic> json) =>
      RecurringOperation(
          id: json['id'] as String,
          title: json['title'] as String,
          frequency: json['frequency'] as String,
          nextRunAt: DateTime.parse(json['nextRunAt'] as String),
          isEnabled: json['isEnabled'] == true);
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
int? _nullableInt(Object? value) => value == null ? null : _int(value);
