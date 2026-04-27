import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/models/vehicle_model.dart';
import '../providers/vehicle_provider.dart';


class EditVehicleScreen extends ConsumerStatefulWidget {
  const EditVehicleScreen({super.key});

  @override
  ConsumerState<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends ConsumerState<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _colorCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = ref.read(vehicleProvider);
    _brandCtrl = TextEditingController(text: v?.brand ?? '');
    _modelCtrl = TextEditingController(text: v?.model ?? '');
    _yearCtrl = TextEditingController(text: v?.year ?? '');
    _plateCtrl = TextEditingController(text: v?.plate ?? '');
    _colorCtrl = TextEditingController(text: v?.color ?? '');
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final vehicle = VehicleModel(
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: _yearCtrl.text.trim(),
        plate: _plateCtrl.text.trim().toUpperCase(),
        color: _colorCtrl.text.trim(),
      );
      await ref.read(vehicleProvider.notifier).save(vehicle);
      if (mounted) {
        AppHelpers.showSnackBar(context, 'Vehículo guardado', isSuccess: true);
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'Error al guardar', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar vehículo'),
        content: const Text('¿Deseas eliminar los datos de tu vehículo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(vehicleProvider.notifier).delete();
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVehicle = ref.watch(vehicleProvider) != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          hasVehicle ? 'Editar Vehículo' : 'Agregar Vehículo',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          if (hasVehicle)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _delete,
              tooltip: 'Eliminar vehículo',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero icon
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.directions_car, size: 44, color: Colors.white),
                ),
              ),
              const Gap(32),

              // Brand
              AppTextField(
                label: 'Marca',
                controller: _brandCtrl,
                prefixIcon: const Icon(Icons.business, size: 20),
                hint: 'Toyota, Chevrolet, Hyundai...',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la marca' : null,
                textInputAction: TextInputAction.next,
              ),
              const Gap(14),

              // Model
              AppTextField(
                label: 'Modelo',
                controller: _modelCtrl,
                prefixIcon: const Icon(Icons.directions_car_outlined, size: 20),
                hint: 'Hilux, Aveo, Tucson...',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el modelo' : null,
                textInputAction: TextInputAction.next,
              ),
              const Gap(14),

              // Year
              AppTextField(
                label: 'Año',
                controller: _yearCtrl,
                prefixIcon: const Icon(Icons.calendar_today, size: 20),
                hint: '2022',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: Validators.year,
                textInputAction: TextInputAction.next,
              ),
              const Gap(14),

              // Plate
              AppTextField(
                label: 'Placa',
                controller: _plateCtrl,
                prefixIcon: const Icon(Icons.pin, size: 20),
                hint: 'ABC-1234',
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (old, newValue) => newValue.copyWith(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    ),
                  ),
                ],
                validator: Validators.plate,
                textInputAction: TextInputAction.next,
              ),
              const Gap(14),

              // Color
              AppTextField(
                label: 'Color',
                controller: _colorCtrl,
                prefixIcon: const Icon(Icons.palette_outlined, size: 20),
                hint: 'Blanco, Negro, Rojo...',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el color' : null,
                textInputAction: TextInputAction.done,
              ),
              const Gap(32),

              AppButton(
                label: hasVehicle ? 'Guardar Cambios' : 'Agregar Vehículo',
                onPressed: _save,
                isLoading: _saving,
                height: 52,
              ),
              const Gap(12),
              AppButton(
                label: 'Cancelar',
                onPressed: () => context.pop(),
                variant: AppButtonVariant.ghost,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
