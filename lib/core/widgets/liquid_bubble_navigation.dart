import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

double liquidTaskbarBottomPadding(
  BuildContext context, {
  double extra = 16,
}) {
  final insets =
      context.dependOnInheritedWidgetOfExactType<_LiquidTaskbarScrollInsets>();
  return (insets?.bottomInset ?? MediaQuery.paddingOf(context).bottom) + extra;
}

class LiquidTaskbarScrollScope extends StatelessWidget {
  const LiquidTaskbarScrollScope({
    super.key,
    required this.child,
    this.additionalClearance = 0,
  });

  final Widget child;
  final double additionalClearance;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return _LiquidTaskbarScrollInsets(
      bottomInset: (media.viewInsets.bottom > 0 ? 0 : media.padding.bottom) +
          additionalClearance,
      child: child,
    );
  }
}

class _LiquidTaskbarScrollInsets extends InheritedWidget {
  const _LiquidTaskbarScrollInsets({
    required this.bottomInset,
    required super.child,
  });

  final double bottomInset;

  @override
  bool updateShouldNotify(_LiquidTaskbarScrollInsets oldWidget) =>
      oldWidget.bottomInset != bottomInset;
}

class LiquidNavigationItem {
  const LiquidNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isAction = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isAction;
}

class LiquidBubbleNavigation extends StatefulWidget {
  const LiquidBubbleNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.backgroundColor = Colors.white,
    this.bubbleColor,
    this.activeColor = const Color(0xFFFF385C),
    this.inactiveColor = const Color(0xFF717171),
    this.height = 64,
    this.borderRadius = BorderRadius.zero,
    this.centerAction,
    this.centerGap = 58,
  })  : assert(items.length >= 2),
        assert(selectedIndex >= 0 && selectedIndex < items.length);

  final List<LiquidNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color backgroundColor;
  final Color? bubbleColor;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final BorderRadius borderRadius;
  final Widget? centerAction;
  final double centerGap;

  @override
  State<LiquidBubbleNavigation> createState() => _LiquidBubbleNavigationState();
}

