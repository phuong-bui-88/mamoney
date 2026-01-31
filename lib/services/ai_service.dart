import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mamoney/services/ai_config.dart';

class AIService {
  /// Parse AI message to extract description and amount
  /// Example: "Bought lunch for 50 dollars" -> {description: "Bought lunch", amount: "50"}
  static Future<Map<String, String>> parseTransactionMessage(
      String message) async {
    try {
      // Validate that GitHub token is configured
      if (AIConfig.githubToken.isEmpty) {
        return {
          'error':
              'GitHub token not configured. Please set GITHUB_TOKEN environment variable.\n'
                  'See FIX_GITHUB_TOKEN_ERROR.md for setup instructions.'
        };
      }

      final response = await _callGitHubModels(
        _buildPrompt(message),
      );

      if (response['success']) {
        final parsed = _extractDescriptionAndAmount(response['message']);
        return parsed;
      } else {
        return {'error': response['error']};
      }
    } catch (e) {
      return {'error': 'Failed to parse message: $e'};
    }
  }

  /// Call GitHub Models API (powered by Azure OpenAI)
  static Future<Map<String, dynamic>> _callGitHubModels(String prompt) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AIConfig.githubToken}',
      };

      final body = jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content': 'You are a financial assistant that extracts transaction details from user messages. '
                'Extract the description (what was bought/earned) and the amount (number only). '
                'Convert Vietnamese number notation: k = thousands (50k = 50000), m = millions (1m = 1000000). '
                'Return response in format: DESCRIPTION: [description] | AMOUNT: [amount]'
          },
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.7,
        'max_tokens': 100,
        'model': AIConfig.model,
      });

      final response = await http
          .post(
            Uri.parse(AIConfig.getApiUrl()),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message =
            data['choices'][0]['message']['content'].toString().trim();
        return {'success': true, 'message': message};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error':
              'Authentication Error: Invalid or expired GitHub token. Please rebuild with a valid GITHUB_TOKEN via --dart-define. Ensure read:model-garden scope is enabled.'
        };
      } else {
        return {
          'success': false,
          'error': 'API Error: ${response.statusCode} - ${response.body}'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Build prompt for AI
  static String _buildPrompt(String message) {
    return 'Extract transaction details from this message: "$message". '
        'Provide description and amount only.';
  }

  /// Extract description and amount from AI response
  static Map<String, String> _extractDescriptionAndAmount(String response) {
    final result = <String, String>{};

    // Look for pattern: DESCRIPTION: ... | AMOUNT: ...
    final descRegex = RegExp(r'DESCRIPTION:\s*([^|]+)', caseSensitive: false);
    final amountRegex =
        RegExp(r'AMOUNT:\s*(\d+(?:\.\d+)?)', caseSensitive: false);

    final descMatch = descRegex.firstMatch(response);
    final amountMatch = amountRegex.firstMatch(response);

    if (descMatch != null) {
      result['description'] = descMatch.group(1)?.trim() ?? '';
    }

    if (amountMatch != null) {
      result['amount'] = amountMatch.group(1)?.trim() ?? '';
    }

    // If patterns not found, try alternative parsing
    if (result.isEmpty) {
      _parseAlternativeFormat(response, result);
    }

    return result;
  }

  /// Alternative parsing method if standard format not found
  static void _parseAlternativeFormat(
      String response, Map<String, String> result) {
    final lines = response.split('\n');
    for (var line in lines) {
      if (line.toLowerCase().contains('description')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          result['description'] = parts.sublist(1).join(':').trim();
        }
      } else if (line.toLowerCase().contains('amount')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          final amountStr = parts.sublist(1).join(':').trim();
          final amount = _extractNumber(amountStr);
          if (amount.isNotEmpty) {
            result['amount'] = amount;
          }
        }
      }
    }
  }

  /// Extract number from string
  static String _extractNumber(String str) {
    final regex = RegExp(r'\d+(?:\.\d+)?');
    final match = regex.firstMatch(str);
    return match?.group(0) ?? '';
  }
}
