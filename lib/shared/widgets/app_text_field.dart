import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

enum _FieldState { idle, valid, invalid }

class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
    with SingleTickerProviderStateMixin {
  bool _obscure = false;
  late final FocusNode _internalFocus;
  bool _hasFocus = false;
  _FieldState _fieldState = _FieldState.idle;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _internalFocus = widget.focusNode ?? FocusNode();
    _internalFocus.addListener(_onFocusChange);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _internalFocus.hasFocus);
    if (!_internalFocus.hasFocus) _runValidation();
  }

  void _runValidation([String? value]) {
    if (widget.validator == null) return;
    final text = value ?? widget.controller?.text ?? '';
    final error = widget.validator!(text);
    final next = text.isEmpty
        ? _FieldState.idle
        : (error == null ? _FieldState.valid : _FieldState.invalid);

    if (next == _FieldState.invalid && _fieldState != _FieldState.invalid) {
      _shakeController.forward(from: 0);
    }
    if (next != _fieldState) setState(() => _fieldState = next);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    if (widget.focusNode == null) _internalFocus.dispose();
    super.dispose();
  }

  Color get _fillColor {
    switch (_fieldState) {
      case _FieldState.valid:
        return AppColors.success.withOpacity(0.07);
      case _FieldState.invalid:
        return AppColors.error.withOpacity(0.05);
      case _FieldState.idle:
        return _hasFocus
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainerLow;
    }
  }

  InputBorder get _enabledBorder {
    if (_fieldState == _FieldState.valid) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: AppColors.success.withOpacity(0.4),
          width: 1.5,
        ),
      );
    }
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final dx = _shakeController.isAnimating
            ? 6 * (0.5 - (_shakeAnimation.value % 1)).abs() *
                (_shakeAnimation.value < 0.5 ? 1 : -1)
            : 0.0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: _fieldState == _FieldState.valid
                        ? AppColors.success
                        : AppColors.secondary,
                  ),
                ),
                if (_fieldState == _FieldState.valid) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle_rounded,
                      size: 12, color: AppColors.success),
                ],
              ],
            ),
          ),
          // Input
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuart,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: _fillColor,
            ),
            child: TextFormField(
              controller: widget.controller,
              validator: (v) {
                final err = widget.validator?.call(v);
                final next = (v == null || v.isEmpty)
                    ? _FieldState.idle
                    : (err == null ? _FieldState.valid : _FieldState.invalid);
                if (next == _FieldState.invalid &&
                    _fieldState != _FieldState.invalid) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _shakeController.forward(from: 0));
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) {
                  if (mounted && next != _fieldState) {
                    setState(() => _fieldState = next);
                  }
                });
                return err;
              },
              keyboardType: widget.keyboardType,
              obscureText: _obscure,
              maxLines: widget.obscureText ? 1 : widget.maxLines,
              maxLength: widget.maxLength,
              inputFormatters: widget.inputFormatters,
              onChanged: (v) {
                _runValidation(v);
                widget.onChanged?.call(v);
              },
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              textInputAction: widget.textInputAction,
              focusNode: _internalFocus,
              autofocus: widget.autofocus,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  color: AppColors.secondary.withOpacity(0.5),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: widget.prefixIcon,
                suffixIcon: widget.obscureText
                    ? IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )
                    : widget.suffixIcon,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: _enabledBorder,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: _fieldState == _FieldState.valid
                        ? AppColors.success.withOpacity(0.4)
                        : AppColors.primary.withOpacity(0.2),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
