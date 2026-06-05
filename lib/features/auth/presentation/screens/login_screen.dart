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

  void _handlePrimaryAction(bool isLoading) {
    if (isLoading) return;
    if (_showEmailForm) {
      _login();
      return;
    }
    setState(() => _showEmailForm = true);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
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
    return SafeArea(
      key: const ValueKey('login_intro'),
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 34 : 22,
            isDesktop ? 30 : 20,
            isDesktop ? 34 : 22,
            isDesktop ? 28 : 22,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 640 : 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'AUTORESQ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 34 : 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: const Color(0xFF141518),
                  ),
                ),
                SizedBox(height: isDesktop ? 28 : 18),
                const _IntroShowcaseCard(),
                SizedBox(height: isDesktop ? 36 : 28),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: isDesktop ? 58 : 36,
                      height: 1.06,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF141518),
                    ),
                    children: const [
                      TextSpan(text: 'Asistencia\nVehicular\n'),
                      TextSpan(
                        text: 'Inteligente',
                        style: TextStyle(color: Color(0xFFD50B14)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isDesktop ? 28 : 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Diagnóstico con IA, geolocalización y asistencia en tiempo real para tu total tranquilidad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 20 : 15.5,
                      height: 1.65,
                      color: const Color(0xFF6D7178),
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 38 : 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => setState(() => _showIntroScreen = false),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1C1E),
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, isDesktop ? 90 : 72),
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
                            fontSize: isDesktop ? 24 : 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(width: isDesktop ? 16 : 14),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: isDesktop ? 22 : 18,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isDesktop ? 28 : 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
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
  }

  Widget _buildOptionsScreen(
    BuildContext context,
    bool isDesktop,
    bool isLoading,
  ) {
    return Stack(
      key: const ValueKey('login_options'),
      children: [
        const _LoginBackdrop(),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : 22,
                isDesktop ? 26 : 18,
                isDesktop ? 28 : 22,
                isDesktop ? 28 : 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 620 : 520),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _HeaderBackButton(
                            onPressed: () => setState(() {
                              _showEmailForm = false;
                              _showIntroScreen = true;
                            }),
                          ),
                          Expanded(
                            child: Text(
                              'AutoResQ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isDesktop ? 28 : 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: const Color(0xFF17181B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 44),
                        ],
                      ),
                      SizedBox(height: isDesktop ? 24 : 18),
                      const _AuthHeroCard(),
                      SizedBox(height: isDesktop ? 32 : 24),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: isDesktop ? 56 : 36,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF15171A),
                          ),
                          children: const [
                            TextSpan(text: 'Continúa con\n'),
                            TextSpan(
                              text: 'AutoResQ',
                              style: TextStyle(color: Color(0xFFD30A11)),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isDesktop ? 22 : 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Text(
                          'Tu seguridad en carretera comienza con un solo paso.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 15.5,
                            height: 1.5,
                            color: const Color(0xFF666A72),
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 34 : 28),
                      _GoogleSignInButton(
                        onPressed: isLoading ? null : _loginWithGoogle,
                        label: 'Continuar con Google',
                        height: isDesktop ? 82 : 66,
                      ),
                      const SizedBox(height: 16),
                      _OutlineActionButton(
                        label: _showEmailForm ? 'Continuar' : 'Iniciar sesión',
                        onPressed: isLoading
                            ? null
                            : () => _handlePrimaryAction(isLoading),
                        height: isDesktop ? 82 : 66,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: !_showEmailForm
                              ? const SizedBox(height: 18)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: _buildEmailForm(isLoading),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _AuthDivider(),
                      const SizedBox(height: 18),
                      _PrimaryRedButton(
                        label: 'Crear nueva cuenta',
                        onPressed: isLoading
                            ? null
                            : () => context.push(AppRoutes.roleSelect),
                        height: isDesktop ? 82 : 66,
                      ),
                      SizedBox(height: isDesktop ? 28 : 24),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.forgotPassword),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4F5259),
                        ),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 50 : 42),
                      const _AuthFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
          const SizedBox(height: 18),
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
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.secondary.withValues(alpha: 0.5)),
      filled: true,
      fillColor: const Color(0xFFF7FAFF),
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

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -110,
          left: -90,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.tertiary.withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          right: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
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
        foregroundColor: const Color(0xFF1A1B1E),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 32),
    );
  }
}

