import 'package:flutter/material.dart';
import 'admin_workspace_screen.dart';

class AdminModerationScreen extends StatelessWidget {
  const AdminModerationScreen({super.key, this.initialFilters = const {}});
  final Map<String, String> initialFilters;
  @override
  Widget build(BuildContext context) => AdminWorkspaceScreen(
      section: 'moderation', initialFilters: initialFilters);
}
