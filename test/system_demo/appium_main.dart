import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_driver/flutter_driver.dart' show SerializableFinder;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart' as testing;

import 'package:rental_room_management/app/app.dart';
import 'package:rental_room_management/core/config/api_config.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/data/auth/secure_session_storage.dart';

final _caption = ValueNotifier<String>('KIEM THU TU DONG - DU LIEU THU');
final _errors = <String>[];
late ProviderContainer _container;

void main() {
  final backend = Uri.parse(ApiConfig.baseUrl);
  if (kReleaseMode ||
      !const bool.fromEnvironment('SYSTEM_DEMO') ||
      !['localhost', '127.0.0.1'].contains(backend.host) ||
      backend.port == 3000) {
    throw StateError('Demo requires a debug build and a separate local API.');
  }
  enableFlutterDriverExtension(
    finders: [_DemoFinderExtension()],
    handler: _handle,
  );
  FilePicker.platform = _DemoFilePicker();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _errors.add(details.exceptionAsString());
    previous?.call(details);
  };
  _container = ProviderContainer(overrides: [
    secureStorageProvider.overrideWithValue(SecureSessionStorage(
        storage: const FlutterSecureStorage(
            iOptions: IOSOptions(accountName: 'rental.system.demo')))),
  ]);
  runApp(UncontrolledProviderScope(
    container: _container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        const RentalRoomApp(),
        Positioned(
          top: 48,
          left: 12,
          right: 12,
          child: IgnorePointer(
            child: ValueListenableBuilder<String>(
              valueListenable: _caption,
              builder: (_, text, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: const Color(0xE61E3A5F),
                child: Text(text,
                    key: const ValueKey('system-demo-caption'),
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        decoration: TextDecoration.none)),
              ),
            ),
          ),
        ),
      ]),
    ),
  ));
}

Future<String> _handle(String? raw) async {
  final input = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
  switch (input['action']) {
    case 'route':
      final path = input['path'] as String;
      if (!path.startsWith('/') || path.startsWith('//')) {
        throw ArgumentError('Only internal app routes are allowed.');
      }
      final router = _container.read(appRouterProvider);
      router.routerDelegate.navigatorKey.currentState
          ?.popUntil((route) => route.settings is Page || route.isFirst);
      router.go(path);
      break;
    case 'caption':
      _caption.value = input['text'] as String;
      break;
    case 'resetSession':
      await _container.read(sessionControllerProvider.notifier).logout();
      break;
    case 'snapshot':
      final texts = testing.find
          .byType(Text)
          .evaluate()
          .where((element) =>
              element.widget.key != const ValueKey('system-demo-caption'))
          .map((element) {
        final text = element.widget as Text;
        return text.data ?? text.textSpan?.toPlainText() ?? '';
      }).toList();
      final fields = testing.find.byType(TextField).evaluate().map((element) {
        final field = element.widget as TextField;
        return {
          'label': field.decoration?.labelText,
          'hint': field.decoration?.hintText,
          'readOnly': field.readOnly,
          'obscure': field.obscureText,
        };
      }).toList();
      texts
          .addAll(testing.find.byType(SelectableText).evaluate().map((element) {
        final text = element.widget as SelectableText;
        return text.data ?? text.textSpan?.toPlainText() ?? '';
      }));
      return jsonEncode({
        'route': _container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .toString(),
        'apiBaseUrl': ApiConfig.baseUrl,
        'sessionRole':
            _container.read(sessionControllerProvider).session?.user.role,
        'texts': texts,
        'fields': fields,
        'errors': List<String>.from(_errors),
      });
    case 'clearErrors':
      _errors.clear();
      break;
    case 'matches':
      final finder = _DemoFinderExtension().createTarget(_DemoFinder(
          input['kind'] as String,
          input['value'] as String,
          input['index'] as int? ?? 0));
      return jsonEncode({'count': finder.evaluate().length});
    default:
      throw ArgumentError('Unsupported demo command.');
  }
  return jsonEncode({'ok': true});
}

