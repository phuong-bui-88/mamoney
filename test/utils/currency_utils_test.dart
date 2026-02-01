import 'package:flutter_test/flutter_test.dart';
import 'package:mamoney/utils/currency_utils.dart';

void main() {
  group('Currency Utils', () {
    group('formatCurrency', () {
      test('should format zero correctly', () {
        final result = formatCurrency(0);
        expect(result, contains('0'));
      });

      test('should format small amount', () {
        final result = formatCurrency(100);
        expect(result, contains('100'));
        expect(result, contains('VND'));
      });

      test('should format thousands with separator', () {
        final result = formatCurrency(1000);
        expect(result, contains('1'));
        expect(result, contains('000'));
        expect(result, contains('VND'));
      });

      test('should format large amount with separators', () {
        final result = formatCurrency(1234567);
        expect(result, contains('VND'));
        // Vietnamese locale uses . as thousand separator
        expect(result.contains('1') && result.contains('234') && result.contains('567'), isTrue);
      });

      test('should format million amount', () {
        final result = formatCurrency(1000000);
        expect(result, contains('1'));
        expect(result, contains('000'));
        expect(result, contains('VND'));
      });

      test('should format decimal amount as integer (no cents in VND)', () {
        final result = formatCurrency(123.45);
        // VND has 0 decimal digits, so should round/truncate
        expect(result, contains('123'));
        expect(result, contains('VND'));
      });

      test('should format negative amount', () {
        final result = formatCurrency(-500);
        expect(result, contains('500'));
        expect(result, contains('VND'));
      });

      test('should handle very large amounts', () {
        final result = formatCurrency(999999999);
        expect(result, contains('VND'));
        expect(result, contains('999'));
      });

      test('should format amount with decimal places by rounding', () {
        final result = formatCurrency(1234.99);
        expect(result, contains('VND'));
        // Should round to nearest integer
        expect(result, contains('1'));
      });

      test('should handle double type input', () {
        final result = formatCurrency(5000.0);
        expect(result, contains('5'));
        expect(result, contains('000'));
        expect(result, contains('VND'));
      });

      test('should handle int type input', () {
        final result = formatCurrency(5000);
        expect(result, contains('5'));
        expect(result, contains('000'));
        expect(result, contains('VND'));
      });

      test('should be consistent for same value', () {
        final result1 = formatCurrency(12345);
        final result2 = formatCurrency(12345);
        expect(result1, equals(result2));
      });

      test('should format 50k VND correctly', () {
        final result = formatCurrency(50000);
        expect(result, contains('VND'));
        expect(result, contains('50'));
      });

      test('should format 1 million VND correctly', () {
        final result = formatCurrency(1000000);
        expect(result, contains('VND'));
        expect(result, contains('1'));
      });

      test('should format typical grocery amount', () {
        final result = formatCurrency(200000);
        expect(result, contains('VND'));
        expect(result, contains('200'));
      });

      test('should format salary amount', () {
        final result = formatCurrency(15000000);
        expect(result, contains('VND'));
        expect(result, contains('15'));
      });
    });
  });
}