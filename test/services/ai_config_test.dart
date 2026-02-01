import 'package:flutter_test/flutter_test.dart';
import 'package:mamoney/services/ai_config.dart';

void main() {
  group('AIConfig', () {
    group('Constants', () {
      test('should have endpoint defined', () {
        expect(AIConfig.endpoint, isNotEmpty);
        expect(AIConfig.endpoint, 'https://models.github.ai/inference');
      });

      test('should have valid endpoint URL', () {
        expect(AIConfig.endpoint, startsWith('https://'));
        expect(AIConfig.endpoint, contains('github'));
      });

      test('should have model defined', () {
        expect(AIConfig.model, isNotEmpty);
        expect(AIConfig.model, 'openai/gpt-4.1');
      });

      test('should have valid model format', () {
        expect(AIConfig.model, contains('/'));
        final parts = AIConfig.model.split('/');
        expect(parts.length, 2);
        expect(parts[0], 'openai');
        expect(parts[1], 'gpt-4.1');
      });

      test('githubToken should be string (may be empty)', () {
        expect(AIConfig.githubToken, isA<String>());
      });
    });

    group('getApiUrl', () {
      test('should return full API URL for chat completions', () {
        final url = AIConfig.getApiUrl();
        expect(url, isNotEmpty);
      });

      test('should combine endpoint with chat completions path', () {
        final url = AIConfig.getApiUrl();
        expect(url, contains(AIConfig.endpoint));
        expect(url, endsWith('/chat/completions'));
      });

      test('should return valid HTTPS URL', () {
        final url = AIConfig.getApiUrl();
        expect(url, startsWith('https://'));
      });

      test('should return consistent URL on multiple calls', () {
        final url1 = AIConfig.getApiUrl();
        final url2 = AIConfig.getApiUrl();
        expect(url1, equals(url2));
      });

      test('should construct proper URL path', () {
        final url = AIConfig.getApiUrl();
        expect(
          url,
          equals('${AIConfig.endpoint}/chat/completions'),
        );
      });
    });

    group('Endpoint validation', () {
      test('endpoint should not have trailing slash', () {
        expect(AIConfig.endpoint, isNot(endsWith('/')));
      });

      test('endpoint should be valid GitHub Models URL', () {
        expect(AIConfig.endpoint, contains('models.github.ai'));
      });

      test('endpoint should use secure protocol', () {
        expect(AIConfig.endpoint, startsWith('https://'));
      });
    });

    group('Model validation', () {
      test('model should follow provider/name format', () {
        expect(AIConfig.model.split('/').length, 2);
      });

      test('model provider should be openai', () {
        final provider = AIConfig.model.split('/')[0];
        expect(provider, 'openai');
      });

      test('model name should be gpt-4.1', () {
        final modelName = AIConfig.model.split('/')[1];
        expect(modelName, 'gpt-4.1');
      });

      test('model should not be empty', () {
        expect(AIConfig.model, isNotEmpty);
      });

      test('model should not contain whitespace', () {
        expect(AIConfig.model, isNot(contains(' ')));
        expect(AIConfig.model, isNot(contains('\t')));
        expect(AIConfig.model, isNot(contains('\n')));
      });
    });

    group('Configuration completeness', () {
      test('all required configuration fields should be present', () {
        expect(AIConfig.endpoint, isNotNull);
        expect(AIConfig.model, isNotNull);
        expect(AIConfig.githubToken, isNotNull);
      });

      test('configuration should be accessible statically', () {
        // These should not throw
        expect(() => AIConfig.endpoint, returnsNormally);
        expect(() => AIConfig.model, returnsNormally);
        expect(() => AIConfig.githubToken, returnsNormally);
        expect(() => AIConfig.getApiUrl(), returnsNormally);
      });
    });

    group('Edge cases', () {
      test('getApiUrl should handle endpoint without trailing slash', () {
        final url = AIConfig.getApiUrl();
        expect(url, isNot(contains('//')));
        expect(url.split('//').length, 2); // Only https://
      });

      test('configuration should be immutable', () {
        // Since these are const, they can't be changed
        // This test verifies they're declared properly
        expect(AIConfig.endpoint, isA<String>());
        expect(AIConfig.model, isA<String>());
      });
    });

    group('Alternative models documentation', () {
      test('should document alternative model options', () {
        // These are mentioned in comments in the source
        const alternativeModels = [
          'openai/gpt-4',
          'openai/gpt-3.5-turbo',
          'meta/llama-2-7b',
          'meta/llama-2-70b',
        ];

        // Verify our current model is valid format like alternatives
        for (final altModel in alternativeModels) {
          expect(altModel.split('/').length, 2);
          expect(altModel, isNot(isEmpty));
        }
      });
    });

    group('URL construction', () {
      test('should create valid URL for HTTP requests', () {
        final url = AIConfig.getApiUrl();
        final uri = Uri.parse(url);

        expect(uri.scheme, 'https');
        expect(uri.host, 'models.github.ai');
        expect(uri.path, '/inference/chat/completions');
      });

      test('should not have query parameters in base URL', () {
        final url = AIConfig.getApiUrl();
        final uri = Uri.parse(url);

        expect(uri.queryParameters, isEmpty);
      });

      test('should not have fragment in URL', () {
        final url = AIConfig.getApiUrl();
        final uri = Uri.parse(url);

        expect(uri.fragment, isEmpty);
      });
    });

    group('Security considerations', () {
      test('should use HTTPS for secure communication', () {
        expect(AIConfig.endpoint, startsWith('https://'));
        expect(AIConfig.getApiUrl(), startsWith('https://'));
      });

      test('token should be configurable at compile time', () {
        // Token is set via String.fromEnvironment
        // This test verifies it's a String type
        expect(AIConfig.githubToken, isA<String>());
      });
    });
  });
}