class _DemoFinder extends SerializableFinder {
  const _DemoFinder(this.kind, this.value, this.index);
  final String kind;
  final String value;
  final int index;

  @override
  String get finderType => 'DemoFinder';

  @override
  Map<String, String> serialize() => {
        ...super.serialize(),
        'kind': kind,
        'value': value,
        'index': '$index',
      };
}

class _DemoFinderExtension extends FinderExtension {
  @override
  String get finderType => 'DemoFinder';

  @override
  SerializableFinder deserialize(
          Map<String, String> params, DeserializeFinderFactory finderFactory) =>
      _DemoFinder(
          params['kind']!, params['value']!, int.parse(params['index']!));

  @override
  testing.Finder createFinder(
      SerializableFinder finder, CreateFinderFactory finderFactory) {
    return createTarget(finder as _DemoFinder);
  }

  testing.Finder createTarget(_DemoFinder target) {
    final candidates = testing.find.byElementPredicate((element) {
      final widget = element.widget;
      switch (target.kind) {
        case 'Text':
        case 'Contains':
        case 'ButtonText':
          if (widget is! Text && widget is! SelectableText) return false;
          if (widget.key == const ValueKey('system-demo-caption')) return false;
          final text = widget is Text
              ? widget.data ?? widget.textSpan?.toPlainText() ?? ''
              : (widget as SelectableText).data ??
                  widget.textSpan?.toPlainText() ??
                  '';
          if (target.kind == 'ButtonText') {
            if (text != target.value) return false;
            var inButton = false;
            element.visitAncestorElements((ancestor) {
              if (ancestor.widget is ButtonStyleButton) inButton = true;
              return !inButton;
            });
            return inButton;
          }
          return target.kind == 'Text'
              ? text == target.value
              : text.contains(target.value);
        case 'Field':
          if (widget is! TextField) return false;
          if (widget.decoration?.labelText == target.value ||
              widget.decoration?.hintText == target.value) {
            return true;
          }
          var matches = false;
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget is Column) {
              ancestor.visitChildElements((child) {
                child.visitChildElements((label) {
                  final text = label.widget;
                  if (text is Text && text.data == target.value) matches = true;
                });
                final text = child.widget;
                if (text is Text && text.data == target.value) matches = true;
              });
              return false;
            }
            return true;
          });
          return matches;
        case 'Tooltip':
          return widget is Tooltip && widget.message == target.value;
        case 'Type':
          return widget.runtimeType.toString() == target.value;
        case 'VerticalScrollable':
          if (widget is! Scrollable ||
              ![AxisDirection.down, AxisDirection.up]
                  .contains(widget.axisDirection)) {
            return false;
          }
          var insideEditor = false;
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget is EditableText) insideEditor = true;
            return !insideEditor;
          });
          return !insideEditor;
        default:
          throw ArgumentError('Unsupported finder kind.');
      }
    });
    return _SafeIndexFinder(candidates, target.index);
  }
}

class _SafeIndexFinder extends testing.Finder {
  _SafeIndexFinder(this.parent, this.index);
  final testing.Finder parent;
  final int index;

  @override
  String get description => 'Demo target at $index';

  @override
  Iterable<Element> findInCandidates(Iterable<Element> candidates) {
    final matches = parent.findInCandidates(candidates);
    return index < 0
        ? matches.toList().reversed.take(1)
        : matches.skip(index).take(1);
  }
}

class _DemoFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j5t8AAAAASUVORK5CYII=');
    final file = File('${Directory.systemTemp.path}/DEMO-only.png');
    await file.writeAsBytes(bytes);
    return FilePickerResult([
      PlatformFile(
          name: 'DEMO-only.png',
          size: bytes.length,
          path: file.path,
          bytes: bytes),
    ]);
  }
}
