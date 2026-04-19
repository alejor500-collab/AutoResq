import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/helpers.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 24,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(imageUrl!),
        backgroundColor: AppColors.surfaceVariant,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primary.withOpacity(0.1),
      child: Text(
        AppHelpers.getInitials(name),
        style: TextStyle(
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w700,
          color: backgroundColor != null
              ? AppColors.textOnPrimary
              : AppColors.primary,
        ),
      ),
    );
  }
}
