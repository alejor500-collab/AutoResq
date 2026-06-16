import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/input_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/admin_bottom_nav.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/admin_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends ConsumerState<UserManagementScreen> {
  String _searchQuery = '';
  String _filterRole = 'todos';
  String _filterTechnicianStatus = 'todos';

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.adminDashboard);
        break;
      case 1:
        break;
      case 2:
        context.go(AppRoutes.technicianValidation);
        break;
      case 3:
        context.go(AppRoutes.emergencyMonitor);
        break;
      case 4:
        context.go(AppRoutes.adminReports);
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminNotifierProvider.notifier).loadUsers();
    });
  }

  Future<void> _handleToggle(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    final currentActivo = user['activo'] as bool? ?? true;
    String? reason;

    if (currentActivo) {
      reason = await _showDisableAccountDialog(user);
      if (reason == null) return;
    } else {
      final confirmed = await _showEnableAccountDialog(user);
      if (confirmed != true) return;
    }

    final ok = await ref.read(adminNotifierProvider.notifier).toggleUserActive(
          id,
          !currentActivo,
          reason: reason,
        );
    if (!ok && mounted) {
      AppHelpers.showSnackBar(
        context,
        ref.read(adminNotifierProvider).error ??
            'No se pudo actualizar la cuenta',
        isError: true,
      );
    }
  }

  Future<String?> _showDisableAccountDialog(Map<String, dynamic> user) async {
    final reasonCtrl = TextEditingController();
    final name = user['nombre'] as String? ?? 'este usuario';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Desactivar cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Indica el motivo para desactivar la cuenta de $name. Este texto se enviara por correo y se mostrara al usuario al iniciar sesion.',
              style: const TextStyle(height: 1.4),
            ),
            const Gap(14),
            TextField(
              controller: reasonCtrl,
              minLines: 3,
              maxLines: 5,
              inputFormatters: AppInputFormatters.limitedText(
                Validators.longTextMaxLength,
              ),
              decoration: InputDecoration(
                hintText: 'Motivo de desactivacion...',
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              if (reason.length < 8) return;
              Navigator.pop(dialogContext, reason);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    return result;
  }

  Future<bool?> _showEnableAccountDialog(Map<String, dynamic> user) {
    final name = user['nombre'] as String? ?? 'este usuario';
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reactivar cuenta'),
        content: Text(
          'La cuenta de $name podra iniciar sesion nuevamente. Si tiene una solicitud de reactivacion pendiente, quedara aprobada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reactivar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReactivationRequest(
    Map<String, dynamic> user,
    Map<String, dynamic> request,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReactivationRequestSheet(
        user: user,
        request: request,
        onApprove: (response) => _reviewReactivationRequest(
          user: user,
          request: request,
          approved: true,
          response: response,
        ),
        onReject: (response) => _reviewReactivationRequest(
          user: user,
          request: request,
          approved: false,
          response: response,
        ),
      ),
    );
  }

  Future<bool> _reviewReactivationRequest({
    required Map<String, dynamic> user,
    required Map<String, dynamic> request,
    required bool approved,
    String? response,
  }) async {
    final userId = user['id']?.toString() ?? '';
    final requestId = request['id']?.toString() ?? '';
    final ok = await ref
        .read(adminNotifierProvider.notifier)
        .reviewReactivationRequest(
          userId: userId,
          requestId: requestId,
          approved: approved,
          response: response,
        );

    if (!mounted) return ok;
    AppHelpers.showSnackBar(
      context,
      ok
          ? approved
              ? 'Cuenta reactivada correctamente.'
              : 'Solicitud rechazada.'
          : ref.read(adminNotifierProvider).error ??
              'No se pudo revisar la solicitud.',
      isSuccess: ok,
      isError: !ok,
    );
    return ok;
  }

  Map<String, dynamic>? _firstMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  bool _hasTechnicianProfile(Map<String, dynamic> user) {
    return user['rol'] == AppConstants.roleTechnician ||
        _firstMap(user['tecnicos']) != null;
  }

  bool _matchesTechnicianStatus(Map<String, dynamic> user, String status) {
    if (!_hasTechnicianProfile(user)) return false;
    final activo = user['activo'] as bool? ?? true;
    final technician = _firstMap(user['tecnicos']);
    final verification = technician?['estado_verificacion']?.toString();
    return switch (status) {
      'activos' =>
        activo &&
            verification != AppConstants.verificationPending &&
            verification != AppConstants.verificationRejected,
      'rechazados' =>
        activo && verification == AppConstants.verificationRejected,
      'deshabilitados' => !activo,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotifierProvider);

    final filtered = state.users.where((u) {
      final name = (u['nombre'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      final role = u['rol'] as String? ?? '';
      final matchSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
      final matchRole = _filterRole == 'todos'
          ? true
          : _filterRole == AppConstants.roleTechnician
              ? _hasTechnicianProfile(u)
              : role == _filterRole;
      final matchTechnicianStatus = _filterTechnicianStatus == 'todos' ||
          _matchesTechnicianStatus(u, _filterTechnicianStatus);
      return matchSearch && matchRole && matchTechnicianStatus;
    }).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.adminDashboard);
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AdminBottomNav(
        selectedIndex: 1,
        onItemTapped: _onNavTap,
      ),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go(AppRoutes.adminDashboard),
        ),
        title: const Text(
          'Gestion de usuarios',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  inputFormatters: AppInputFormatters.limitedText(100),
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const Gap(8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        selected: _filterRole == 'todos',
                        onTap: () => setState(() {
                          _filterRole = 'todos';
                          _filterTechnicianStatus = 'todos';
                        }),
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: 'Conductores',
                        selected:
                            _filterRole == AppConstants.roleDriver,
                        onTap: () => setState(() {
                          _filterRole = AppConstants.roleDriver;
                          _filterTechnicianStatus = 'todos';
                        }),
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: 'Tecnicos',
                        selected:
                            _filterRole == AppConstants.roleTechnician,
                        onTap: () => setState(() {
                          _filterRole = AppConstants.roleTechnician;
                          _filterTechnicianStatus = 'todos';
                        }),
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: 'Admins',
                        selected:
                            _filterRole == AppConstants.roleAdmin,
                        onTap: () => setState(() {
                          _filterRole = AppConstants.roleAdmin;
                          _filterTechnicianStatus = 'todos';
                        }),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos tecnicos',
                        selected: _filterRole == AppConstants.roleTechnician &&
                            _filterTechnicianStatus == 'todos',
                        onTap: () => setState(() {
                          _filterRole = AppConstants.roleTechnician;
                          _filterTechnicianStatus = 'todos';
                        }),
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: 'Activos',
                        selected: _filterTechnicianStatus == 'activos',
                        onTap: () => setState(() {
                          _filterRole = AppConstants.roleTechnician;
                          _filterTechnicianStatus = 'activos';
                        }),
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: 'Rechazados',
                        selected: _filterTechnicianStatus == 'rechazados',
                        onTap: () => setState(() {
                          _filterRole = AppConstants.roleTechnician;
                          _filterTechnicianStatus = 'rechazados';
                        }),
                      ),
                      const Gap(8),
                      _FilterChip(
                        label: 'Deshabilitados',
                        selected: _filterTechnicianStatus == 'deshabilitados',
                        onTap: () => setState(() {
                          _filterRole = AppConstants.roleTechnician;
                          _filterTechnicianStatus = 'deshabilitados';
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : filtered.isEmpty
                    ? const EmptyStateWidget(
                        message: 'No se encontraron usuarios',
                        icon: Icons.people_outline,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          return _UserCard(
                            user: filtered[i],
                            onToggleActive: () => _handleToggle(filtered[i]),
                            onOpenReactivationRequest:
                                _showReactivationRequest,
                          );
                        },
                      ),
          ),
        ],
      ),
      ),
    );
  }
}

