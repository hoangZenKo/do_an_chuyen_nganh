import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'admin_workspace_flow_test.dart' as workspace;
import 'admin_accounts_panel_test.dart' as accounts;
import 'admin_account_detail_panel_test.dart' as detail;
import 'admin_inventory_panel_test.dart' as inventory;

void main() {
  workspace.main();
  accounts.main();
  detail.main();
  inventory.main();
  tearDownAll(() {
    Timer(const Duration(seconds: 2), () => exit(0));
  });
}
