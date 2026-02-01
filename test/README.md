# Mamoney Test Suite

## Overview
This directory contains comprehensive unit and widget tests for the Mamoney application. The test suite covers all business logic, utility functions, models, and services.

## Directory Structure

```
test/
├── README.md                                      # This file
├── widget_test.dart                               # Original widget test (legacy)
├── models/
│   └── transaction_test.dart                      # Transaction model tests (30+ tests)
├── screens/
│   ├── add_transaction_screen_test.dart           # ThousandsSeparatorInputFormatter tests (15 tests)
│   └── add_transaction_screen_widget_test.dart    # ChatMessage & TransactionRecord tests (35+ tests)
├── services/
│   ├── ai_config_test.dart                        # AI configuration tests (30+ tests)
│   ├── ai_service_test.dart                       # AI service tests (25+ tests)
│   └── transaction_provider_test.dart             # Transaction provider tests (20+ tests)
└── utils/
    └── currency_utils_test.dart                   # Currency formatting tests (16 tests)
```

## Test Files

### Models
- **transaction_test.dart** - Tests for the Transaction model including serialization, deserialization, and copyWith functionality

### Screens
- **add_transaction_screen_test.dart** - Tests for ThousandsSeparatorInputFormatter input validation
- **add_transaction_screen_widget_test.dart** - Tests for ChatMessage and TransactionRecord classes

### Services
- **ai_config_test.dart** - Tests for AI configuration constants and URL construction
- **ai_service_test.dart** - Tests for AI service message parsing and extraction logic
- **transaction_provider_test.dart** - Tests for transaction provider state management and computed properties

### Utils
- **currency_utils_test.dart** - Tests for Vietnamese Dong currency formatting

## Running Tests

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/services/ai_service_test.dart
```

### Run tests with coverage
```bash
flutter test --coverage
```

### Run tests in a specific directory
```bash
flutter test test/services/
```

### Run tests in verbose mode
```bash
flutter test --reporter expanded
```

## Test Statistics

- **Total Test Files:** 7 (excluding legacy widget_test.dart)
- **Total Tests:** 170+
- **Coverage Areas:** Models, Services, Screens, Utils

## Test Coverage

### Models (30+ tests)
- Transaction model serialization
- Type conversions
- copyWith functionality
- Edge cases

### Services (75+ tests)
- AI service message parsing
- Transaction provider state management
- Configuration validation
- Error handling

### Screens (50+ tests)
- Input formatting
- Chat messages
- Transaction records
- UI components

### Utils (16+ tests)
- Currency formatting
- Vietnamese locale
- Number formatting

## Test Quality

All tests follow these principles:

1. **Arrange-Act-Assert** - Clear test structure
2. **Isolation** - Tests don't depend on each other
3. **Descriptive Names** - Test names clearly describe the scenario
4. **Edge Cases** - Tests cover boundary conditions
5. **Error Cases** - Tests verify error handling

## Common Test Patterns

### Testing a simple function
```dart
test('should format currency correctly', () {
  final result = formatCurrency(1000);
  expect(result, contains('VND'));
});
```

### Testing state changes
```dart
test('should update loading state', () {
  provider.isLoading = true;
  expect(provider.isLoading, isTrue);
});
```

### Testing with mock data
```dart
test('should calculate total income', () {
  final transactions = [/* mock data */];
  provider.transactions.addAll(transactions);
  expect(provider.totalIncome, expectedValue);
});
```

## Adding New Tests

When adding new tests:

1. Place the test file in the appropriate directory (models/, services/, screens/, utils/)
2. Name the file with `_test.dart` suffix
3. Group related tests using `group()`
4. Write descriptive test names
5. Cover positive cases, negative cases, and edge cases
6. Update this README if adding a new test category

## Continuous Integration

These tests are designed to run in CI/CD pipelines. Ensure all tests pass before merging:

```bash
flutter test --reporter json > test-results.json
```

## Troubleshooting

### Tests fail to run
- Ensure Flutter SDK is installed: `flutter doctor`
- Update dependencies: `flutter pub get`
- Clear build cache: `flutter clean`

### Import errors
- Check that all dependencies are in pubspec.yaml
- Run `flutter pub get`
- Verify import paths are correct

### Mock/Stub issues
- Ensure Firebase is properly initialized in tests
- Use `setUp()` and `tearDown()` for test fixtures
- Consider using mockito for complex mocking

## Best Practices

1. **Keep tests fast** - Unit tests should run in milliseconds
2. **Test one thing** - Each test should verify one behavior
3. **Use meaningful assertions** - Prefer specific matchers over generic ones
4. **Avoid test interdependence** - Tests should not rely on execution order
5. **Clean up resources** - Use tearDown() to dispose of controllers, providers, etc.

## Future Enhancements

Potential areas for additional testing:

1. Integration tests for complete user flows
2. Golden tests for UI consistency
3. Performance tests for large datasets
4. Accessibility tests
5. Localization tests

## Contributing

When contributing tests:

1. Follow existing test structure and naming conventions
2. Ensure new tests pass locally before committing
3. Update TEST_SUMMARY.md with new test counts
4. Add comments for complex test scenarios
5. Keep test code clean and maintainable

## Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Flutter Test Package](https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html)

---

For a detailed breakdown of test coverage, see [TEST_SUMMARY.md](../TEST_SUMMARY.md) in the project root.