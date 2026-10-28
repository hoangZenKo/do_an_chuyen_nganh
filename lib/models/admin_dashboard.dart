class AdminMetricGrowth {
  const AdminMetricGrowth(this.current, this.previous, this.changePercent);
  final int current, previous;
  final double? changePercent;

  factory AdminMetricGrowth.fromJson(Map<String, dynamic> json) =>
      AdminMetricGrowth(_integer(json['current']), _integer(json['previous']),
          (json['changePercent'] as num?)?.toDouble());
}

class AdminDailyTrend {
  const AdminDailyTrend(
      {required this.day,
      required this.accounts,
      required this.properties,
      required this.rooms,
      required this.listings,
      this.rentalCollected,
      this.rentalReversed,
      this.rentalNet});
  final DateTime day;
  final int accounts, properties, rooms, listings;
  final int? rentalCollected, rentalReversed, rentalNet;

  factory AdminDailyTrend.fromJson(Map<String, dynamic> json) =>
      AdminDailyTrend(
          day: DateTime.parse('${json['day']}'),
          accounts: _integer(json['accounts']),
          properties: _integer(json['properties']),
          rooms: _integer(json['rooms']),
          listings: _integer(json['listings']),
          rentalCollected: (json['rentalCollected'] as num?)?.toInt(),
          rentalReversed: (json['rentalReversed'] as num?)?.toInt(),
          rentalNet: (json['rentalNet'] as num?)?.toInt());

  int valueFor(String metric) => switch (metric) {
        'properties' => properties,
        'rooms' => rooms,
        'rentalNet' => rentalNet ?? 0,
        _ => accounts,
      };
}

class AdminDashboardFinance {
  AdminDashboardFinance.fromJson(Map<String, dynamic> json)
      : collected = _integer(json['rentalCollected']),
        reversed = _integer(json['rentalReversed']),
        net = _integer(json['rentalNet']),
        expenses = _integer(json['expenses']),
        outstanding = _integer(json['outstandingSnapshot']),
        failedPayments = _integer(json['failedPayments']),
        platformRevenue = (json['platformRevenue'] is Map &&
                (json['platformRevenue'] as Map)['available'] == true)
            ? ((json['platformRevenue'] as Map)['amount'] as num?)?.toInt()
            : null,
        growth = AdminMetricGrowth.fromJson(_map(json['rentalGrowth']));
  final int collected, reversed, net, expenses, outstanding, failedPayments;
  final int? platformRevenue;
  final AdminMetricGrowth growth;
}

class AdminDashboardData {
  AdminDashboardData.fromJson(Map<String, dynamic> response) {
    final data = _map(response['data']);
    if (data['accounts'] is! Map ||
        data['properties'] is! Map ||
        data['rooms'] is! Map ||
        data['growth'] is! Map ||
        data['trends'] is! List) {
      throw const FormatException('Invalid admin overview response');
    }
    generatedAt = DateTime.parse('${data['generatedAt']}');
    days = _integer(data['days']);
    final period = _map(data['period']);
    from = DateTime.parse('${period['from']}');
    to = DateTime.parse('${period['to']}');
    accounts = _map(data['accounts']);
    properties = _map(data['properties']);
    rooms = _map(data['rooms']);
    growth = _map(data['growth']).map(
        (key, value) => MapEntry(key, AdminMetricGrowth.fromJson(_map(value))));
    finance = data['finance'] is Map
        ? AdminDashboardFinance.fromJson(_map(data['finance']))
        : null;
    trends = (data['trends'] as List)
        .whereType<Map>()
        .map((row) => AdminDailyTrend.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
  late final DateTime generatedAt, from, to;
  late final int days;
  late final Map<String, dynamic> accounts, properties, rooms;
  late final Map<String, AdminMetricGrowth> growth;
  late final AdminDashboardFinance? finance;
  late final List<AdminDailyTrend> trends;
  int get accountTotal => _integer(accounts['total']);
  int get propertyTotal => _integer(properties['total']);
  int get roomTotal => _integer(rooms['total']);
  int get occupied => _integer(rooms['occupied']);
  double? get occupancyRate => (rooms['occupancyRate'] as num?)?.toDouble();
}

int _integer(Object? value) => (value as num?)?.toInt() ?? 0;
Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
