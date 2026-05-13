import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/admin_bottom_nav.dart';
import '../providers/admin_provider.dart';

class TechnicianValidationScreen extends ConsumerStatefulWidget {
  const TechnicianValidationScreen({super.key});

  @override
  ConsumerState<TechnicianValidationScreen> createState() =>
      _TechnicianValidationScreenState();
}

class _TechnicianValidationScreenState
    extends ConsumerState<TechnicianValidationScreen> {
  int _tabIndex = 0;
  String? _filterSpecialty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminNotifierProvider.notifier).loadPendingTechnicians();
    });
  }

  List<Map<String, dynamic>> _filteredItems(AdminState state) {
    if (_tabIndex != 0) return const [];
    final list = state.pendingTechnicians;
    if (_filterSpecialty == null) return list;
    return list.where((t) {
      final esp = (t['especialidad'] as String? ?? '').toLowerCase();
      return esp.contains(_filterSpecialty!.toLowerCase());
    }).toList();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.adminDashboard);
        break;
      case 1:
        context.go(AppRoutes.userManagement);
        break;
      case 2:
        context.go(AppRoutes.technicianValidation);
        break;
      case 3:
        context.go(AppRoutes.emergencyMonitor);
        break;
    }
  }

  Future<void> _showApproveSheet(String id, String nombre) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApproveSheet(nombre: nombre),
    );
    if (confirmed == true && mounted) {
      final ok =
          await ref.read(adminNotifierProvider.notifier).approveTechnician(id);
      if (mounted && ok) {
        AppHelpers.showSnackBar(context, '$nombre aprobado', isSuccess: true);
      }
    }
  }

  Future<void> _showRejectSheet(String id, String nombre) async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RejectSheet(),
    );
    if (motivo != null && mounted) {
      final ok = await ref
          .read(adminNotifierProvider.notifier)
          .rejectTechnician(id, motivo: motivo);
      if (mounted && ok) {
        AppHelpers.showSnackBar(context, '$nombre rechazado', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotifierProvider);
    final filtered = _filteredItems(state);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.adminDashboard);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: _ValidationAppBar(
            onBack: () => context.go(AppRoutes.adminDashboard),
          ),
        ),
        body: Column(
          children: [
            _ValidationTabBar(
              selectedIndex: _tabIndex,
              pendingCount: state.pendingTechnicians.length,
              onTabChanged: (i) => setState(() {
                _tabIndex = i;
                _filterSpecialty = null;
              }),
            ),
            if (_tabIndex == 0)
              _SpecialtyFilter(
                selected: _filterSpecialty,
                onSelected: (v) => setState(() => _filterSpecialty = v),
              ),
            Expanded(
              child: state.isLoading
                  ? const _LoadingState()
                  : filtered.isEmpty
                      ? _EmptyState(tabIndex: _tabIndex)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppConstants.pagePadding,
                            12,
                            AppConstants.pagePadding,
                            AppConstants.pagePadding,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final tech = filtered[i];
                            final nombre = (tech['usuarios']
                                        as Map<String, dynamic>?)?['nombre']
                                    as String? ??
                                'Técnico';
                            final techId = tech['id'] as String;
                            return _TechCard(
                              technician: tech,
                              onApprove: () =>
                                  _showApproveSheet(techId, nombre),
                              onReject: () => _showRejectSheet(techId, nombre),
                            );
                          },
                        ),
            ),
          ],
        ),
        bottomNavigationBar: AdminBottomNav(
          selectedIndex: 2,
          onItemTapped: _onNavTap,
        ),
      ),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────

class _ValidationAppBar extends StatelessWidget {
  final VoidCallback onBack;

  const _ValidationAppBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.surfaceContainerLowest,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.textPrimary,
        ),
        onPressed: onBack,
      ),
      title: Text(
        'Validación de Técnicos',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textSecondary,
            size: 22,
          ),
          onPressed: () {},
        ),
      ],
    );
  }
}

// ─── Tab Bar ──────────────────────────────────────────────────────────────────

class _ValidationTabBar extends StatelessWidget {
  final int selectedIndex;
  final int pendingCount;
  final ValueChanged<int> onTabChanged;

  const _ValidationTabBar({
    required this.selectedIndex,
    required this.pendingCount,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('Pendientes', pendingCount),
      ('Aprobados', 0),
      ('Rechazados', 0),
    ];

    return Container(
      color: AppColors.surfaceContainerLowest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final label = tabs[i].$1;
                final count = tabs[i].$2;
                final isActive = selectedIndex == i;
                return Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => onTabChanged(i),
                      child: AnimatedContainer(
                        duration: AppConstants.animFast,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                isActive ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              count > 0 ? '$count' : '—',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                height: 1,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
        ],
      ),
    );
  }
}

// ─── Specialty Filter Chips ───────────────────────────────────────────────────

