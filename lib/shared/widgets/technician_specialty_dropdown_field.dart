import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/technician_specialties.dart';

class TechnicianSpecialtyDropdownField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final String? Function(String?)? validator;

  const TechnicianSpecialtyDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Especialidad técnica',
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: TechnicianSpecialties.isValidCode(value) ? value : null,
          isExpanded: true,
          menuMaxHeight: 320,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.onSurfaceVariant,
          ),
          decoration: InputDecoration(
            hintText: 'Elige tu especialidad',
            helperText: 'Se usara para asignarte emergencias compatibles.',
            helperMaxLines: 2,
            prefixIcon: const Icon(
              Icons.build_outlined,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.72),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            hintStyle: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.72),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            helperStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
            errorMaxLines: 3,
            errorStyle: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          dropdownColor: AppColors.surfaceContainerLowest,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          selectedItemBuilder: (context) => TechnicianSpecialties.options
              .map(
                (option) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          items: TechnicianSpecialties.options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.code,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.handyman_outlined,
                          size: 17,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            option.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}
