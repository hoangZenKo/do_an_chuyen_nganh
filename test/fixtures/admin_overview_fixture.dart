Map<String, dynamic> adminOverviewFixture(
    {int days = 30, bool finance = true}) {
  final today = DateTime.utc(2026, 10, 27);
  final trends = [
    for (var index = 0; index < days; index++)
      {
        'day': today
            .subtract(Duration(days: days - index - 1))
            .toIso8601String()
            .substring(0, 10),
        'accounts': index % 5 + 1,
        'properties': index % 4 == 0 ? 1 : 0,
        'rooms': index % 3 == 0 ? 4 : 1,
        'listings': index % 2,
        if (finance) ...{
          'rentalCollected': 1600000 + index % 7 * 250000,
          'rentalReversed': index == days - 1 ? 1200000 : 0,
          'rentalNet':
              1600000 + index % 7 * 250000 - (index == days - 1 ? 1200000 : 0),
        }
      }
  ];
  int sum(String key) =>
      trends.fold<int>(0, (total, row) => total + (row[key] as int? ?? 0));
  Map<String, dynamic> growth(int current, int previous) => {
        'current': current,
        'previous': previous,
        'changePercent':
            previous == 0 ? null : (current - previous) / previous.abs() * 100,
      };
  return {
    'data': {
      'generatedAt': '2026-10-27T12:00:00Z',
      'timezone': 'Asia/Ho_Chi_Minh',
      'days': days,
      'period': {
        'from': today
            .subtract(Duration(days: days - 1, hours: 7))
            .toIso8601String(),
        'to': '2026-10-27T12:00:00Z',
        'previousFrom': today
            .subtract(Duration(days: days * 2 - 1, hours: 7))
            .toIso8601String(),
        'previousTo': today
            .subtract(Duration(days: days - 1, hours: 7))
            .toIso8601String(),
        'comparison': 'PREVIOUS_FULL_PERIOD',
      },
      'accounts': {
        'total': 1284,
        'active': 1210,
        'inactive': 74,
        'landlords': 356,
        'tenants': 812,
        'staff': 114,
        'admins': 2
      },
      'properties': {'total': 356, 'active': 348, 'archived': 8},
      'rooms': {
        'total': 400,
        'occupied': 312,
        'vacant': 80,
        'maintenance': 8,
        'occupancyRate': .78
      },
      'growth': {
        'accounts': growth(sum('accounts'), sum('accounts') - 8),
        'properties': growth(sum('properties'), sum('properties') - 1),
        'rooms': growth(sum('rooms'), sum('rooms') - 2),
      },
      if (finance)
        'finance': {
          'currency': 'VND',
          'rentalCollected': sum('rentalCollected'),
          'rentalReversed': sum('rentalReversed'),
          'rentalNet': sum('rentalNet'),
          'expenses': 7200000,
          'outstandingSnapshot': 12000000,
          'failedPayments': 2,
          'platformRevenue': {
            'available': false,
            'amount': null,
            'reason': 'SUBSCRIPTION_BILLING_NOT_IMPLEMENTED'
          },
          'rentalGrowth': growth(sum('rentalNet'), sum('rentalNet') - 4000000),
        },
      'trends': trends,
    }
  };
}
