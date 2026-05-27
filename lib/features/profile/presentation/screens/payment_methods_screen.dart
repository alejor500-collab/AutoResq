import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/payment_methods.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  late String _selected;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).valueOrNull;
    _selected = PaymentMethods.normalize(user?.preferredPaymentMethod);
  }

  Future<void> _save() async {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSaving = true);
    final ok = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(user.copyWith(preferredPaymentMethod: _selected));
    if (!mounted) return;
    setState(() => _isSaving = false);

    AppHelpers.showSnackBar(
      context,
      ok
          ? 'Metodo de pago guardado.'
          : 'No se pudo guardar el metodo de pago.',
      isError: !ok,
    );
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Metodos de pago'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            const Text(
              'Metodo preferido',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: 0,
              ),
            ),
            const Gap(8),
            const Text(
              'Este sera el metodo sugerido al crear una emergencia. Podras cambiarlo antes de publicarla.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
                height: 1.45,
              ),
            ),
            const Gap(24),
            for (final method in PaymentMethods.values) ...[
              _PaymentMethodTile(
                method: method,
                selected: _selected == method,
                onTap: () => setState(() => _selected = method),
              ),
              const Gap(12),
            ],
            const Gap(12),
            _InfoPanel(
              icon: Icons.visibility_outlined,
              title: 'Visible para el tecnico',
              body:
                  'El tecnico vera la forma de pago elegida junto con la solicitud y durante el servicio.',
            ),
            if (user?.email.isNotEmpty == true) ...[
              const Gap(12),
              _InfoPanel(
                icon: Icons.account_circle_outlined,
                title: 'Cuenta',
                body: user!.email,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: AppButton(
            label: 'Guardar metodo',
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _save,
            prefixIcon: const Icon(Icons.check_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  PaymentMethods.icon(method),
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PaymentMethods.label(method),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const Gap(3),
                    Text(
                      PaymentMethods.description(method),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary, size: 22),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const Gap(2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
