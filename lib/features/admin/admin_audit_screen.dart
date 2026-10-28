import 'package:flutter/material.dart';
import 'admin_workspace_screen.dart';

class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({super.key, this.initialFilters = const {}});
  final Map<String, String> initialFilters;
  @override
  Widget build(BuildContext context) =>
      AdminWorkspaceScreen(section: 'audit', initialFilters: initialFilters);
}
