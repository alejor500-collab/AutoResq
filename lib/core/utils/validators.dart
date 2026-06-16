import '../constants/app_strings.dart';

abstract class Validators {
  static const int nameMaxLength = 80;
  static const int emailMaxLength = 254;
  static const int phoneLength = 10;
  static const int passwordMaxLength = 64;
  static const int vehicleTextMaxLength = 40;
  static const int reviewMaxLength = 500;
  static const int messageMaxLength = 1000;
  static const int longTextMaxLength = 1000;

  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final normalized = value.trim();
    if (normalized.length > emailMaxLength) {
      return 'El correo no puede exceder $emailMaxLength caracteres';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(normalized)) {
      return AppStrings.emailInvalid;
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (value.length < 8) {
      return AppStrings.passwordTooShort;
    }
    if (value.length > passwordMaxLength) {
      return 'La contrasena no puede exceder $passwordMaxLength caracteres';
    }
    if (value.contains(RegExp(r'\s'))) {
      return 'La contrasena no puede contener espacios';
    }
    if (!value.contains(RegExp(r'[A-Za-z]')) ||
        !value.contains(RegExp(r'[0-9]'))) {
      return 'Incluye al menos una letra y un numero';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (value.length > passwordMaxLength) {
      return 'La contrasena no puede exceder $passwordMaxLength caracteres';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    final base = password(value);
    if (base != null) return base;
    if (value != original) return AppStrings.passwordsNoMatch;
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final digits = value.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length != phoneLength) {
      return 'Ingresa los $phoneLength digitos del celular';
    }
    if (!digits.startsWith('09')) {
      return 'El celular debe empezar con 09';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    if (normalized.length > nameMaxLength) {
      return 'El nombre no puede exceder $nameMaxLength caracteres';
    }
    final nameRegex = RegExp("^[A-Za-z\\u00C0-\\u00FF' -]+\$");
    if (!nameRegex.hasMatch(normalized)) {
      return 'El nombre solo puede contener letras, espacios y apostrofes';
    }
    return null;
  }

  static String? year(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final normalized = value.trim();
    if (normalized.length != 4) return 'El ano debe tener 4 digitos';
    final parsed = int.tryParse(normalized);
    if (parsed == null) return 'El ano debe ser numerico';
    final current = DateTime.now().year;
    if (parsed < 1900 || parsed > current + 1) {
      return 'Ingresa un ano entre 1900 y ${current + 1}';
    }
    return null;
  }

  static String? plate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    final normalized =
        value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^[A-Z]{3}[0-9]{3,4}$').hasMatch(normalized)) {
      return 'Usa una placa ecuatoriana valida, por ejemplo ABC-1234';
    }
    return null;
  }

  static String? vehicleText(
    String? value, {
    required String fieldName,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa $fieldName';
    }
    final normalized = value.trim();
    if (normalized.length < 2) {
      return '$fieldName debe tener al menos 2 caracteres';
    }
    if (normalized.length > vehicleTextMaxLength) {
      return '$fieldName no puede exceder $vehicleTextMaxLength caracteres';
    }
    if (!RegExp("^[A-Za-z0-9\\u00C0-\\u00FF .'/+-]+\$")
        .hasMatch(normalized)) {
      return '$fieldName contiene caracteres no permitidos';
    }
    return null;
  }

  static String? optionalText(
    String? value, {
    required int maxLength,
    String fieldName = 'El texto',
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.length > maxLength) {
      return '$fieldName no puede exceder $maxLength caracteres';
    }
    return null;
  }

  static String? textRange(
    String? value, {
    required int minLength,
    required int maxLength,
    String fieldName = 'El texto',
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return AppStrings.fieldRequired;
    if (normalized.length < minLength) {
      return '$fieldName debe tener al menos $minLength caracteres';
    }
    if (normalized.length > maxLength) {
      return '$fieldName no puede exceder $maxLength caracteres';
    }
    return null;
  }

  static String? amount(
    String? value, {
    double min = 0.01,
    double max = 10000,
  }) {
    final raw = value?.trim() ?? '';
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null) return 'Ingresa un valor numerico valido';
    if (parsed < min || parsed > max) {
      return 'Ingresa un valor entre $min y $max';
    }
    if (!RegExp(r'^\d{1,5}([.,]\d{1,2})?$').hasMatch(raw)) {
      return 'Usa maximo 2 decimales';
    }
    return null;
  }

  static String? ecuadorianId(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.length != 10) return 'La cedula debe tener 10 digitos';
    final province = int.tryParse(digits.substring(0, 2)) ?? 0;
    if (province < 1 || province > 24 || int.parse(digits[2]) > 5) {
      return 'La cedula ecuatoriana no es valida';
    }
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      var digit = int.parse(digits[i]);
      if (i.isEven) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    final verifier = (10 - (sum % 10)) % 10;
    if (verifier != int.parse(digits[9])) {
      return 'La cedula ecuatoriana no es valida';
    }
    return null;
  }

  static String? minLength(String? value, int min) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    if (value.trim().length < min) {
      return 'Minimo $min caracteres';
    }
    return null;
  }
}
