import 'package:flutter_test/flutter_test.dart';
import 'package:autoresq/core/utils/validators.dart';

void main() {
  group('Validators.phone', () {
    test('accepts a 10 digit Ecuadorian mobile number', () {
      expect(Validators.phone('0991234567'), isNull);
    });

    test('rejects incomplete, oversized and non-mobile numbers', () {
      expect(Validators.phone('099123456'), isNotNull);
      expect(Validators.phone('09912345678'), isNotNull);
      expect(Validators.phone('0212345678'), isNotNull);
    });
  });

  group('Validators.year', () {
    test('accepts a plausible four digit vehicle year', () {
      expect(Validators.year('2020'), isNull);
    });

    test('rejects ancient, short and future years', () {
      expect(Validators.year('1220'), isNotNull);
      expect(Validators.year('220'), isNotNull);
      expect(
        Validators.year('${DateTime.now().year + 2}'),
        isNotNull,
      );
    });
  });

  group('Validators.plate', () {
    test('accepts common Ecuadorian plate formats', () {
      expect(Validators.plate('ABC-1234'), isNull);
      expect(Validators.plate('ABC123'), isNull);
    });

    test('rejects malformed plates', () {
      expect(Validators.plate('12-ABC'), isNotNull);
      expect(Validators.plate('AB-1234'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('requires length, letters and numbers', () {
      expect(Validators.password('Clave123'), isNull);
      expect(Validators.password('sololetras'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('Abc 1234'), isNotNull);
    });

    test('confirmation must match', () {
      expect(
        Validators.confirmPassword('Clave123', 'Clave123'),
        isNull,
      );
      expect(
        Validators.confirmPassword('Clave124', 'Clave123'),
        isNotNull,
      );
    });
  });

  group('Validators Ecuador-specific data', () {
    test('validates Ecuadorian identity numbers', () {
      expect(Validators.ecuadorianId('1710034065'), isNull);
      expect(Validators.ecuadorianId('1710034064'), isNotNull);
    });

    test('validates monetary values with two decimals', () {
      expect(Validators.amount('8.50'), isNull);
      expect(Validators.amount('8,50'), isNull);
      expect(Validators.amount('8.555'), isNotNull);
      expect(Validators.amount('0'), isNotNull);
    });
  });
}
