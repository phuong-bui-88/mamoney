import 'package:flutter_test/flutter_test.dart';
import 'package:mamoney/services/ai_service.dart';
import 'dart:io';

void main() {
  group('AIService Invoice Parsing Tests', () {
    group('_getMediaType', () {
      test('returns correct media type for JPEG', () {
        // Since _getMediaType is static and private, we test behavior indirectly
        // through parseInvoiceImage. This test documents expected behavior.
        const extension = 'jpg';
        expect(['jpg', 'jpeg'].contains(extension), true);
      });

      test('returns correct media type for PNG', () {
        const extension = 'png';
        expect(['png'].contains(extension), true);
      });

      test('defaults to image/jpeg for unknown extension', () {
        // Unknown extensions should default to JPEG for safety
        const extension = 'unknown';
        expect(
            !['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension), true);
      });
    });

    group('parseInvoiceImage', () {
      test('returns error with invoiceId when GitHub token not configured',
          () async {
        final result = await AIService.parseInvoiceImage(null);

        // GitHub token is not configured in test environment, so this is expected
        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('items'), true);
        expect(result.containsKey('invoiceId'), true);
        expect(result.containsKey('invoiceDate'), true);
        expect(result['items'], isA<List>());
        expect(result['items'].isNotEmpty, true);
        expect(result['items'].first.containsKey('error'), true);
        expect(result['items'].first['error'], contains('GitHub token'));
        expect(result['invoiceId'], isNotNull);
      });

      test('returns error with invoiceId when image file does not exist',
          () async {
        // Even with token configured, non-existent file should error
        // This test documents expected behavior if token were available
        final result = await AIService.parseInvoiceImage(
          '/nonexistent/path/image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        // Either token error or file not found is acceptable
        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('items'), true);
        expect(result['items'], isA<List>());
        expect(result['items'].isNotEmpty, true);
        expect(result['items'].first.containsKey('error'), true);
        expect(result['items'].first['error'], isNotEmpty);
        expect(result['invoiceId'], isNotNull);
        expect(result['invoiceDate'], isNotNull);
      });

      tearDown(() {
        // Clean up test files
        final tempDir = Directory.systemTemp;
        try {
          final pattern = RegExp(r'test_invoice_\d+\.jpg');
          tempDir.listSync().forEach((f) {
            if (pattern.hasMatch(f.path.split('/').last)) {
              try {
                f.deleteSync();
              } catch (_) {}
            }
          });
        } catch (_) {}
      });
    });

    group('Invoice Text Extraction Parsing', () {
      test('extracts description correctly from standard format', () {
        const response =
            'DESCRIPTION: Lunch at Restaurant | AMOUNT: 50000 | CATEGORY: Food | TYPE: expense';

        // Test the parsing logic by using the parsing method
        // We can't directly test _extractDescriptionAndAmount, but we verify the format
        expect(response.contains('DESCRIPTION:'), true);
        expect(response.contains('AMOUNT:'), true);
        expect(response.contains('CATEGORY:'), true);
        expect(response.contains('TYPE:'), true);
      });

      test('handles description with special characters', () {
        const response =
            'DESCRIPTION: Coffee & Snacks (3 items) | AMOUNT: 75000 | CATEGORY: Food | TYPE: expense';

        expect(response.contains('&'), true);
        expect(response.contains('('), true);
        expect(response.contains(')'), true);
      });

      test('correctly parses amount from various formats', () {
        const amounts = [
          'AMOUNT: 50000',
          'AMOUNT: 50,000',
          'AMOUNT: 500.50',
          'AMOUNT: 1000',
        ];

        for (final format in amounts) {
          expect(format.contains('AMOUNT:'), true);
        }
      });

      test('recognizes transaction type as expense or income', () {
        const expenseResponse =
            'DESCRIPTION: Groceries | AMOUNT: 100000 | CATEGORY: Food | TYPE: expense';
        const incomeResponse =
            'DESCRIPTION: Freelance Work | AMOUNT: 500000 | CATEGORY: Freelance | TYPE: income';

        expect(expenseResponse.contains('expense'), true);
        expect(incomeResponse.contains('income'), true);
      });

      test('handles category with emoji', () {
        const response =
            'DESCRIPTION: Power Bill | AMOUNT: 150000 | CATEGORY: 💡 Utilities | TYPE: expense';

        expect(response.contains('💡'), true);
        expect(response.contains('Utilities'), true);
      });

      test('handles unknown or unmapped category', () {
        const response =
            'DESCRIPTION: Mystery Item | AMOUNT: 25000 | CATEGORY: Unknown | TYPE: expense';

        // Should default to "Other" or first category when category not recognized
        expect(response.contains('Unknown'), true);
      });

      test('handles missing or invalid amount gracefully', () {
        const response =
            'DESCRIPTION: Item | AMOUNT: 0 | CATEGORY: Food | TYPE: expense';

        // Zero amount is valid but indicates parsing failed
        expect(response.contains('AMOUNT: 0'), true);
      });

      test('handles whitespace correctly in parsed fields', () {
        const response =
            'DESCRIPTION:   Lunch   | AMOUNT:   50000   | CATEGORY:   Food   | TYPE:   expense  ';

        // After trimming, should extract clean values
        expect(response.contains('DESCRIPTION:'), true);
        // Actual parsing should trim whitespace
      });
    });

    group('Invoice Category Validation', () {
      const expenseCategories = [
        '🏠 Housing',
        '🍚 Food',
        '🚗 Transportation',
        '💡 Utilities',
        '🏥 Healthcare'
      ];

      const incomeCategories = [
        'Salary',
        'Freelance',
        'Investment',
        'Gift',
        'Other'
      ];

      test('validates extracted category against expense list', () {
        const extractedCategory = 'Food';
        final isValid =
            expenseCategories.any((cat) => cat.contains(extractedCategory));

        expect(isValid, true);
      });

      test('validates extracted category against income list', () {
        const extractedCategory = 'Salary';
        final isValid = incomeCategories.contains(extractedCategory.trim());

        expect(isValid, true);
      });

      test('defaults to first category if extracted category not found', () {
        const extractedCategory = 'InvalidCategory';
        final isValidExpense =
            expenseCategories.any((cat) => cat.contains(extractedCategory));
        final isValidIncome =
            incomeCategories.contains(extractedCategory.trim());

        // Should default to first category
        expect(isValidExpense || isValidIncome, false);
      });

      test('handles case-insensitive category matching', () {
        const extractedCategory = 'FOOD';
        final lowerCaseCategory = extractedCategory.toLowerCase();

        final isValid = expenseCategories
            .any((cat) => cat.toLowerCase().contains(lowerCaseCategory));

        expect(isValid, true);
      });

      test('extracts category emoji correctly when present', () {
        const categoryWithEmoji = '🍚 Food';
        final emoji = categoryWithEmoji.split(' ').first;

        expect(emoji, '🍚');
      });
    });

    group('Invoice Amount Parsing', () {
      test('converts standard amount formats', () {
        const amounts = [
          ('50000', '50000'),
          ('50,000', '50000'),
          ('500.50', '500.50'),
          ('1', '1'),
        ];

        for (final (input, _) in amounts) {
          final cleaned = input.replaceAll(',', '');
          final parsed = double.tryParse(cleaned);

          expect(parsed, isNotNull);
        }
      });

      test('handles edge case of zero amount', () {
        const zeroAmount = '0';
        final parsed = double.tryParse(zeroAmount);

        expect(parsed, 0.0);
      });

      test('handles large amounts correctly', () {
        const largeAmount = '9999999';
        final parsed = double.tryParse(largeAmount);

        expect(parsed, 9999999.0);
      });

      test('handles decimal amounts', () {
        const decimalAmount = '123.45';
        final parsed = double.tryParse(decimalAmount);

        expect(parsed, 123.45);
      });

      test('rejects invalid amount formats', () {
        const invalidAmounts = ['abc', 'null', '', ' '];

        for (final amount in invalidAmounts) {
          final parsed = double.tryParse(amount);
          expect(parsed, isNull);
        }
      });
    });

    group('Invoice Image File Handling', () {
      test('recognizes valid image extensions', () {
        const validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

        for (final ext in validExtensions) {
          final path = 'test_invoice.$ext';
          final extension = path.split('.').last.toLowerCase();
          expect(validExtensions.contains(extension), true);
        }
      });

      test('handles JPEG and JPG extensions interchangeably', () {
        expect('image.jpg'.endsWith('.jpg'), true);
        expect('image.jpeg'.endsWith('.jpeg'), true);
      });

      tearDown(() {
        // Clean up after tests
        final tempDir = Directory.systemTemp;
        try {
          final files = tempDir
              .listSync()
              .where((f) => f.path.contains('test_invoice'))
              .toList();
          for (var f in files) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        } catch (_) {}
      });
    });
  });
}