class _IntroShowcaseCard extends StatelessWidget {
  const _IntroShowcaseCard();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(52),
          gradient: const RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.1,
            colors: [
              Color(0xFF4C575D),
              Color(0xFF242B2F),
              Color(0xFF171B1E),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 34,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(52),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: _IntroLogoShowcase(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroLogoShowcase extends StatelessWidget {
  const _IntroLogoShowcase();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: constraints.maxHeight * 0.14,
              child: Align(
                child: Container(
                  width: constraints.maxWidth * 0.52,
                  height: constraints.maxWidth * 0.52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8A4C).withValues(alpha: 0.8),
                        blurRadius: 42,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: constraints.maxHeight * 0.11,
              child: Align(
                child: Container(
                  width: constraints.maxWidth * 0.12,
                  height: constraints.maxHeight * 0.28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFFFB184).withValues(alpha: 0.85),
                        const Color(0xFFFF8A4C).withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: constraints.maxHeight * 0.22,
              child: Align(
                child: SizedBox(
                  width: constraints.maxWidth * 0.72,
                  child: const AppLogo(
                    semanticLabel: false,
                  ),
                ),
              ),
            ),
            Positioned(
              left: constraints.maxWidth * 0.16,
              right: constraints.maxWidth * 0.16,
              bottom: constraints.maxHeight * 0.14,
              child: Container(
                height: constraints.maxHeight * 0.1,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.56),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
        Icon(icon, size: 18, color: const Color(0xFFB7BAC0)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Color(0xFFB0B3B9),
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
        color: Color(0xFFC6C8CC),
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

class _AuthHeroCard extends StatelessWidget {
  const _AuthHeroCard();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.32,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(44),
          color: Colors.white.withValues(alpha: 0.92),
          border: Border.all(color: const Color(0xFFE7EBF4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB8C7EA).withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: const _AssistanceHeroScene(),
        ),
      ),
    );
  }
}

class _AssistanceHeroScene extends StatelessWidget {
  const _AssistanceHeroScene();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.15),
                    radius: 1.18,
                    colors: [
                      Colors.white,
                      const Color(0xFFF8FAFF),
                      const Color(0xFFEEF3FF),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: width * 0.78,
              top: height * 0.16,
              child: Opacity(
                opacity: 0.22,
                child: _CityBackdrop(
                  width: width * 0.18,
                  height: height * 0.34,
                ),
              ),
            ),
            Positioned(
              left: width * 0.03,
              top: height * 0.14,
              child: Opacity(
                opacity: 0.18,
                child: _CityBackdrop(
                  width: width * 0.16,
                  height: height * 0.3,
                ),
              ),
            ),
            Positioned(
              left: width * 0.12,
              right: width * 0.12,
              top: height * 0.1,
              child: CustomPaint(
                size: Size(width * 0.76, height * 0.34),
                painter: _DashedArcPainter(),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: height * 0.03),
                  child: _ToolHeroBadge(size: width * 0.14),
                ),
              ),
            ),
            Positioned(
              left: width * 0.08,
              bottom: height * 0.14,
              child: _BlueCarHero(
                width: width * 0.34,
                height: height * 0.28,
              ),
            ),
            Positioned(
              right: width * 0.08,
              bottom: height * 0.13,
              child: _VanHero(
                width: width * 0.29,
                height: height * 0.27,
              ),
            ),
            Positioned(
              left: width * 0.455,
              bottom: height * 0.4,
              child: Opacity(
                opacity: 0.4,
                child: Icon(
                  Icons.air_rounded,
                  size: width * 0.05,
                  color: const Color(0xFF9AA6BD),
                ),
              ),
            ),
            Positioned(
              left: width * 0.1,
              right: width * 0.1,
              bottom: height * 0.12,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFE3ECFF),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CityBackdrop extends StatelessWidget {
  final double width;
  final double height;

  const _CityBackdrop({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SkylineBar(width: width * 0.16, height: height * 0.58),
          SizedBox(width: width * 0.06),
          _SkylineBar(width: width * 0.24, height: height * 0.88),
          SizedBox(width: width * 0.06),
          _SkylineBar(width: width * 0.14, height: height * 0.46),
          SizedBox(width: width * 0.06),
          _SkylineBar(width: width * 0.2, height: height * 0.72),
        ],
      ),
    );
  }
}

class _SkylineBar extends StatelessWidget {
  final double width;
  final double height;

  const _SkylineBar({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFDDE6F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
    );
  }
}

class _DashedArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2F73FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.02, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.5,
        -size.height * 0.2,
        size.width * 0.98,
        size.height * 0.92,
      );

    const dashWidth = 8.0;
    const dashSpace = 7.0;
    final metric = path.computeMetrics().first;
    var distance = 0.0;
    while (distance < metric.length) {
      final next = math.min(distance + dashWidth, metric.length);
      canvas.drawPath(metric.extractPath(distance, next), paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ToolHeroBadge extends StatelessWidget {
  final double size;

  const _ToolHeroBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2F73FF), Color(0xFF0A5BE4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F73FF).withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.build_rounded,
        color: Colors.white,
        size: size * 0.46,
      ),
    );
  }
}

