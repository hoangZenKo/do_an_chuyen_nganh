const _incidentChoices = {
  'status': ['OPEN', 'ACKNOWLEDGED', 'SNOOZED', 'RESOLVED'],
  'severity': ['WARNING', 'CRITICAL'],
  'assignment': ['all', 'mine', 'unassigned'],
  'window': ['all', '24h', '7d', '30d'],
};

const _supportChoices = {
  'status': ['OPEN', 'IN_PROGRESS', 'WAITING_FOR_USER', 'RESOLVED', 'CLOSED'],
  'assignment': ['all', 'mine', 'unassigned', 'overdue'],
  'sla': ['all', 'overdue', 'due_soon', 'paused'],
  'priority': ['LOW', 'NORMAL', 'HIGH', 'URGENT'],
  'category': [
    'GENERAL',
    'BILLING',
    'LEASE',
    'MAINTENANCE',
    'ACCOUNT',
    'SAFETY'
  ],
  'sort': ['recent', 'oldest', 'resolution_due'],
};

Map<String, String> adminInboxFilters(Map<String, String> query,
    {required bool incidents}) {
  final choices = incidents ? _incidentChoices : _supportChoices;
  final result = <String, String>{
    for (final entry in choices.entries)
      if (entry.value.contains(query[entry.key])) entry.key: query[entry.key]!,
  };
  final search = query['search']?.trim();
  if (search != null && search.isNotEmpty && search.length <= 100) {
    result['search'] = search;
  }
  if (!incidents) {
    for (final key in ['teamId', 'assigneeId']) {
      final value = query[key];
      if (value != null &&
          RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
              .hasMatch(value)) {
        result[key] = value;
      }
    }
    final label = query['label'];
    if (label != null && label.isNotEmpty && label.length <= 32) {
      result['label'] = label;
    }
  }
  return result;
}
