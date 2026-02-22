import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mamoney/utils/input_formatters.dart';

void main() {
  group('ThousandsSeparatorInputFormatter', () {
    late ThousandsSeparatorInputFormatter formatter;

    setUp(() {
      formatter = ThousandsSeparatorInputFormatter();
    });

    group('Basic Formatting', () {
      test('should format number with comma separator', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '1234');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1,234');
      });

      test('should format large number with multiple commas', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '1234567');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1,234,567');
      });

      test('should not add comma to numbers less than 1000', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '999');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '999');
      });

      test('should handle empty input', () {
        const oldValue = TextEditingValue(text: '123');
        const newValue = TextEditingValue(text: '');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '');
      });

      test('should remove existing commas before formatting', () {
        const oldValue = TextEditingValue(text: '1,234');
        const newValue = TextEditingValue(text: '1,2345');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '12,345');
      });
    });

    group('Cursor Position', () {
      test('should move cursor to end after formatting', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '1234');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.selection.baseOffset, result.text.length);
        expect(result.selection.extentOffset, result.text.length);
      });

      test('should maintain collapsed selection', () {
        const oldValue = TextEditingValue(text: '123');
        const newValue = TextEditingValue(text: '1234');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.selection.isCollapsed, isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle single digit', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '5');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '5');
      });

      test('should handle zero', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '0');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '0');
      });

      test('should handle very large numbers', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '9999999999');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '9,999,999,999');
      });

      test('should handle number with leading zeros', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '00123');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '123');
      });

      test('should return old value on invalid input', () {
        const oldValue = TextEditingValue(text: '123');
        const newValue = TextEditingValue(text: 'abc');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, oldValue.text);
      });

      test('should handle input with only commas', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: ',,,');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '');
      });

      test('should handle mixed valid and invalid characters', () {
        const oldValue = TextEditingValue(text: '123');
        const newValue = TextEditingValue(text: '123abc');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        // Should return old value since parse will fail
        expect(result.text, oldValue.text);
      });
    });

    group('Incremental Input', () {
      test('should handle incremental digit addition', () {
        var oldValue = const TextEditingValue(text: '');
        var newValue = const TextEditingValue(text: '1');
        var result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, '1');

        oldValue = result;
        newValue = const TextEditingValue(text: '12');
        result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, '12');

        oldValue = result;
        newValue = const TextEditingValue(text: '123');
        result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, '123');

        oldValue = result;
        newValue = const TextEditingValue(text: '1234');
        result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, '1,234');

        oldValue = result;
        newValue = const TextEditingValue(text: '1,2345');
        result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, '12,345');
      });

      test('should handle backspace operations', () {
        const oldValue = TextEditingValue(text: '1,234');
        const newValue = TextEditingValue(text: '1,23');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '123');
      });

      test('should handle deletion to empty', () {
        const oldValue = TextEditingValue(text: '1');
        const newValue = TextEditingValue(text: '');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '');
      });
    });

    group('Vietnamese Common Amounts', () {
      test('should format 5000 (5k)', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '5000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '5,000');
      });

      test('should format 10000 (10k)', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '10000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '10,000');
      });

      test('should format 50000 (50k)', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '50000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '50,000');
      });

      test('should format 100000 (100k)', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '100000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '100,000');
      });

      test('should format 1000000 (1m)', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '1000000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1,000,000');
      });

      test('should format 5000000 (5m)', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '5000000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '5,000,000');
      });
    });

    group('Boundary Conditions', () {
      test('should handle maximum safe integer', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '9007199254740991');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, contains(','));
      });

      test('should handle number at comma threshold (1000)', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '1000');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '1,000');
      });

      test('should handle number just below comma threshold (999)', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '999');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '999');
      });
    });

    group('Rapid Input', () {
      test('should handle rapid consecutive inputs without crashing', () {
        const inputs = ['1', '12', '123', '1234', '12345', '123456'];

        for (var i = 0; i < inputs.length; i++) {
          final oldValue = TextEditingValue(
            text: i > 0 ? inputs[i - 1] : '',
          );
          final newValue = TextEditingValue(text: inputs[i]);

          expect(
            () => formatter.formatEditUpdate(oldValue, newValue),
            returnsNormally,
          );
        }
      });

      test('should handle repeated format calls with same input', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '1234');

        final result1 = formatter.formatEditUpdate(oldValue, newValue);
        final result2 = formatter.formatEditUpdate(oldValue, newValue);
        final result3 = formatter.formatEditUpdate(oldValue, newValue);

        expect(result1.text, result2.text);
        expect(result2.text, result3.text);
      });
    });

    group('Special Characters', () {
      test('should reject special characters', () {
        const oldValue = TextEditingValue(text: '123');
        const newValue = TextEditingValue(text: '123@#\$');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, oldValue.text);
      });

      test('should reject decimal points', () {
        const oldValue = TextEditingValue(text: '123');
        const newValue = TextEditingValue(text: '123.45');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, oldValue.text);
      });

      test('should reject negative numbers', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '-123');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, oldValue.text);
      });

      test('should handle spaces in input', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '1 234');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        // Should fail to parse and return old value
        expect(result.text, oldValue.text);
      });
    });
  });
}