class _SpecialtyFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _SpecialtyFilter({required this.selected, required this.onSelected});

  static const _options = ['Todos', 'Mecánico', 'Eléctrico'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: _options.map((opt) {
          final isSelected =
              opt == 'Todos' ? selected == null : selected == opt;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(opt == 'Todos' ? null : opt),
              child: AnimatedContainer(
                duration: AppConstants.animFast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Tech Card ────────────────────────────────────────────────────────────────

class _TechCard extends StatelessWidget {
  final Map<String, dynamic> technician;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _TechCard({
    required this.technician,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final userData = technician['usuarios'] as Map<String, dynamic>? ?? {};
    final nombre = userData['nombre'] as String? ?? 'Técnico';
    final email = userData['email'] as String? ?? '';
    final telefono = userData['telefono'] as String? ?? '';
    final especialidad = technician['especialidad'] as String? ?? '';
    final urlCredencial = technician['url_credencial'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                UserAvatar(name: nombre, radius: 26),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (especialidad.isNotEmpty)
                        Text(
                          especialidad,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const Gap(8),
                const _StatusBadge(
                  label: 'Pendiente',
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          // ── Details ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                if (email.isNotEmpty)
                  _DetailRow(
                    icon: Icons.email_outlined,
                    label: 'Correo electrónico',
                    value: email,
                  ),
                if (telefono.isNotEmpty) ...[
                  const Gap(10),
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: telefono,
                  ),
                ],
                if (especialidad.isNotEmpty) ...[
                  const Gap(10),
                  _DetailRow(
                    icon: Icons.build_outlined,
                    label: 'Especialidad declarada',
                    value: especialidad,
                  ),
                ],
                const Gap(10),
                _CredentialRow(url: urlCredencial),
              ],
            ),
          ),
          // ── Actions ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Rechazar',
                    onPressed: onReject,
                    variant: AppButtonVariant.outline,
                    height: 42,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: AppButton(
                    label: 'Aprobar',
                    onPressed: onApprove,
                    height: 42,
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: AppColors.textHint),
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint,
                  letterSpacing: 0.2,
                ),
              ),
              const Gap(1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String? url;

  const _CredentialRow({this.url});

  void _showFullImage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(16),
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  url!,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: double.infinity,
                      height: 300,
                      color: const Color(0xFF1A1A1A),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (ctx, _, __) => Container(
                    width: double.infinity,
                    height: 240,
                    color: const Color(0xFF1A1A1A),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: Colors.white38,
                        ),
                        const Gap(8),
                        Text(
                          'No se pudo cargar la imagen',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDoc = url != null && url!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (hasDoc ? AppColors.info : AppColors.textHint)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.badge_outlined,
                size: 16,
                color: hasDoc ? AppColors.info : AppColors.textHint,
              ),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documento de identidad',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint,
                    ),
                  ),
                  const Gap(1),
                  Text(
                    hasDoc
                        ? 'Foto adjunta — toca para ampliar'
                        : 'Documento no disponible',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: hasDoc ? AppColors.info : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasDoc) ...[
          const Gap(10),
          GestureDetector(
            onTap: () => _showFullImage(context),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url!,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (ctx, _, __) => Container(
                    width: double.infinity,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          size: 18,
                          color: AppColors.textHint,
                        ),
                        const Gap(8),
                        Text(
                          'No se pudo cargar la imagen',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Loading / Empty States ───────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppConstants.pagePadding),
      child: ShimmerList(count: 3, itemHeight: 220),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({required this.tabIndex});

  static const _data = [
    (
      'Sin técnicos pendientes',
      'Todos los técnicos han sido revisados',
      Icons.verified_user_outlined
    ),
    (
      'Sin técnicos aprobados',
      'Aún no hay técnicos aprobados registrados',
      Icons.check_circle_outline
    ),
    (
      'Sin técnicos rechazados',
      'No existen técnicos rechazados en el sistema',
      Icons.cancel_outlined
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = tabIndex.clamp(0, _data.length - 1);
    final (msg, sub, icon) = _data[idx];
    return EmptyStateWidget(message: msg, subtitle: sub, icon: icon);
  }
}

// ─── Approve Bottom Sheet ─────────────────────────────────────────────────────

class _ApproveSheet extends StatelessWidget {
  final String nombre;

  const _ApproveSheet({required this.nombre});

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(20),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: _green,
              size: 38,
            ),
          ),
          const Gap(16),
          Text(
            'Confirmar aprobación',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(6),
          Text(
            '$nombre podrá acceder a la plataforma\ncomo técnico verificado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const Gap(28),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.pop(context, false),
                  variant: AppButtonVariant.outline,
                  height: 44,
                ),
              ),
              const Gap(10),
              Expanded(
                child: AppButton(
                  label: 'Aprobar',
                  onPressed: () => Navigator.pop(context, true),
                  height: 44,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reject Bottom Sheet ──────────────────────────────────────────────────────

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  static const _reasons = [
    'Documentos incompletos',
    'Especialidad no verificable',
    'Información incorrecta',
    'Sin experiencia suficiente',
    'Otros',
  ];

  String? _selectedReason;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _noteCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),
          // header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              const Gap(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rechazar técnico',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Selecciona el motivo de rechazo',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(20),
          Text(
            'Motivo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const Gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                child: AnimatedContainer(
                  duration: AppConstants.animFast,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.error.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.error : AppColors.border,
                    ),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Gap(16),
          Text(
            'Observaciones',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const Gap(8),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            style:
                TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Agrega detalles adicionales...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const Gap(20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.pop(context),
                  variant: AppButtonVariant.outline,
                  height: 44,
                ),
              ),
              const Gap(10),
              Expanded(
                child: AppButton(
                  label: 'Confirmar rechazo',
                  onPressed: _selectedReason != null &&
                          _noteCtrl.text.trim().isNotEmpty
                      ? () {
                          Navigator.pop(
                            context,
                            '$_selectedReason: ${_noteCtrl.text.trim()}',
                          );
                        }
                      : null,
                  variant: AppButtonVariant.danger,
                  height: 44,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
