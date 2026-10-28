import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../../../models/room.dart';

Color roomSceneColor(Room room, bool overdue) => overdue
    ? const Color(0xFFE8324A)
    : switch (room.status) {
        RoomStatus.occupied => const Color(0xFF00A77F),
        RoomStatus.vacant => const Color(0xFFA9B4C7),
        RoomStatus.maintenance => const Color(0xFFF58B16),
      };

class RoomFloorScene extends StatelessWidget {
  const RoomFloorScene({
    super.key,
    required this.rooms,
    required this.overdueIds,
    required this.selectedId,
    required this.onSelected,
  }) : assert(rooms.length <= 7);

  final List<Room> rooms;
  final Set<String> overdueIds;
  final String selectedId;
  final ValueChanged<String> onSelected;

  static const imageAsset =
      'assets/images/atrium_floorplan_scene_reference.png';
  static const referenceSize = Size(821, 671);
  static const labelBounds = [
    Rect.fromLTWH(165, 410, 178, 88),
    Rect.fromLTWH(445, 477, 146, 88),
    Rect.fromLTWH(617, 349, 180, 88),
    Rect.fromLTWH(390, 208, 168, 92),
    Rect.fromLTWH(76, 145, 180, 87),
    Rect.fromLTWH(242, 9, 178, 88),
    Rect.fromLTWH(620, 53, 143, 89),
  ];
  static const roomOutlines = [
    [Offset(101, 452), Offset(251, 335), Offset(412, 429), Offset(255, 556)],
    [Offset(401, 551), Offset(578, 412), Offset(747, 509), Offset(571, 649)],
    [Offset(510, 382), Offset(675, 275), Offset(813, 365), Offset(649, 484)],
    [Offset(304, 319), Offset(393, 211), Offset(554, 302), Offset(420, 419)],
    [Offset(0, 247), Offset(184, 118), Offset(341, 208), Offset(172, 344)],
    [Offset(229, 108), Offset(430, 0), Offset(541, 66), Offset(366, 204)],
    [Offset(437, 175), Offset(583, 67), Offset(737, 151), Offset(590, 266)],
  ];

  static int? hitRoom(Offset referencePosition, int roomCount) {
    for (var index = roomCount - 1; index >= 0; index--) {
      if ((Path()..addPolygon(roomOutlines[index], true))
          .contains(referencePosition)) {
        return index;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: AspectRatio(
            aspectRatio: referenceSize.aspectRatio,
            child: LayoutBuilder(builder: (context, constraints) {
              final scale = constraints.maxWidth / referenceSize.width;
              return Stack(key: const ValueKey('floor-3d-viewport'), children: [
                Positioned.fill(
                    child: GestureDetector(
                  onTapUp: (details) {
                    final index =
                        hitRoom(details.localPosition / scale, rooms.length);
                    if (index != null) onSelected(rooms[index].id);
                  },
                  child: Image.asset(imageAsset,
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                      filterQuality: FilterQuality.high),
                )),
                Positioned.fill(
                    child: IgnorePointer(
                        child: CustomPaint(
                  painter: _RoomHighlights(
                      rooms: rooms,
                      overdueIds: overdueIds,
                      selectedId: selectedId),
                ))),
                for (var index = 0; index < labelBounds.length; index++)
                  Positioned(
                    left: labelBounds[index].left * scale,
                    top: labelBounds[index].top * scale,
                    width: math.max(68, labelBounds[index].width * scale),
                    height: math.max(44, labelBounds[index].height * scale),
                    child: _RoomLabel(
                      room: index < rooms.length ? rooms[index] : null,
                      overdue: index < rooms.length &&
                          overdueIds.contains(rooms[index].id),
                      selected:
                          index < rooms.length && rooms[index].id == selectedId,
                      onTap: index < rooms.length
                          ? () => onSelected(rooms[index].id)
                          : null,
                      scale: scale,
                    ),
                  ),
              ]);
            }),
          ),
        ),
      );
}

class _RoomLabel extends StatelessWidget {
  const _RoomLabel(
      {required this.room,
      required this.overdue,
      required this.selected,
      required this.onTap,
      required this.scale});
  final Room? room;
  final bool overdue;
  final bool selected;
  final VoidCallback? onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final current = room;
    final status = current == null
        ? 'Vị trí minh họa'
        : overdue
            ? 'Quá hạn'
            : current.status.label;
    final color = current == null
        ? const Color(0xFFBCC3CD)
        : roomSceneColor(current, overdue);
    final background = overdue ? const Color(0xFFFFF6F5) : Colors.white;
    return Semantics(
      button: current != null,
      selected: selected,
      label: current == null
          ? 'Vị trí minh họa chưa gán phòng'
          : '${current.name}, $status, ${formatCurrencyVnd(current.basePrice)}',
      child: ExcludeSemantics(
          child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
            left: 18 * scale,
            bottom: -3 * scale,
            child: Transform.rotate(
                angle: math.pi / 4,
                child: SizedBox(
                    width: 14 * scale,
                    height: 14 * scale,
                    child: ColoredBox(color: background)))),
        Positioned.fill(
            child: Material(
          color: background,
          elevation: selected ? 5 : 2,
          shadowColor: const Color(0x44102039),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20 * scale),
              side: selected
                  ? BorderSide(color: color, width: 1.2)
                  : BorderSide.none),
          child: InkWell(
            borderRadius: BorderRadius.circular(20 * scale),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale, vertical: 5 * scale),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Icon(Icons.circle, size: 9, color: color)),
                      const SizedBox(width: 5),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(current?.name ?? 'Chưa gán',
                                style: TextStyle(
                                    color: overdue
                                        ? const Color(0xFFCE1832)
                                        : const Color(0xFF102039),
                                    fontSize: (27 * scale).clamp(12, 22),
                                    height: 1.2,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 1),
                            Text(
                                current == null ||
                                        overdue ||
                                        current.status != RoomStatus.occupied
                                    ? status
                                    : formatCurrencyVnd(current.basePrice),
                                style: TextStyle(
                                    color: overdue
                                        ? const Color(0xFFE8324A)
                                        : const Color(0xFF52617B),
                                    fontSize: (21 * scale).clamp(10, 17),
                                    height: 1.2)),
                          ]),
                    ]),
              ),
            ),
          ),
        )),
      ])),
    );
  }
}

class _RoomHighlights extends CustomPainter {
  const _RoomHighlights(
      {required this.rooms,
      required this.overdueIds,
      required this.selectedId});
  final List<Room> rooms;
  final Set<String> overdueIds;
  final String selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / RoomFloorScene.referenceSize.width);
    for (var index = 0; index < rooms.length; index++) {
      final overdue = overdueIds.contains(rooms[index].id);
      if (!overdue && rooms[index].id != selectedId) continue;
      final color = overdue ? const Color(0xFFFF203D) : const Color(0xFF00A77F);
      final path = Path()..addPolygon(RoomFloorScene.roomOutlines[index], true);
      if (overdue) {
        canvas.drawPath(
            path,
            Paint()
              ..color = color.withValues(alpha: .65)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: .24));
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = overdue ? 5 : 3);
      if (overdue) {
        canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xFFFFDDE3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoomHighlights oldDelegate) =>
      oldDelegate.rooms != rooms ||
      oldDelegate.overdueIds != overdueIds ||
      oldDelegate.selectedId != selectedId;
}
