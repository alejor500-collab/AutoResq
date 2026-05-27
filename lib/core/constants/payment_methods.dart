import 'package:flutter/material.dart';

abstract class PaymentMethods {
  static const cash = 'cash';
  static const transfer = 'transfer';

  static const values = [cash, transfer];

  static String normalize(String? value) {
    final raw = value?.trim().toLowerCase();
    return values.contains(raw) ? raw! : cash;
  }

  static String label(String? value) {
    return switch (normalize(value)) {
      cash => 'Efectivo',
      transfer => 'Transferencia',
      _ => 'Efectivo',
    };
  }

  static String description(String? value) {
    return switch (normalize(value)) {
      cash => 'Pago directo al finalizar el servicio.',
      transfer => 'El tecnico coordinara sus datos bancarios o billetera.',
      _ => 'Pago directo al finalizar el servicio.',
    };
  }

  static IconData icon(String? value) {
    return switch (normalize(value)) {
      cash => Icons.payments_outlined,
      transfer => Icons.account_balance_outlined,
      _ => Icons.payments_outlined,
    };
  }
}
