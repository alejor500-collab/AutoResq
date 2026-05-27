import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'animated_pressable.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isTechnician;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isTechnician = false,
  });

  static const _driverItems = [
    _NavItem(
        icon: Icons.home_outlined, activeIcon: Icons.home, label: 'INICIO'),
    _NavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      label: 'SOLICITUDES',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'CHAT',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'PERFIL',
    ),
  ];

  static const _technicianItems = [
    _NavItem(
      icon: Icons.history_rounded,
      activeIcon: Icons.history_rounded,
      label: 'HISTORIAL',
    ),
    _NavItem(
      icon: Icons.assignment_turned_in_outlined,
      activeIcon: Icons.assignment_turned_in,
      label: 'SOLICITUDES',
    ),
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'INICIO',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'CHAT',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'PERFIL',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = isTechnician ? _technicianItems : _driverItems;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SizedBox(
        height: 72 + bottomInset,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                height: 68,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.94),
                      AppColors.surfaceContainerLowest.withValues(alpha: 0.84),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.82),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.10),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: List.generate(items.length, (i) {
                    final item = items[i];
                    final isActive = i == currentIndex;
                    return Expanded(
                      child: _NavItemWidget(
                        item: item,
                        isActive: isActive,
                        onTap: () => onTap(i),
                      ),
                    );
                  }),
                ),
              ),
            ),
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

class _NavItemWidget extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabel = isActive && constraints.maxWidth >= 104;

        return AnimatedPressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          pressedScale: 0.95,
          hoverScale: 1.015,
          child: AnimatedScale(
            scale: isActive ? 1.02 : 0.98,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(horizontal: isActive ? 10 : 0),
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.14),
                          AppColors.primary.withValues(alpha: 0.08),
                        ],
                      )
                    : null,
                color: isActive ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : Colors.transparent,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: isActive ? 34 : 42,
                    height: isActive ? 34 : 42,
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.primaryGradient : null,
                      color: isActive
                          ? null
                          : AppColors.secondary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? item.activeIcon : item.icon,
                      color: isActive ? Colors.white : AppColors.secondary,
                      size: isActive ? 19 : 21,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    child: showLabel
                        ? Padding(
                            padding: const EdgeInsets.only(left: 7),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
