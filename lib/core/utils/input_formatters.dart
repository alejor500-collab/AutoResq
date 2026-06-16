import 'package:flutter/services.dart';

abstract class AppInputFormatters {
  static final name = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(
      RegExp("[A-Za-z\\u00C0-\\u00FF' -]"),
    ),
    LengthLimitingTextInputFormatter(80),
  ];

  static final email = <TextInputFormatter>[
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(254),
  ];

  static final phone = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  static final password = <TextInputFormatter>[
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(64),
  ];

  static final vehicleText = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(
      RegExp("[A-Za-z0-9\\u00C0-\\u00FF .'/+-]"),
    ),
    LengthLimitingTextInputFormatter(40),
  ];

  static final year = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
  ];

  static final plate = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
    LengthLimitingTextInputFormatter(8),
    TextInputFormatter.withFunction(
      (oldValue, newValue) => newValue.copyWith(
        text: newValue.text.toUpperCase(),
        selection: newValue.selection,
      ),
    ),
  ];

  static final money = <TextInputFormatter>[
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty || RegExp(r'^\d{0,5}([.,]\d{0,2})?$').hasMatch(text)) {
        return newValue;
      }
      return oldValue;
    }),
  ];

  static List<TextInputFormatter> limitedText(int maxLength) => [
        LengthLimitingTextInputFormatter(maxLength),
      ];
}
