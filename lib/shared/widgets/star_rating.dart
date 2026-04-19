import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color activeColor;
  final Color inactiveColor;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 20,
    this.activeColor = const Color(0xFFFFC107),
    this.inactiveColor = AppColors.border,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        IconData icon;
        if (rating >= starValue) {
          icon = Icons.star_rounded;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(
          icon,
          size: size,
          color: rating >= starValue - 0.5 ? activeColor : inactiveColor,
        );
      }),
    );
  }
}

// ─── Interactive Star Rating ──────────────────────────────────────────────────
class InteractiveStarRating extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;
  final double size;

  const InteractiveStarRating({
    super.key,
    this.initialValue = 0,
    required this.onChanged,
    this.size = 40,
  });

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        return GestureDetector(
          onTap: () {
            setState(() => _value = starValue);
            widget.onChanged(starValue);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              _value >= starValue ? Icons.star_rounded : Icons.star_outline_rounded,
              size: widget.size,
              color: _value >= starValue
                  ? const Color(0xFFFFC107)
                  : AppColors.border,
            ),
          ),
        );
      }),
    );
  }
}
