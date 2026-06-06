import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/app_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _showIntroScreen = true;
  bool _showEmailForm = false;
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _navigateByRole() {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;
    if (!user.isActive) {
      context.go(AppRoutes.accountDisabled);
      return;
    }
    switch (user.role) {
      case AppConstants.roleDriver:
        context.go(AppRoutes.driverHome);
      case AppConstants.roleTechnician:
        context.go(
          user.isApproved ? AppRoutes.technicianHome : AppRoutes.driverHome,
        );
      case AppConstants.roleAdmin:
        context.go(AppRoutes.adminDashboard);
    }
  }

  Future<void> _loginWithGoogle() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    final success = await notifier.loginWithGoogle();
    if (!mounted) return;
    if (success) {
      _navigateByRole();
    } else {
      final error = ref.read(authNotifierProvider).error;
      AppHelpers.showSnackBar(
        context,
        error?.toString() ?? 'Error al iniciar sesión con Google',
        isError: true,
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);
    final success = await notifier.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      _navigateByRole();
    } else {
      final error = ref.read(authNotifierProvider).error;
      AppHelpers.showSnackBar(
        context,
        error?.toString() ?? 'Error de autenticación',
        isError: true,
      );
    }
  }

  double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _showIntroScreen
            ? _buildIntroScreen(context, isDesktop)
            : _buildOptionsScreen(context, isDesktop, isLoading),
      ),
    );
  }

  Widget _buildIntroScreen(BuildContext context, bool isDesktop) {
    return ColoredBox(
      key: const ValueKey('login_intro'),
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isShort = constraints.maxHeight < 700;
            final topPadding = isDesktop ? 20.0 : (isShort ? 8.0 : 14.0);
            final bottomPadding = isDesktop ? 20.0 : (isShort ? 10.0 : 14.0);
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 34 : 22,
                  topPadding,
                  isDesktop ? 34 : 22,
                  bottomPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 680 : 520),
                  child: SizedBox(
                    height: constraints.maxHeight - topPadding - bottomPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                SizedBox(
                  height: isDesktop ? 126 : (isShort ? 82 : 104),
                  width: double.infinity,
                  child: const _IntroShowcaseCard(),
                ),
                const Spacer(flex: 2),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: isDesktop ? 46 : (isShort ? 29 : 34),
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                    children: const [
                      TextSpan(text: 'Asistencia\nVehicular\n'),
                      TextSpan(
                        text: 'Inteligente',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isShort ? 6 : (isDesktop ? 12 : 8)),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Diagnóstico con IA, geolocalización y asistencia en tiempo real para tu total tranquilidad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 17 : (isShort ? 13 : 14),
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => setState(() => _showIntroScreen = false),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize:
                          Size(0, isDesktop ? 68 : (isShort ? 54 : 60)),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Comenzar',
                          style: TextStyle(
                            fontSize: isDesktop ? 21 : 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(width: isDesktop ? 14 : 10),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: isDesktop ? 20 : 16,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isShort ? 7 : (isDesktop ? 14 : 10)),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: const [
                    _IntroMetaItem(
                      icon: Icons.shield_outlined,
                      label: 'SAFE & SECURE',
                    ),
                    _IntroMetaDot(),
                    _IntroMetaItem(
                      icon: Icons.bolt_outlined,
                      label: 'FAST RESPONSE',
                    ),
                  ],
                ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOptionsScreen(
    BuildContext context,
    bool isDesktop,
    bool isLoading,
  ) {
    return ColoredBox(
      key: const ValueKey('login_options'),
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = isDesktop ? 32.0 : 20.0;
            final verticalPadding = constraints.maxHeight < 680 ? 8.0 : 14.0;
            final availableHeight =
                constraints.maxHeight - (verticalPadding * 2);

            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: SizedBox(
                      height: availableHeight,
                      child: _showEmailForm
                          ? _buildEmailOptionsLayout(
                              context,
                              isDesktop,
                              isLoading,
                              availableHeight,
                            )
                          : _buildProviderOptionsLayout(
                              context,
                              isDesktop,
                              isLoading,
                              availableHeight,
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandHeader({
    required bool isDesktop,
    required VoidCallback onBack,
  }) {
    return SizedBox(
      height: isDesktop ? 54 : 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _HeaderBackButton(onPressed: onBack),
          ),
          AppLogo(
            height: isDesktop ? 52 : 42,
            width: isDesktop ? 210 : 168,
            semanticLabel: false,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderOptionsLayout(
    BuildContext context,
    bool isDesktop,
    bool isLoading,
    double availableHeight,
  ) {
    final isShort = availableHeight < 720;
    final heroHeight = _clampDouble(
      availableHeight * (isDesktop ? 0.34 : 0.27),
      isShort ? 132 : 165,
      isDesktop ? 290 : 225,
    );
    final actionHeight = isShort ? 48.0 : 54.0;

    return Column(
      children: [
        _buildBrandHeader(
          isDesktop: isDesktop,
          onBack: () => setState(() {
            _showEmailForm = false;
            _showIntroScreen = true;
          }),
        ),
        SizedBox(height: isShort ? 4 : 8),
        SizedBox(
          height: heroHeight,
          width: double.infinity,
          child: const _AssistanceHeroScene(),
        ),
        SizedBox(height: isShort ? 6 : 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: isDesktop ? 40 : (isShort ? 27 : 31),
              height: 1.02,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
            children: const [
              TextSpan(text: 'Continúa con '),
              TextSpan(
                text: 'AutoResQ',
                style: TextStyle(color: AppColors.emergency),
              ),
            ],
          ),
        ),
        SizedBox(height: isShort ? 5 : 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Text(
            'Tu seguridad en carretera comienza con un solo paso.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 15.5 : (isShort ? 12.5 : 14),
              height: 1.3,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(height: isShort ? 10 : 16),
        _GoogleSignInButton(
          onPressed: isLoading ? null : _loginWithGoogle,
          label: 'Continuar con Google',
          height: actionHeight,
        ),
        SizedBox(height: isShort ? 8 : 10),
        _OutlineActionButton(
          label: 'Iniciar sesión',
          onPressed:
              isLoading ? null : () => setState(() => _showEmailForm = true),
          height: actionHeight,
        ),
        SizedBox(height: isShort ? 8 : 12),
        const _AuthDivider(),
        SizedBox(height: isShort ? 8 : 12),
        _PrimaryRedButton(
          label: 'Crear nueva cuenta',
          onPressed: isLoading ? null : () => context.push(AppRoutes.roleSelect),
          height: actionHeight,
        ),
        SizedBox(height: isShort ? 2 : 6),
        TextButton(
          onPressed: () => context.push(AppRoutes.forgotPassword),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(
            '¿Olvidaste tu contraseña?',
            style: TextStyle(
              fontSize: isDesktop ? 15 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        if (!isShort) const _CompactAuthFooter(),
      ],
    );
  }

  Widget _buildEmailOptionsLayout(
    BuildContext context,
    bool isDesktop,
    bool isLoading,
    double availableHeight,
  ) {
    final isShort = availableHeight < 680;
    return Column(
      children: [
        _buildBrandHeader(
          isDesktop: isDesktop,
          onBack: () => setState(() => _showEmailForm = false),
        ),
        SizedBox(height: isShort ? 8 : 18),
        Text(
          'Iniciar sesión',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 34 : 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.05,
          ),
        ),
        SizedBox(height: isDesktop ? 8 : 6),
        Text(
          'Ingresa con tu correo para continuar en AutoResQ.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 15.5 : 13.5,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        SizedBox(height: isShort ? 10 : 18),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: _clampDouble(
                  availableHeight * 0.75,
                  350,
                  isDesktop ? 520 : 470,
                ),
              ),
              child: _buildEmailForm(isLoading),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              const Text(
                'Ingresa con tu correo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showEmailForm = false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Cerrar'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _FieldLabel('EMAIL'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            textInputAction: TextInputAction.next,
            cursorColor: AppColors.primary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
            decoration: _inputDecoration('nombre@ejemplo.com'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const _FieldLabel('CONTRASEÑA'),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(AppRoutes.forgotPassword),
                child: const Text(
                  '¿OLVIDASTE?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePass,
            validator: Validators.password,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            cursorColor: AppColors.primary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
            ),
            decoration: _inputDecoration('••••••••').copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.secondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Text(
              'Tu seguridad es nuestra prioridad. Todos nuestros técnicos son verificados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.secondary.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : _login,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Text(
                'Continuar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (isLoading) ...[
            const SizedBox(height: 14),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.secondary.withValues(alpha: 0.5)),
      filled: true,
      fillColor: AppColors.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(
          color: AppColors.outline.withValues(alpha: 0.14),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(
          color: AppColors.outline.withValues(alpha: 0.14),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: AppColors.error, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HeaderBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AppColors.navy,
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 32),
    );
  }
}

class _IntroShowcaseCard extends StatelessWidget {
  const _IntroShowcaseCard();

  @override
  Widget build(BuildContext context) {
    return const _IntroLogoShowcase();
  }
}

class _IntroLogoShowcase extends StatelessWidget {
  const _IntroLogoShowcase();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: AppLogo(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            semanticLabel: false,
            variant: AppLogoVariant.withSloganLight,
          ),
        );
      },
    );
  }
}

class _IntroMetaItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IntroMetaItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textHint),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

class _IntroMetaDot extends StatelessWidget {
  const _IntroMetaDot();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '•',
      style: TextStyle(
        fontSize: 16,
        color: AppColors.textHint,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.secondary,
      ),
    );
  }
}

class _AssistanceHeroScene extends StatelessWidget {
  const _AssistanceHeroScene();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Image(
        image: AssetImage(
          'assets/images/ChatGPT Image 5 jun 2026, 19_21_02.png',
        ),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const _OutlineActionButton({
    required this.label,
    required this.onPressed,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceContainerLowest.withValues(alpha: 0.84),
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.outline.withValues(alpha: 0.9)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PrimaryRedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const _PrimaryRedButton({
    required this.label,
    required this.onPressed,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.outline,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'o',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.outline,
          ),
        ),
      ],
    );
  }
}

class _CompactAuthFooter extends StatelessWidget {
  const _CompactAuthFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: AppColors.textHint,
          ),
          SizedBox(width: 7),
          Text(
            'Acceso seguro y técnicos verificados',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final double height;

  const _GoogleSignInButton({
    this.onPressed,
    this.label = 'Ingresar con Google',
    this.height = 66,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navy,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.outline.withValues(alpha: 0.14)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.18;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    arcPaint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, _deg(-42), _deg(-102), false, arcPaint);

    arcPaint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, _deg(-144), _deg(-54), false, arcPaint);

    arcPaint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, _deg(162), _deg(-96), false, arcPaint);

    arcPaint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, _deg(66), _deg(-108), false, arcPaint);

    final cutPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        center.dx + radius * 0.05,
        center.dy - strokeWidth * 0.95,
        radius * 1.05,
        strokeWidth * 1.9,
      ),
      cutPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(center.dx + radius * 0.02, center.dy),
      Offset(size.width - strokeWidth * 0.45, center.dy),
      linePaint,
    );
  }

  double _deg(double degrees) => degrees * (math.pi / 180);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
