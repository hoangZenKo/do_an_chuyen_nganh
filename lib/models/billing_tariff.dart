class BillingTariffTier {
  const BillingTariffTier({this.upTo, required this.unitPrice});

  final int? upTo;
  final int unitPrice;

  factory BillingTariffTier.fromJson(Map<String, dynamic> json) {
    return BillingTariffTier(
      upTo: _intOrNull(json['upTo']),
      unitPrice: _int(json['unitPrice']),
    );
  }

  Map<String, dynamic> toJson() => {
        'upTo': upTo,
        'unitPrice': unitPrice,
      };
}

class BillingTariffVersion {
  const BillingTariffVersion({
    required this.id,
    required this.propertyId,
    this.roomId,
    required this.serviceKey,
    required this.name,
    required this.kind,
    required this.unit,
    required this.amount,
    required this.isActive,
    required this.effectiveFrom,
    required this.version,
    required this.state,
    this.makerId,
    this.checkerId,
    this.reason,
    this.reviewReason,
    this.reviewedAt,
    this.tiers = const [],
  });

  final String id;
  final String propertyId;
  final String? roomId;
  final String serviceKey;
  final String name;
  final String kind;
  final String unit;
  final int amount;
  final bool isActive;
  final DateTime? effectiveFrom;
  final int version;
  final String state;
  final String? makerId;
  final String? checkerId;
  final String? reason;
  final String? reviewReason;
  final DateTime? reviewedAt;
  final List<BillingTariffTier> tiers;

  bool get isProposed => state.toUpperCase() == 'PROPOSED';
  bool get isApproved => state.toUpperCase() == 'APPROVED';
  bool get isRejected => state.toUpperCase() == 'REJECTED';
  bool get isUtility => kind.toUpperCase() != 'SERVICE';

  factory BillingTariffVersion.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawTiers = data['tiers'];
    return BillingTariffVersion(
      id: data['id'] as String? ?? '',
      propertyId: data['propertyId'] as String? ?? '',
      roomId: data['roomId'] as String?,
      serviceKey: data['serviceKey'] as String? ?? '',
      name: data['name'] as String? ?? '',
      kind: data['kind'] as String? ?? 'SERVICE',
      unit: data['unit'] as String? ?? 'tháng',
      amount: _int(data['amount']),
      isActive: data['isActive'] != false,
      effectiveFrom: _date(data['effectiveFrom']),
      version: _int(data['version']),
      state: data['state'] as String? ?? 'PROPOSED',
      makerId: data['makerId'] as String?,
      checkerId: data['checkerId'] as String?,
      reason: data['reason'] as String?,
      reviewReason: data['reviewReason'] as String?,
      reviewedAt: _date(data['reviewedAt']),
      tiers: rawTiers is List
          ? rawTiers
              .whereType<Map<String, dynamic>>()
              .map(BillingTariffTier.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}

class BillingTariffRoomImpact {
  const BillingTariffRoomImpact({required this.id, required this.name});

  final String id;
  final String name;

  factory BillingTariffRoomImpact.fromJson(Map<String, dynamic> json) {
    return BillingTariffRoomImpact(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Phòng',
    );
  }
}

class BillingTariffImpact {
  const BillingTariffImpact({
    required this.proposed,
    this.previous,
    required this.rooms,
    required this.issuedInvoices,
    required this.lockedPeriods,
    required this.canApprove,
    this.overriddenRooms = const [],
    this.blockingReasons = const [],
  });

  final BillingTariffVersion proposed;
  final BillingTariffVersion? previous;
  final List<BillingTariffRoomImpact> rooms;
  final int issuedInvoices;
  final int lockedPeriods;
  final bool canApprove;
  final List<BillingTariffRoomImpact> overriddenRooms;
  final List<String> blockingReasons;

  factory BillingTariffImpact.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawRooms = data['rooms'];
    return BillingTariffImpact(
      proposed: BillingTariffVersion.fromJson(
        (data['proposed'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      previous: data['previous'] is Map
          ? BillingTariffVersion.fromJson(
              (data['previous'] as Map).cast<String, dynamic>(),
            )
          : null,
      rooms: rawRooms is List
          ? rawRooms
              .whereType<Map<String, dynamic>>()
              .map(BillingTariffRoomImpact.fromJson)
              .toList(growable: false)
          : const [],
      issuedInvoices: _int(data['issuedInvoices']),
      lockedPeriods: _int(data['lockedPeriods']),
      canApprove: data['canApprove'] == true,
      overriddenRooms: (data['overriddenRooms'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BillingTariffRoomImpact.fromJson)
          .toList(growable: false),
      blockingReasons: (data['blockingReasons'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  return _int(value);
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}
