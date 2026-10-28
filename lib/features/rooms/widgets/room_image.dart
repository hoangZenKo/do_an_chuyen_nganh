import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/uploads/upload_api.dart';
import '../../auth/auth_providers.dart';

import '../../../models/room.dart';

class RoomImageCatalog {
  const RoomImageCatalog._();

  static const presetImages = [
    'assets/images/rooms/room_01.jpeg',
    'assets/images/rooms/room_02.jpeg',
    'assets/images/rooms/room_03.jpeg',
    'assets/images/rooms/room_04.jpeg',
    'assets/images/rooms/room_05.jpeg',
    'assets/images/rooms/room_06.jpeg',
    'assets/images/rooms/room_07.jpeg',
    'assets/images/rooms/room_08.jpeg',
    'assets/images/rooms/room_09.jpeg',
    'assets/images/rooms/room_10.jpeg',
    'assets/images/rooms/room_11.jpeg',
  ];

  static String? imageFor(Room room) {
    final explicit = room.imageUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return defaultImageFor(room);
  }

  static List<String> galleryFor(Room room) {
    final featured = imageFor(room);
    final images = <String>[
      if (featured != null && featured.isNotEmpty) featured,
      ...presetImages,
    ];
    return images.toSet().toList(growable: false);
  }

  static String defaultImageFor(Room room) {
    final key = '${room.id}:${room.name}';
    return defaultImageForKey(key);
  }

  static String defaultImageForKey(String key) {
    return presetImages[_stableIndex(key, presetImages.length)];
  }

  static bool isAsset(String source) => source.startsWith('assets/');

  static int _stableIndex(String value, int length) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash % length;
  }
}

final _privateImageProvider = FutureProvider.autoDispose.family<String, String>(
    (ref, url) =>
        UploadApi(ref.watch(sessionDioProvider).client).accessUrl(url));

class RoomImageView extends ConsumerWidget {
  const RoomImageView({
    super.key,
    required this.source,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });

  final String? source;
  final Widget placeholder;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = source?.trim();
    if (path == null || path.isEmpty) return placeholder;

    if (RoomImageCatalog.isAsset(path)) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    if (Uri.tryParse(path)?.path.startsWith('/uploads/') == true) {
      return ref.watch(_privateImageProvider(path)).when(
            data: (url) => Image.network(url,
                fit: fit, errorBuilder: (_, __, ___) => placeholder),
            loading: () => placeholder,
            error: (_, __) => placeholder,
          );
    }
    return Image.network(
      path,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
