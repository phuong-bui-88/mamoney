import 'package:flutter_test/flutter_test.dart';
import 'package:mamoney/screens/add_transaction_screen.dart';

void main() {
  group('ThousandsSeparatorInputFormatter', () {
    late ThousandsSeparatorInputFormatter formatter;

    setUp(() {
      formatter = ThousandsSeparatorInputFormatter();
    });

    test('should format empty string', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '');
    });

    test('should format single digit', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '5');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '5');
    });

    test('should format three digits without comma', () {
      const oldValue = TextEditingValue(text: '12');
      const newValue = TextEditingValue(text: '123');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '123');
    });

    test('should format four digits with comma', () {
      const oldValue = TextEditingValue(text: '123');
      const newValue = TextEditingValue(text: '1234');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '1,234');
      expect(result.selection.baseOffset, 5); // cursor at end
    });

    test('should format large number with multiple commas', () {
      const oldValue = TextEditingValue(text: '1,234');
      const newValue = TextEditingValue(text: '1234567');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '1,234,567');
      expect(result.selection.baseOffset, 9); // cursor at end
    });

    test('should handle million value', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '1000000');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '1,000,000');
    });

    test('should remove existing commas before formatting', () {
      const oldValue = TextEditingValue(text: '1,234');
      const newValue = TextEditingValue(text: '1,2345');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '12,345');
    });

    test('should return old value for invalid input', () {
      const oldValue = TextEditingValue(text: '123');
      const newValue = TextEditingValue(text: 'abc');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '123');
    });

    test('should handle mixed alphanumeric input by returning old value', () {
      const oldValue = TextEditingValue(text: '1,234');
      const newValue = TextEditingValue(text: '1,234a');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '1,234');
    });

    test('should handle deletion to empty string', () {
      const oldValue = TextEditingValue(text: '1,234');
      const newValue = TextEditingValue(text: '');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '');
    });

    test('should handle only commas input', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: ',,,');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, ',,,');
    });

    test('should format decimal value as integer', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '1234.5');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      // The formatter uses double.parse which handles decimals,
      // but formats as integer
      expect(result.text, '1,234');
    });

    test('should handle zero', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '0');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '0');
    });

    test('should format large value boundary case', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '999999999');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '999,999,999');
    });

    test('should handle negative numbers by returning old value', () {
      const oldValue = TextEditingValue(text: '123');
      const newValue = TextEditingValue(text: '-123');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '123');
    });
  });
}