class _LiquidBubbleNavigationState extends State<LiquidBubbleNavigation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );
  bool _dragging = false;
  bool _reduceMotion = false;

  int get _centerGapAfter => widget.items.length ~/ 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion && !_dragging) {
      _position.value = widget.selectedIndex.toDouble();
    }
  }

  @override
  void didUpdateWidget(covariant LiquidBubbleNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.items.length != widget.items.length) {
      _dragging = false;
      _settle();
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _settle() {
    final target = widget.selectedIndex.toDouble();
    if (_reduceMotion) {
      _position.value = target;
      return;
    }
    _position.animateWith(SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 380, damping: 28),
      _position.value,
      target,
      _position.velocity.clamp(-12.0, 12.0),
    ));
  }

  double _itemLeft(int index, double extent) =>
      index * extent +
      (widget.centerAction != null && index >= _centerGapAfter
          ? widget.centerGap
          : 0);

  double _centerAt(double position, double extent) {
    final bounded = position.clamp(0.0, widget.items.length - 1.0);
    final first = bounded.floor();
    final second = math.min(first + 1, widget.items.length - 1);
    return _itemLeft(first, extent) +
        (_itemLeft(second, extent) - _itemLeft(first, extent)) *
            (bounded - first) +
        extent / 2;
  }

  double _positionAt(double dx, double extent) {
    for (var index = 0; index < widget.items.length - 1; index++) {
      final start = _itemLeft(index, extent) + extent / 2;
      final end = _itemLeft(index + 1, extent) + extent / 2;
      if (dx <= end) {
        return (index + (dx - start) / (end - start))
            .clamp(0.0, widget.items.length - 1.0);
      }
    }
    return widget.items.length - 1.0;
  }

  double _logicalX(double dx, double width) =>
      Directionality.of(context) == TextDirection.rtl ? width - dx : dx;

  void _startDrag(double dx, double width, double extent) {
    final logicalX = _logicalX(dx, width);
    if (widget.centerAction != null) {
      final gapStart = _centerGapAfter * extent;
      if (logicalX >= gapStart && logicalX <= gapStart + widget.centerGap) {
        return;
      }
    }
    setState(() => _dragging = true);
    _position.value = _positionAt(logicalX, extent);
  }

  void _updateDrag(double dx, double width, double extent) {
    if (!_dragging) return;
    _position.value = _positionAt(_logicalX(dx, width), extent);
  }

  void _finishDrag() {
    if (!_dragging) return;
    var destination = widget.selectedIndex;
    var distance = double.infinity;
    for (var index = 0; index < widget.items.length; index++) {
      if (widget.items[index].isAction) continue;
      final candidate = (_position.value - index).abs();
      if (candidate < distance) {
        destination = index;
        distance = candidate;
      }
    }
    setState(() => _dragging = false);
    if (destination != widget.selectedIndex) widget.onSelected(destination);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dragging) _settle();
    });
  }

  void _cancelDrag() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    _settle();
  }

  @override
  Widget build(BuildContext context) {
    assert(!widget.items[widget.selectedIndex].isAction);
    final scaledLabel = MediaQuery.textScalerOf(context).scale(11);
    final height = widget.height + math.max(0.0, scaledLabel - 11) * 2;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final extent =
          (width - (widget.centerAction == null ? 0 : widget.centerGap)) /
              widget.items.length;
      final bubbleWidth = math.min(128.0, math.max(0.0, extent - 10));
      return Material(
        color: widget.backgroundColor,
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) =>
              _startDrag(details.localPosition.dx, width, extent),
          onHorizontalDragUpdate: (details) =>
              _updateDrag(details.localPosition.dx, width, extent),
          onHorizontalDragEnd: (_) => _finishDrag(),
          onHorizontalDragCancel: _cancelDrag,
          onLongPressStart: (details) =>
              _startDrag(details.localPosition.dx, width, extent),
          onLongPressMoveUpdate: (details) =>
              _updateDrag(details.localPosition.dx, width, extent),
          onLongPressEnd: (_) => _finishDrag(),
          onLongPressCancel: _cancelDrag,
          child: SizedBox(
            height: height,
            child: Stack(children: [
              AnimatedBuilder(
                animation: _position,
                builder: (context, _) {
                  final center = _centerAt(_position.value, extent);
                  final left =
                      (isRtl ? width - center : center) - bubbleWidth / 2;
                  final stretch = _reduceMotion
                      ? 0.0
                      : math.min(
                          0.12,
                          _position.velocity.abs() / 100 +
                              (_dragging ? 0.06 : 0));
                  return Positioned(
                    left: 0,
                    top: 6,
                    width: bubbleWidth,
                    height: height - 12,
                    child: IgnorePointer(
                      child: Transform.translate(
                        offset: Offset(left, 0),
                        child: Transform.scale(
                          scaleX: 1 + stretch,
                          scaleY: 1 - stretch / 2,
                          child: DecoratedBox(
                            key: const ValueKey('liquid-navigation-bubble'),
                            decoration: BoxDecoration(
                              color: widget.bubbleColor ??
                                  widget.activeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(height / 2),
                              border: Border.all(
                                color: widget.bubbleColor == Colors.white
                                    ? const Color(0xFFE6EAF0)
                                    : widget.activeColor
                                        .withValues(alpha: 0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Row(children: [
                for (var index = 0; index < widget.items.length; index++) ...[
                  if (widget.centerAction != null && index == _centerGapAfter)
                    SizedBox(width: widget.centerGap),
                  Expanded(
                    child: _NavigationItemButton(
                      key: ValueKey('liquid-navigation-item-$index'),
                      item: widget.items[index],
                      selected: widget.selectedIndex == index,
                      activeColor: widget.activeColor,
                      inactiveColor: widget.inactiveColor,
                      onTap: () => widget.onSelected(index),
                    ),
                  ),
                ],
              ]),
              if (widget.centerAction != null)
                Positioned(
                  left: isRtl
                      ? width - _centerGapAfter * extent - widget.centerGap
                      : _centerGapAfter * extent,
                  top: 0,
                  bottom: 0,
                  width: widget.centerGap,
                  child: Center(child: widget.centerAction),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

class _NavigationItemButton extends StatelessWidget {
  const _NavigationItemButton({
    super.key,
    required this.item,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final LiquidNavigationItem item;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: item.isAction ? null : selected,
      label: item.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          overlayColor:
              WidgetStatePropertyAll(activeColor.withValues(alpha: 0.08)),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? item.selectedIcon : item.icon,
                      size: 22, color: color),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