enum _AccountStatus { active, pending, rejected, disabled }

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggleActive;
  final void Function(
    Map<String, dynamic> user,
    Map<String, dynamic> request,
  ) onOpenReactivationRequest;

  const _UserCard({
    required this.user,
    required this.onToggleActive,
    required this.onOpenReactivationRequest,
  });

  _AccountStatus get _status {
    final activo = user['activo'] as bool? ?? true;
    if (!activo) return _AccountStatus.disabled;
    final tecnicoData = _firstMap(user['tecnicos']);
    final estado = tecnicoData?['estado_verificacion'] as String?;
    if (estado == AppConstants.verificationPending) return _AccountStatus.pending;
    if (estado == AppConstants.verificationRejected) return _AccountStatus.rejected;
    return _AccountStatus.active;
  }

  Map<String, dynamic>? _firstMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  Map<String, dynamic>? get _latestReactivationRequest {
    final raw = user['account_reactivation_requests'];
    final list = raw is List
        ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
    if (list.isEmpty) return null;
    list.sort(
      (a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''),
    );
    return list.first;
  }

  List<Map<String, dynamic>> get _serviceHistory {
    final raw = user['admin_service_history'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  double get _ratingAverage =>
      (user['admin_rating_average'] as num?)?.toDouble() ??
      (user['calificacion_promedio'] as num?)?.toDouble() ??
      0;

  int get _servicesCount =>
      (user['admin_services_count'] as num?)?.toInt() ??
      (user['total_servicios'] as num?)?.toInt() ??
      0;

  Color _statusColor(_AccountStatus s) {
    switch (s) {
      case _AccountStatus.active:   return AppColors.success;
      case _AccountStatus.pending:  return AppColors.warning;
      case _AccountStatus.rejected: return AppColors.error;
      case _AccountStatus.disabled: return AppColors.textHint;
    }
  }

  String _statusLabel(_AccountStatus s) {
    switch (s) {
      case _AccountStatus.active:   return 'Activa';
      case _AccountStatus.pending:  return 'Pendiente';
      case _AccountStatus.rejected: return 'Rechazada';
      case _AccountStatus.disabled: return 'Deshabilitada';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleDriver:     return AppColors.primary;
      case AppConstants.roleTechnician: return AppColors.tertiary;
      case AppConstants.roleAdmin:      return AppColors.primaryContainer;
      default:                          return AppColors.textSecondary;
    }
  }

  void _showServiceHistory(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServiceHistorySheet(
        userName: user['nombre'] as String? ?? 'Usuario',
        ratingAverage: _ratingAverage,
        servicesCount: _servicesCount,
        services: _serviceHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name     = user['nombre'] as String? ?? 'Usuario';
    final email    = user['email']  as String? ?? '';
    final role     = user['rol']    as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;
    final activo   = user['activo'] as bool? ?? true;
    final status   = _status;
    final statusColor = _statusColor(status);
    final disabledReason = user['account_disabled_reason'] as String?;
    final request = _latestReactivationRequest;
    final hasPendingReactivation = request?['status'] == 'pending';
    final evidenceUrl = request?['evidence_url']?.toString();
    final ratingAverage = _ratingAverage;
    final servicesCount = _servicesCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: avatarUrl, name: name, radius: 22),
              const Gap(12),
              Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const Gap(7),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _UserMetricChip(
                      icon: Icons.star_rounded,
                      label: ratingAverage > 0
                          ? ratingAverage.toStringAsFixed(1)
                          : 'Sin rating',
                      color: Colors.amber.shade700,
                    ),
                    _UserMetricChip(
                      icon: Icons.assignment_turned_in_outlined,
                      label: '$servicesCount atendidas',
                      color: AppColors.secondary,
                    ),
                    if (servicesCount > 0)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _showServiceHistory(context),
                        child: const _UserMetricChip(
                          icon: Icons.visibility_outlined,
                          label: 'Ver detalle',
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                if (!activo && disabledReason?.trim().isNotEmpty == true) ...[
                  const Gap(4),
                  Text(
                    'Motivo: ${disabledReason!.trim()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _roleColor(role).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              AppHelpers.roleLabel(role),
              style: TextStyle(
                color: _roleColor(role),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(4),
          IconButton(
            icon: Icon(
              activo ? Icons.toggle_on : Icons.toggle_off,
              color: activo ? statusColor : AppColors.textHint,
              size: 28,
            ),
            onPressed: onToggleActive,
          ),
        ],
          ),
          if (hasPendingReactivation) ...[
            const Gap(10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  final pendingRequest = request;
                  if (pendingRequest != null) {
                    onOpenReactivationRequest(user, pendingRequest);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const Gap(5),
                      Expanded(
                        child: Text(
                          'Solicita reactivacion: ${request?['reason'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                      const Gap(5),
                      const Text(
                        'Revisar',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.warning,
                        ),
                      ),
                      if (evidenceUrl?.isNotEmpty == true) ...[
                        const Gap(3),
                        const Icon(
                          Icons.attach_file_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _UserMetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const Gap(4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactivationRequestSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> request;
  final Future<bool> Function(String response) onApprove;
  final Future<bool> Function(String response) onReject;

  const _ReactivationRequestSheet({
    required this.user,
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_ReactivationRequestSheet> createState() =>
      _ReactivationRequestSheetState();
}

class _ReactivationRequestSheetState
    extends State<_ReactivationRequestSheet> {
  final TextEditingController _responseCtrl = TextEditingController();
  bool _isReviewing = false;

  String? get _evidenceUrl {
    final value = widget.request['evidence_url']?.toString().trim();
    return value?.isNotEmpty == true ? value : null;
  }

  String get _evidenceFileName {
    final stored = widget.request['evidence_file_name']?.toString().trim();
    if (stored?.isNotEmpty == true) return stored!;
    final url = _evidenceUrl;
    if (url == null) return 'Archivo adjunto';
    final uri = Uri.tryParse(url);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : null;
    return segment?.isNotEmpty == true ? segment! : 'Archivo adjunto';
  }

  bool get _isImageEvidence {
    final value = (_evidenceFileName.isNotEmpty
            ? _evidenceFileName
            : _evidenceUrl ?? '')
        .toLowerCase();
    return value.endsWith('.jpg') ||
        value.endsWith('.jpeg') ||
        value.endsWith('.png') ||
        value.endsWith('.webp');
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool approved}) async {
    final response = _responseCtrl.text.trim();
    if (!approved && response.length < 8) {
      AppHelpers.showSnackBar(
        context,
        'Escribe una respuesta para rechazar la solicitud.',
        isError: true,
      );
      return;
    }

    setState(() => _isReviewing = true);
    final ok = approved
        ? await widget.onApprove(response)
        : await widget.onReject(response);
    if (!mounted) return;
    setState(() => _isReviewing = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _openEvidence() async {
    final url = _evidenceUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) {
      AppHelpers.showSnackBar(
        context,
        'No se pudo abrir el archivo adjunto.',
        isError: true,
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppHelpers.showSnackBar(
        context,
        'No se pudo abrir el archivo adjunto.',
        isError: true,
      );
    }
  }

  String _formatTimestamp(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    final date = parsed == null ? null : AppHelpers.toAppTime(parsed);
    if (date == null) return 'Fecha no disponible';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _infoBox({
    required IconData icon,
    required String title,
    required String body,
    Color color = AppColors.secondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const Gap(4),
                Text(
                  body.isEmpty ? 'Sin informacion registrada.' : body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
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

  Widget _evidenceView() {
    final url = _evidenceUrl;
    if (url == null) {
      return _infoBox(
        icon: Icons.attach_file_rounded,
        title: 'Evidencia',
        body: 'El usuario no adjunto fotos ni documentos.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isImageEvidence
                    ? Icons.image_outlined
                    : Icons.description_outlined,
                size: 18,
                color: AppColors.warning,
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  _evidenceFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openEvidence,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('Abrir'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          if (_isImageEvidence) ...[
            const Gap(10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                url,
                height: 210,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 130,
                  alignment: Alignment.center,
                  color: AppColors.surfaceContainer,
                  child: const Text(
                    'No se pudo cargar la vista previa.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const Gap(8),
            const Text(
              'Documento adjunto disponible para revision.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final name = widget.user['nombre']?.toString() ?? 'Usuario';
    final email = widget.user['email']?.toString() ?? '';
    final disabledReason =
        widget.user['account_disabled_reason']?.toString().trim() ?? '';
    final requestReason = widget.request['reason']?.toString().trim() ?? '';
    final createdAt = _formatTimestamp(widget.request['created_at']);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.90),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          18 + media.padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Gap(18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Solicitud de reactivacion',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        createdAt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Pendiente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(16),
            Expanded(
              child: ListView(
                children: [
                  _infoBox(
                    icon: Icons.person_outline_rounded,
                    title: name,
                    body: email,
                  ),
                  const Gap(12),
                  _infoBox(
                    icon: Icons.block_rounded,
                    title: 'Motivo de desactivacion',
                    body: disabledReason,
                    color: AppColors.error,
                  ),
                  const Gap(12),
                  _sectionTitle('Justificacion del usuario'),
                  _infoBox(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Comentario',
                    body: requestReason,
                    color: AppColors.warning,
                  ),
                  const Gap(12),
                  _sectionTitle('Evidencia adjunta'),
                  _evidenceView(),
                  const Gap(12),
                  _sectionTitle('Respuesta del administrador'),
                  TextField(
                    controller: _responseCtrl,
                    minLines: 3,
                    maxLines: 5,
                    inputFormatters: AppInputFormatters.limitedText(
                      Validators.longTextMaxLength,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Opcional al aprobar, obligatorio al rechazar...',
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isReviewing
                        ? null
                        : () => _submit(approved: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: FilledButton(
                    onPressed: _isReviewing
                        ? null
                        : () => _submit(approved: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isReviewing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceHistorySheet extends StatelessWidget {
  final String userName;
  final double ratingAverage;
  final int servicesCount;
  final List<Map<String, dynamic>> services;

  const _ServiceHistorySheet({
    required this.userName,
    required this.ratingAverage,
    required this.servicesCount,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const Gap(18),
          Row(
            children: [
              Expanded(
                child: Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              _HistoryRatingBadge(rating: ratingAverage),
            ],
          ),
          const Gap(4),
          Text(
            '$servicesCount solicitudes atendidas registradas',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(18),
          Expanded(
            child: services.isEmpty
                ? const Center(
                    child: Text(
                      'Aun no hay servicios finalizados para este usuario.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const Gap(10),
                    itemBuilder: (context, index) {
                      final service = services[index];
                      final date = DateTime.tryParse(
                        service['date']?.toString() ?? '',
                      );
                      final rating = (service['rating'] as num?)?.toInt();
                      final comment = service['comment']?.toString().trim();
                      final role = service['role_label']?.toString() ?? '';
                      final counterpartLabel =
                          service['counterpart_label']?.toString() ?? 'con';
                      final counterpart =
                          service['counterpart_name']?.toString() ?? '';
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    service['service_name']?.toString() ??
                                        'Emergencia',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                                _SmallRatingBadge(rating: rating),
                              ],
                            ),
                            const Gap(5),
                            Text(
                              [
                                if (role.isNotEmpty) role,
                                if (counterpart.isNotEmpty)
                                  '$counterpartLabel $counterpart',
                                if (date != null) AppHelpers.formatDate(date),
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (comment?.isNotEmpty == true) ...[
                              const Gap(8),
                              Text(
                                comment!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurface,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRatingBadge extends StatelessWidget {
  final double rating;

  const _HistoryRatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return _UserMetricChip(
      icon: Icons.star_rounded,
      label: rating > 0 ? rating.toStringAsFixed(1) : 'Sin rating',
      color: Colors.amber.shade700,
    );
  }
}

class _SmallRatingBadge extends StatelessWidget {
  final int? rating;

  const _SmallRatingBadge({this.rating});

  @override
  Widget build(BuildContext context) {
    final hasRating = rating != null && rating! > 0;
    final color = hasRating ? Colors.amber.shade700 : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 13, color: color),
          const Gap(3),
          Text(
            hasRating ? rating.toString() : 'Sin calificar',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
