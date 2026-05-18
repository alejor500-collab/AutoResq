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
    return DropdownButtonFormField<String>(
      initialValue: TechnicianSpecialties.isValidCode(value) ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(
          Icons.build_outlined,
          size: 20,
          color: AppColors.secondary,
        ),
      ).copyWith(labelText: label),
      items: TechnicianSpecialties.options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.code,
              child: Text(
                option.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
