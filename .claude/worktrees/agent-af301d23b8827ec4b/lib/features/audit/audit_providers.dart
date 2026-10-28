import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audit/audit_api.dart';
import '../../data/audit/audit_repository.dart';
import '../../models/audit_log.dart';
import '../auth/auth_providers.dart';

final auditApiProvider = Provider<AuditApi>((ref) {
  return AuditApi(ref.watch(dioProvider));
});

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepository(ref.watch(auditApiProvider));
});

final auditLogsProvider = FutureProvider<List<AuditLog>>((ref) {
  return ref.watch(auditRepositoryProvider).list();
});
