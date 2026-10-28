import 'dart:io';
import 'dart:ui' as reportUi;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
final reportKey = GlobalKey();
int reportCount=0;
bool reportFonts=false;
Future<void> reportPumpWidget(WidgetTester tester, Widget widget) async {
  if (!reportFonts) {
    await tester.runAsync(() async {
    await (FontLoader('Roboto')..addFont(File('/Users/hoang/Rental_room_management/assets/fonts/Manrope-VariableFont_wght.ttf').readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    reportFonts=true;
    });
  }
  await tester.pumpWidget(RepaintBoundary(key:reportKey, child:widget));
}
Future<void> reportCapture(WidgetTester tester, String prefix) async {
  await tester.runAsync(() async {
    if (reportKey.currentContext == null) return;
    final boundary=reportKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    if (boundary.debugNeedsPaint) return;
    final image=await boundary.toImage(pixelRatio:1.5);
    final bytes=await image.toByteData(format:reportUi.ImageByteFormat.png);
    await File('/tmp/rental-report-v2-20261028/ui-v2/${prefix}_${(++reportCount).toString().padLeft(3,'0')}.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
