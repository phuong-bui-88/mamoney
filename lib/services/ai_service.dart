import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mamoney/services/ai_config.dart';
import 'package:logging/logging.dart';

final _logger = Logger('AIService');

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
                'Input format is typically: "[description] [amount]" (e.g., "sửa xe 15k" means description="sửa xe", amount="15000"). '
                'Extract the description (keep it EXACTLY as the user provided but WITHOUT the amount), the amount (number only), the category, and the type. '
                'Categories for expenses: 🏠 Housing (rent, mortgage, maintenance), 🍚 Food (meals, groceries), 🚗 Transportation (fuel, transport), 💡 Utilities (electricity, water, internet, phone), 🏥 Healthcare (medicine, doctor, insurance). '
                'Categories for income: Salary, Freelance, Investment, Gift, Other. '
                'Type is either "expense" or "income". Most transactions are expenses unless explicitly mentioned as earning/getting money (income keywords: salary, earned, received, gift, investment, freelance, bonus, refund). '
                'Convert Vietnamese number notation: k = thousands (50k = 50000), m = millions (1m = 1000000), tr = millions (2tr = 2000000). '
                'Return response in format: DESCRIPTION: [description] | AMOUNT: [amount] | CATEGORY: [category] | TYPE: [expense/income]'
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
          .timeout(const Duration(seconds: 30));

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
        'Return response in format: DESCRIPTION: [description] | AMOUNT: [amount] | CATEGORY: [category] | TYPE: [expense/income]';
  }

  /// Extract description, amount, category, and type from AI response
  static Map<String, String> _extractDescriptionAndAmount(String response) {
    final result = <String, String>{};

    // Look for pattern: DESCRIPTION: ... | AMOUNT: ... | CATEGORY: ... | TYPE: ...
    final descRegex = RegExp(r'DESCRIPTION:\s*([^|]+)', caseSensitive: false);
    final amountRegex =
        RegExp(r'AMOUNT:\s*(\d+(?:\.\d+)?)', caseSensitive: false);
    final categoryRegex = RegExp(r'CATEGORY:\s*([^|]+)', caseSensitive: false);
    final typeRegex = RegExp(r'TYPE:\s*(expense|income)', caseSensitive: false);

    final descMatch = descRegex.firstMatch(response);
    final amountMatch = amountRegex.firstMatch(response);
    final categoryMatch = categoryRegex.firstMatch(response);
    final typeMatch = typeRegex.firstMatch(response);

    if (descMatch != null) {
      result['description'] = descMatch.group(1)?.trim() ?? '';
    }

    if (amountMatch != null) {
      result['amount'] = amountMatch.group(1)?.trim() ?? '';
    }

    if (categoryMatch != null) {
      result['category'] = categoryMatch.group(1)?.trim() ?? '';
    }

    if (typeMatch != null) {
      result['type'] = typeMatch.group(1)?.trim() ?? '';
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
      } else if (line.toLowerCase().contains('category')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          result['category'] = parts.sublist(1).join(':').trim();
        }
      } else if (line.toLowerCase().contains('type')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          final typeStr = parts.sublist(1).join(':').trim().toLowerCase();
          if (typeStr.contains('expense') || typeStr.contains('income')) {
            result['type'] = typeStr.contains('income') ? 'income' : 'expense';
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

  /// Parse invoice image to extract transaction details
  /// Accepts either imageBytes directly (for web) or imagePath (for mobile)
  /// Returns a LIST of items extracted from the invoice
  /// Each item is a map with: {description, amount, category, type}
  /// Returns error in first item: {error: message}
  static Future<List<Map<String, String>>> parseInvoiceImage(
    String? imagePath, {
    Uint8List? imageBytes,
    String? mediaType,
  }) async {
    _logger.info('Starting invoice parsing: ${imagePath ?? "from bytes"}');

    // Validate that GitHub token is configured
    if (AIConfig.githubToken.isEmpty) {
      _logger.warning('GitHub token not configured');
      return [
        {
          'error':
              'GitHub token not configured. Please set GITHUB_TOKEN environment variable.'
        }
      ];
    }

    // Read image bytes
    late Uint8List imageData;
    late String detectedMediaType;

    try {
      if (imageBytes != null) {
        // Web: bytes passed directly
        _logger.info('Using provided image bytes');
        if (imageBytes.isEmpty) {
          _logger.warning('Image bytes are empty');
          return [
            {'error': 'Image data is empty'}
          ];
        }
        imageData = imageBytes;
        detectedMediaType = mediaType ?? 'image/jpeg';
        _logger.info(
            'Image bytes: ${imageData.length} bytes, type: $detectedMediaType');
      } else if (imagePath != null && !kIsWeb) {
        // Mobile: read from file path
        _logger.info('Reading image file from path: $imagePath');
        final imageFile = File(imagePath);

        if (!imageFile.existsSync()) {
          _logger.warning('Image file not found: $imagePath');
          return [
            {'error': 'Image file not found: $imagePath'}
          ];
        }

        _logger.info('Reading image file: ${imageFile.lengthSync()} bytes');
        imageData = imageFile.readAsBytesSync();

        if (imageData.isEmpty) {
          _logger.warning('Image file is empty: $imagePath');
          return [
            {'error': 'Image file is empty: $imagePath'}
          ];
        }

        // Determine image media type from file extension
        final extension = imagePath.split('.').last.toLowerCase();
        detectedMediaType = _getMediaType(extension);
      } else {
        _logger.warning(
            'No image data provided (imagePath=$imagePath, imageBytes length=${imageBytes?.length})');
        return [
          {
            'error':
                'No image data provided. Please provide either imagePath or imageBytes.'
          }
        ];
      }
    } catch (e, stackTrace) {
      _logger.severe('Error reading image: $e', e, stackTrace);
      return [
        {'error': 'Failed to read image: $e'}
      ];
    }

    final base64Image = base64.encode(imageData);
    _logger.info('Image encoded to base64: ${base64Image.length} characters');

    // Call GitHub Models API with base64-encoded image
    _logger.info('Calling GitHub Models API...');
    final response = await _callGitHubModelsWithImage(
      base64Image,
      detectedMediaType,
    );

    if (response['success']) {
      _logger.info('Successfully parsed invoice');
      final items = _extractInvoiceLineItems(response['message']);
      _logger.info('Extracted ${items.length} items from invoice');
      return items;
    } else {
      _logger.warning('API call failed: ${response['error']}');
      return [
        {'error': response['error']}
      ];
    }
    // } catch (e, stackTrace) {
    //   _logger.severe('Exception during invoice parsing: $e', e, stackTrace);
    //   return {'error': 'Failed to parse invoice image: $e'};
    // }
  }

  /// Get media type from file extension
  static String _getMediaType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Extract all line items from invoice response
  /// Parses response lines with format: ITEM: [name] | AMOUNT: [amount] | CATEGORY: [category]
  /// Returns list of transaction maps
  static List<Map<String, String>> _extractInvoiceLineItems(String response) {
    final List<Map<String, String>> items = [];
    final lines = response.split('\n');

    _logger.info('Started parsing invoice response with ${lines.length} lines');
    _logger.info('Raw API response:\n$response');

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      _logger.info('Processing line: "$line"');
      final item = _parseInvoiceItemLine(line);
      if (item.isNotEmpty) {
        items.add(item);
        _logger
            .info('✅ Parsed item: ${item['description']} - ${item['amount']}');
      }
    }

    // If no items found, return empty list so caller knows parsing failed
    if (items.isEmpty) {
      _logger.warning(
          'No items extracted from invoice response. Raw response:\n$response');
    } else {
      _logger.info('Successfully extracted ${items.length} items from invoice');
    }

    return items;
  }

  /// Parse a single invoice line with format: ITEM: [name] | AMOUNT: [amount] | CATEGORY: [category]
  /// Returns map with keys: description, amount, category, type
  static Map<String, String> _parseInvoiceItemLine(String line) {
    final result = <String, String>{};

    // Skip lines that don't look like item lines
    if (!line.contains('ITEM:') && !line.contains('Item:')) {
      return result;
    }

    // Extract ITEM
    final itemRegex = RegExp(r'ITEM:\s*([^|]+)', caseSensitive: false);
    final itemMatch = itemRegex.firstMatch(line);
    if (itemMatch != null) {
      result['description'] = itemMatch.group(1)?.trim() ?? '';
    }

    // Extract AMOUNT - more robust regex that excludes trailing punctuation
    final amountRegex = RegExp(
        r'AMOUNT:\s*([\d,\.]+(?:\s*[\d,\.]+)*)\s*(?:\||$)',
        caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(line);
    if (amountMatch != null) {
      final amountStr = amountMatch.group(1)?.trim() ?? '';
      _logger.info('Raw amount extracted: "$amountStr" from line: "$line"');
      final cleanedAmount = _cleanupAmount(amountStr);
      _logger.info('Cleaned amount: "$cleanedAmount"');
      if (cleanedAmount.isNotEmpty) {
        result['amount'] = cleanedAmount;
      }
    }

    // Extract CATEGORY
    final categoryRegex =
        RegExp(r'CATEGORY:\s*([^|\n]+)', caseSensitive: false);
    final categoryMatch = categoryRegex.firstMatch(line);
    if (categoryMatch != null) {
      result['category'] = categoryMatch.group(1)?.trim() ?? 'Other';
    } else {
      result['category'] = 'Other';
    }

    // Type is always expense for invoice items
    result['type'] = 'expense';

    return result;
  }

  /// Clean up amount string handling various number formats
  /// "67,500" → "67500"
  /// "67.500" → "67500"
  /// "67,500.00" → "67500"
  /// "67.500,00" → "67500"
  static String _cleanupAmount(String amountStr) {
    if (amountStr.isEmpty) return '';

    // Remove whitespace
    var cleaned = amountStr.replaceAll(RegExp(r'\s+'), '');

    // If it has both comma and dot, determine which is decimal separator
    if (cleaned.contains(',') && cleaned.contains('.')) {
      // Vietnamese format: 67.500,00 (dot is thousands, comma is decimal)
      if (cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')) {
        // Comma comes after dot → Vietnamese format
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Dot comes after comma → US/EU format
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      // Only comma: could be decimal or thousands separator
      // If there are exactly 2 or 3 digits before comma, it's decimal (price like 500,00)
      final parts = cleaned.split(',');
      if (parts.first.length <= 3 &&
          parts.length == 2 &&
          parts.last.length == 2) {
        // Likely decimal: 500,00 or 5,00
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // Likely thousands separator (Vietnamese): keep only digits before comma
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains('.')) {
      // Only dot: could be decimal or thousands separator
      // If there are exactly 2 or 3 digits after dot, it's decimal
      final parts = cleaned.split('.');
      if (parts.last.length == 2 && !cleaned.contains('000')) {
        // Likely decimal: 500.00
        // Keep as is
      } else {
        // Likely thousands separator: remove it
        cleaned = cleaned.replaceAll('.', '');
      }
    }

    // Extract integer part (before any remaining decimal point)
    final parts = cleaned.split('.');
    return parts.first;
  }

  /// Call GitHub Models API with base64-encoded image
  static Future<Map<String, dynamic>> _callGitHubModelsWithImage(
    String base64Image,
    String mediaType,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AIConfig.githubToken}',
      };

      const invoicePrompt =
          'Extract ALL line items from this Vietnamese invoice image exactly as shown.\n'
          'CRITICAL INSTRUCTIONS FOR ACCURACY:\n'
          '1. Item Name: Read from the LEFTMOST product description column\n'
          '2. Amount: Read from the RIGHTMOST column which shows final price (usually "Thành Tiền Sau Thuế" or "Total After Tax")\n'
          '3. IMPORTANT: Do NOT use Unit Price or Subtotal columns - only use the FINAL TOTAL column on the right\n'
          '4. Vietnamese number format: If you see "51.500,00" that equals 51500 VND. Return it as: 51500\n'
          '5. For each row, return: ITEM: [product name] | AMOUNT: [final amount as digits only, no dots or commas] | CATEGORY: [Food/Shopping/etc]\n'
          'Return exactly one line per invoice item. Do NOT include totals, subtotals, or grand totals.\n'
          'Example: ITEM: Cream đặc có đường | AMOUNT: 67500 | CATEGORY: Food';

      final body = jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content': 'You are a financial assistant that extracts ALL line items from invoice/receipt images. '
                'For invoices with multiple items, extract EACH ITEM SEPARATELY on its own line. '
                'Each line must have the format: ITEM: [description] | AMOUNT: [amount] | CATEGORY: [category]\n'
                'Categories: 🏠 Housing, 🍚 Food, 🚗 Transportation, 💡 Utilities, 🏥 Healthcare, 🎭 Entertainment, 🛍️ Shopping, Other. '
                'CRITICAL RULES: 1) Extract one line per item (not totals), 2) Use FINAL PRICE column only (rightmost amount), 3) Return only numbers for amounts (no commas/dots/symbols), 4) Convert Vietnamese format: 67.500,00 → 67500'
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': invoicePrompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mediaType;base64,$base64Image',
                }
              }
            ],
          }
        ],
        'temperature': 0.5,
        'max_tokens': 500,
        'model': AIConfig.model,
      });

      _logger.info('Sending request to ${AIConfig.getApiUrl()}');
      _logger.fine('Request body size: ${body.length} bytes');

      final response = await http
          .post(
            Uri.parse(AIConfig.getApiUrl()),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 60));

      _logger.info('Received response with status: ${response.statusCode}');
      _logger.fine('Response headers: ${response.headers}');
      _logger.fine('Response body length: ${response.body.length} characters');

      if (response.statusCode == 200) {
        try {
          // Validate content type before parsing
          final contentType = response.headers['content-type'] ?? '';
          if (!contentType.contains('application/json')) {
            _logger.warning('Unexpected content type: $contentType');
          }

          // Validate response body is not empty
          if (response.body.isEmpty) {
            _logger.warning('Empty response body');
            return {
              'success': false,
              'error': 'API returned empty response body'
            };
          }

          // Validate response starts with JSON character
          if (!response.body.trim().startsWith('{') &&
              !response.body.trim().startsWith('[')) {
            _logger.warning(
                'Response body does not look like JSON: ${response.body.substring(0, 100)}');
            return {
              'success': false,
              'error':
                  'API returned non-JSON response. This may indicate an API outage or configuration error.'
            };
          }

          final data = jsonDecode(response.body);
          _logger.fine('Successfully decoded JSON response');

          // Validate response structure
          if (data is! Map || data['choices'] == null) {
            _logger.warning('Invalid response structure: Missing choices');
            return {
              'success': false,
              'error':
                  'Invalid API response format: Missing choices in response'
            };
          }

          final choices = data['choices'];
          if (choices is! List || choices.isEmpty) {
            _logger.warning('Invalid response structure: Empty choices array');
            return {
              'success': false,
              'error': 'Invalid API response format: Empty choices array'
            };
          }

          final message = choices[0]['message']['content']?.toString().trim();

          if (message == null || message.isEmpty) {
            _logger.warning('API returned empty message');
            return {'success': false, 'error': 'API returned empty content'};
          }

          _logger.info('Extracted message from API response');
          _logger.info('Raw AI response:\n$message');
          _logger.info('Message length: ${message.length} characters');

          // Count ITEM: occurrences to see how many items AI extracted
          final itemCount = RegExp('ITEM:').allMatches(message).length;
          _logger.info('AI extracted $itemCount items from invoice');

          return {'success': true, 'message': message};
        } catch (parseError, stackTrace) {
          _logger.severe('Failed to parse JSON response: $parseError',
              parseError, stackTrace);
          final responsePreview = response.body.length > 500
              ? response.body.substring(0, 500)
              : response.body;
          return {
            'success': false,
            'error':
                'Failed to parse API response: $parseError\n\nDebug info:\nStatus: ${response.statusCode}\nResponse: $responsePreview'
          };
        }
      } else if (response.statusCode == 401) {
        _logger.warning('Authentication failed: Invalid or expired token');
        return {
          'success': false,
          'error':
              'Authentication Error: Invalid or expired GitHub token. Please rebuild with a valid GITHUB_TOKEN via --dart-define.'
        };
      } else if (response.statusCode == 429) {
        _logger.warning('Rate limited: Too many requests');
        return {
          'success': false,
          'error': 'API Rate Limited: Please wait a moment and try again.'
        };
      } else {
        _logger.warning('API returned error status ${response.statusCode}');
        final responsePreview = response.body.length > 500
            ? response.body.substring(0, 500)
            : response.body;
        return {
          'success': false,
          'error':
              'API Error: ${response.statusCode}\nResponse: $responsePreview'
        };
      }
    } catch (e, stackTrace) {
      _logger.severe('Exception in API call: $e', e, stackTrace);
      // Provide more helpful error messages for timeout
      if (e is TimeoutException) {
        return {
          'success': false,
          'error': 'AI service timeout: Image processing took too long. Please try with a clearer or smaller invoice image.'
        };
      }
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Provides AI with transaction context and financial knowledge base
  /// Returns the AI's response as a string
  /// For budget summaries, formats response as: "Based on your X monthly budget items: 1. Item (emoji): amount VND ... Total: amount VND"
  static Future<String> askFinancialQuestion(
    String question,
    String transactionContext,
    String financialContext,
  ) async {
    try {
      // Validate that GitHub token is configured
      if (AIConfig.githubToken.isEmpty) {
        return 'Error: GitHub token not configured. Please set GITHUB_TOKEN environment variable.';
      }

      final systemPrompt = '''You are a helpful financial advisor AI assistant. 
You have access to the user's transaction history and financial knowledge base.

## User's Transaction Context:
$transactionContext

## Financial Knowledge Base:
$financialContext

FOR BUDGET SUMMARIES: Format responses as:
"Based on your X monthly budget items:
1. Category (emoji): amount VND (dd-mm-yyyy)
2. Category (emoji): amount VND (dd-mm-yyyy)
3. Category (emoji): amount VND (dd-mm-yyyy)
======================================
Total: total_amount VND"

Use appropriate emojis: 🏠 Housing, 🍔 Food, 🚗 Transportation, 💡 Utilities, 🏥 Healthcare''';

      final response = await _callGitHubModelsChat(systemPrompt, question);

      if (response['success']) {
        return response['message'];
      } else {
        return 'Error: ${response['error']}';
      }
    } catch (e) {
      return 'Error asking financial question: $e';
    }
  }

  /// Call GitHub Models API for general chat (not transaction parsing)
  static Future<Map<String, dynamic>> _callGitHubModelsChat(
    String systemPrompt,
    String userMessage,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AIConfig.githubToken}',
      };

      final body = jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': userMessage,
          }
        ],
        'temperature': 0.7,
        'max_tokens': 500,
        'model': AIConfig.model,
      });

      final response = await http
          .post(
            Uri.parse(AIConfig.getApiUrl()),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message =
            data['choices'][0]['message']['content'].toString().trim();
        return {'success': true, 'message': message};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error':
              'Authentication Error: Invalid or expired GitHub token. Please rebuild with a valid GITHUB_TOKEN via --dart-define.',
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
}
