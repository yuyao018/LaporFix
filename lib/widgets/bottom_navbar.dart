import 'dart:ui';

import 'package:flutter/material.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlobalKey<State<StatefulWidget>>>? itemKeys;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.itemKeys,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int? _lastDragIndex;

  static const Color _activeColor = Color(0xFF007AFF);
  static const Color _inactiveColor = Color(0xFF667085);

  static const List<_NavItem> _items = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.warning_amber_rounded,
      activeIcon: Icons.warning_amber_rounded,
      label: 'Issue',
    ),
    _NavItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
      label: 'Community',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  void _selectIndex(int index) {
    if (index == widget.currentIndex) return;
    widget.onTap(index);
  }

  void _handleDrag(Offset localPosition, double width) {
    final itemWidth = width / _items.length;
    final index = (localPosition.dx / itemWidth).floor().clamp(
      0,
      _items.length - 1,
    );

    if (_lastDragIndex == index) return;
    _lastDragIndex = index;
    _selectIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(38),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / _items.length;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) {
                      _lastDragIndex = null;
                      _handleDrag(details.localPosition, constraints.maxWidth);
                    },
                    onHorizontalDragUpdate: (details) {
                      _handleDrag(details.localPosition, constraints.maxWidth);
                    },
                    onHorizontalDragEnd: (_) => _lastDragIndex = null,
                    onHorizontalDragCancel: () => _lastDragIndex = null,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 340),
                          curve: Curves.easeOutCubic,
                          left: itemWidth * widget.currentIndex + 4,
                          top: 7,
                          bottom: 7,
                          width: itemWidth - 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(31),
                              boxShadow: [
                                BoxShadow(
                                  color: _activeColor.withValues(alpha: 0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(_items.length, (index) {
                            final item = _items[index];
                            final isActive = index == widget.currentIndex;

                            return Expanded(
                              child: _BottomNavButton(
                                key: widget.itemKeys != null && index < widget.itemKeys!.length
                                    ? widget.itemKeys![index]
                                    : null,
                                item: item,
                                isActive: isActive,
                                activeColor: _activeColor,
                                inactiveColor: _inactiveColor,
                                onTap: () => _selectIndex(index),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _BottomNavButton({
    super.key,
    required this.item,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(31),
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                scale: isActive ? 1.05 : 1,
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
