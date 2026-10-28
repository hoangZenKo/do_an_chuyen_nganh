import '../../models/audit_log.dart';
import 'audit_api.dart';

class AuditRepository {
  const AuditRepository(this._api);

  final AuditApi _api;

  Future<List<AuditLog>> list({int take = 80}) => _api.list(take: take);
}
