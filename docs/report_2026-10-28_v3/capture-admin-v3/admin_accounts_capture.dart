import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const adminAccountsCaptureKey = ValueKey('admin-accounts-qa');

Future<void> loadAdminAccountsCaptureFonts() async {
  if (Platform.environment['ADMIN_QA_OUTPUT'] == null) return;
  await (FontLoader('Roboto')
        ..addFont(File('assets/fonts/Manrope-VariableFont_wght.ttf')
            .readAsBytes()
            .then(ByteData.sublistView)))
      .load();
  for (final family in ['Ahem', 'Arial', '.SF UI Text', '.SF UI Display']) {
    await (FontLoader(family)..addFont(File('assets/fonts/Manrope-VariableFont_wght.ttf').readAsBytes().then(ByteData.sublistView))).load();
  }
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
}

Future<void> captureAdminAccounts(WidgetTester tester, String name) async {
  final output = Platform.environment['ADMIN_QA_OUTPUT'];
  if (output == null) return;
  await tester.runAsync(() async {
    await Directory(output).create(recursive: true);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(adminAccountsCaptureKey));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
