import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

Future<double?> showTechnicianOfferAmountSheet(
  BuildContext context, {
  double? suggestedAmount,
  double? currentOfferAmount,
  bool alreadyOffered = false,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _TechnicianOfferAmountSheet(
        suggestedAmount: suggestedAmount,
        currentOfferAmount: currentOfferAmount,
        alreadyOffered: alreadyOffered,
      );
    },
  );
}

class _TechnicianOfferAmountSheet extends StatefulWidget {
  final double? suggestedAmount;
  final double? currentOfferAmount;
  final bool alreadyOffered;

  const _TechnicianOfferAmountSheet({
    required this.suggestedAmount,
    required this.currentOfferAmount,
    required this.alreadyOffered,
  });

  @override
  State<_TechnicianOfferAmountSheet> createState() =>
      _TechnicianOfferAmountSheetState();
}

class _TechnicianOfferAmountSheetState
    extends State<_TechnicianOfferAmountSheet> {
  late final TextEditingController _amountController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initialAmount =
        widget.currentOfferAmount ?? widget.suggestedAmount ?? 0;
    _amountController = TextEditingController(
      text: initialAmount > 0 ? _formatEditableAmount(initialAmount) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final validation = Validators.amount(_amountController.text);
    final parsed = _parseAmount(_amountController.text);
    if (validation != null || parsed == null) {
      setState(() {
        _errorText = validation ?? 'Ingresa un precio aproximado valido.';
      });
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final suggested = widget.suggestedAmount;
    final currentOffer = widget.currentOfferAmount;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const Gap(16),
                Text(
                  widget.alreadyOffered ? 'Actualizar oferta' : 'Enviar oferta',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                ),
                const Gap(6),
                const Text(
                  'Indica un precio aproximado para iniciar la atencion. El valor final puede ajustarse despues de revisar el vehiculo y confirmar repuestos o trabajos adicionales.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const Gap(16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (suggested != null)
                        Text(
                          'Referencia de la app: ${AppHelpers.formatCurrency(suggested)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      if (currentOffer != null) ...[
                        if (suggested != null) const Gap(6),
                        Text(
                          'Tu precio aproximado actual: ${AppHelpers.formatCurrency(currentOffer)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(16),
                AppTextField(
                  label: 'Precio aproximado',
                  hint: 'Ej. 8.00',
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: AppInputFormatters.money,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 16, right: 6),
                    child: Icon(
                      Icons.attach_money_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),
                if (_errorText != null) ...[
                  const Gap(8),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Gap(18),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Cancelar',
                        onPressed: () => Navigator.of(context).pop(),
                        variant: AppButtonVariant.outline,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: AppButton(
                        label: widget.alreadyOffered
                            ? 'Actualizar'
                            : 'Enviar oferta',
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatEditableAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  static double? _parseAmount(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}