class _BlueCarHero extends StatelessWidget {
  final double width;
  final double height;

  const _BlueCarHero({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: width * 0.08,
            right: width * 0.04,
            bottom: height * 0.18,
            child: Container(
              height: height * 0.42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2F73FF), Color(0xFF1E59D9)],
                ),
                borderRadius: BorderRadius.circular(height * 0.18),
              ),
            ),
          ),
          Positioned(
            left: width * 0.22,
            right: width * 0.26,
            bottom: height * 0.48,
            child: Container(
              height: height * 0.16,
              decoration: const BoxDecoration(
                color: Color(0xFF8AB1FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            right: width * 0.06,
            bottom: height * 0.48,
            child: Transform.rotate(
              angle: -0.58,
              child: Container(
                width: width * 0.04,
                height: height * 0.42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A67EA),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Positioned(
            left: width * 0.17,
            bottom: 0,
            child: _HeroWheel(size: height * 0.28),
          ),
          Positioned(
            right: width * 0.16,
            bottom: 0,
            child: _HeroWheel(size: height * 0.28),
          ),
        ],
      ),
    );
  }
}

class _VanHero extends StatelessWidget {
  final double width;
  final double height;

  const _VanHero({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: width * 0.05,
            right: width * 0.05,
            bottom: height * 0.18,
            child: Container(
              height: height * 0.46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(height * 0.14),
                border: Border.all(color: const Color(0xFFD7DFED)),
              ),
            ),
          ),
          Positioned(
            left: width * 0.08,
            width: width * 0.24,
            bottom: height * 0.47,
            child: Container(
              height: height * 0.16,
              decoration: BoxDecoration(
                color: const Color(0xFFDDEAFF),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned(
            right: width * 0.01,
            bottom: height * 0.32,
            child: Container(
              width: height * 0.34,
              height: height * 0.34,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: height * 0.24,
                  height: height * 0.24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFF1F1),
                    border: Border.all(color: const Color(0xFFE64040)),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFE21218),
                    size: 12,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: width * 0.48,
            bottom: height * 0.68,
            child: Container(
              width: width * 0.08,
              height: height * 0.07,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB136),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            left: width * 0.18,
            bottom: 0,
            child: _HeroWheel(size: height * 0.26),
          ),
          Positioned(
            right: width * 0.16,
            bottom: 0,
            child: _HeroWheel(size: height * 0.26),
          ),
        ],
      ),
    );
  }
}

class _HeroWheel extends StatelessWidget {
  final double size;

  const _HeroWheel({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF485363),
      ),
      child: Center(
        child: Container(
          width: size * 0.42,
          height: size * 0.42,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFDDE7FA),
          ),
        ),
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
          backgroundColor: Colors.white.withValues(alpha: 0.72),
          foregroundColor: const Color(0xFF15171A),
          side: BorderSide(color: const Color(0xFFD9DBE0).withValues(alpha: 0.9)),
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
          backgroundColor: const Color(0xFFE21218),
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
            color: const Color(0xFFD9DBDF),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'o',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5A5E65),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFD9DBDF),
          ),
        ),
      ],
    );
  }
}

class _AuthFooter extends StatelessWidget {
  const _AuthFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FooterShield(icon: Icons.verified_user_outlined),
            SizedBox(width: 28),
            _FooterShield(icon: Icons.security_outlined),
            SizedBox(width: 28),
            _FooterShield(icon: Icons.privacy_tip_outlined),
          ],
        ),
        SizedBox(height: 22),
        Text(
          'SERVICIO AUTORIZADO RIOBAMBA',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.8,
            color: Color(0xFFB1B4BA),
          ),
        ),
      ],
    );
  }
}

class _FooterShield extends StatelessWidget {
  final IconData icon;

  const _FooterShield({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 32, color: const Color(0xFFB8BBC1));
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
          foregroundColor: const Color(0xFF13284D),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.outline.withValues(alpha: 0.14)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
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
                color: Color(0xFF13284D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 3.5;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect =
        Rect.fromCircle(center: Offset.zero, radius: radius - strokeWidth / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    arcPaint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -0.52, -1.57, false, arcPaint);

    arcPaint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -2.09, -1.57, false, arcPaint);

    arcPaint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 2.62, 1.57, false, arcPaint);

    arcPaint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.52, 1.57, false, arcPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset.zero,
      Offset(radius - strokeWidth / 2, 0),
      linePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
