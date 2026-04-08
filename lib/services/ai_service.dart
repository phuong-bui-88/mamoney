import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mamoney/services/ai_config.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger('AIService');

class AIService {
  /// Parse AI message to extract description and amount
  /// Example: "Bought lunch for 50 dollars" -> {description: "Bought lunch", amount: "50", ragId: "chatcmpl-..."}
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
        // Include ragId from API response
        if (response['ragId'] != null) {
          parsed['ragId'] = response['ragId'].toString();
        }
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
        final ragId = data['id']?.toString() ?? '';
        return {'success': true, 'message': message, 'ragId': ragId};
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

  /// Parse invoice image to extract transaction details and generate invoiceId
  /// Accepts either imageBytes directly (for web) or imagePath (for mobile)
  /// Returns a map with:
  ///   - 'items': List of extracted items, each with {description, amount, category, type}
  ///   - 'invoiceId': Unique ID for grouping transactions from same invoice
  ///   - 'invoiceDate': Timestamp when invoice was imported (now)
  /// If error, returns {'items': [{error: message}], 'invoiceId': null}
  static Future<Map<String, dynamic>> parseInvoiceImage(
    String? imagePath, {
    Uint8List? imageBytes,
    String? mediaType,
  }) async {
    _logger.info('Starting invoice parsing: ${imagePath ?? "from bytes"}');

    // Generate unique invoiceId and timestamp for this invoice import
    final invoiceId = const Uuid().v4();
    final invoiceDate = DateTime.now();
    _logger.info('Generated invoiceId: $invoiceId');

    // Validate that GitHub token is configured
    if (AIConfig.githubToken.isEmpty) {
      _logger.warning('GitHub token not configured');
      return {
        'items': [
          {
            'error':
                'GitHub token not configured. Please set GITHUB_TOKEN environment variable.'
          }
        ],
        'invoiceId': null,
        'invoiceDate': null,
      };
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
          return {
            'items': [
              {'error': 'Image data is empty'}
            ],
            'invoiceId': invoiceId,
            'invoiceDate': invoiceDate,
          };
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
          return {
            'items': [
              {'error': 'Image file not found: $imagePath'}
            ],
            'invoiceId': invoiceId,
            'invoiceDate': invoiceDate,
          };
        }

        _logger.info('Reading image file: ${imageFile.lengthSync()} bytes');
        imageData = imageFile.readAsBytesSync();

        if (imageData.isEmpty) {
          _logger.warning('Image file is empty: $imagePath');
          return {
            'items': [
              {'error': 'Image file is empty: $imagePath'}
            ],
            'invoiceId': invoiceId,
            'invoiceDate': invoiceDate,
          };
        }

        // Determine image media type from file extension
        final extension = imagePath.split('.').last.toLowerCase();
        detectedMediaType = _getMediaType(extension);
      } else {
        _logger.warning(
            'No image data provided (imagePath=$imagePath, imageBytes length=${imageBytes?.length})');
        return {
          'items': [
            {
              'error':
                  'No image data provided. Please provide either imagePath or imageBytes.'
            }
          ],
          'invoiceId': invoiceId,
          'invoiceDate': invoiceDate,
        };
      }
    } catch (e, stackTrace) {
      _logger.severe('Error reading image: $e', e, stackTrace);
      return {
        'items': [
          {'error': 'Failed to read image: $e'}
        ],
        'invoiceId': invoiceId,
        'invoiceDate': invoiceDate,
      };
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
      return {
        'items': items,
        'invoiceId': invoiceId,
        'invoiceDate': invoiceDate,
      };
    } else {
      _logger.warning('API call failed: ${response['error']}');
      return {
        'items': [
          {'error': response['error']}
        ],
        'invoiceId': invoiceId,
        'invoiceDate': invoiceDate,
      };
    }
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

    // Extract AMOUNT - greedy regex to capture the complete amount number
    // Matches all consecutive digits, commas, and dots as one unit
    final amountRegex =
        RegExp(r'AMOUNT:\s*([\d,\.]+)\s*(?:\||$)', caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(line);
    if (amountMatch != null) {
      final amountStr = amountMatch.group(1)?.trim() ?? '';
      _logger.info('Raw amount extracted: "$amountStr" from line: "$line"');
      final cleanedAmount = _cleanupAmount(amountStr);
      _logger.info('Cleaned amount: "$cleanedAmount"');

      // Validate amount: should be at least 4 digits for Vietnamese prices
      // (Vietnamese invoices typically show prices like 1000, 50000, etc.)
      if (cleanedAmount.isNotEmpty) {
        final amountNum = int.tryParse(cleanedAmount) ?? 0;
        if (amountNum >= 1000) {
          // Valid Vietnamese amount (at least 1000 VND)
          result['amount'] = cleanedAmount;
        } else if (cleanedAmount.length >= 5) {
          // Fallback: if string is long enough, likely valid
          result['amount'] = cleanedAmount;
        } else {
          _logger
              .warning('Rejected amount $cleanedAmount: too small or invalid');
        }
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
  /// "49800" → "49800"
  static String _cleanupAmount(String amountStr) {
    if (amountStr.isEmpty) return '';

    _logger.fine('_cleanupAmount input: "$amountStr"');

    // Remove whitespace
    var cleaned = amountStr.replaceAll(RegExp(r'\s+'), '');

    // If it has both comma and dot, determine which is decimal separator
    if (cleaned.contains(',') && cleaned.contains('.')) {
      // Vietnamese format: 67.500,00 (dot is thousands, comma is decimal)
      if (cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')) {
        // Comma comes after dot → Vietnamese format
        _logger
            .fine('Detected Vietnamese format (dot=thousands, comma=decimal)');
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Dot comes after comma → US format
        _logger.fine('Detected US format (comma=thousands, dot=decimal)');
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      // Only comma: could be decimal or thousands separator
      final parts = cleaned.split(',');
      final beforeComma = parts.first.length;
      final afterComma = parts.length > 1 ? parts.last.length : 0;

      if (beforeComma <= 3 && afterComma == 2) {
        // Likely European decimal format: 500,00 or 5,00
        _logger.fine('Detected European decimal format (comma=decimal)');
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // Likely thousands separator (Vietnamese): remove comma
        _logger.fine('Detected Vietnamese thousands separator (comma)');
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains('.')) {
      // Only dot: could be decimal or thousands separator
      final parts = cleaned.split('.');
      final afterDot = parts.last.length;

      if (afterDot == 3) {
        // Likely thousands separator (49.800 → 49800): remove it
        _logger.fine('Detected thousands separator (3 digits after dot)');
        cleaned = cleaned.replaceAll('.', '');
      } else if (afterDot == 2) {
        // Could be decimal or thousands
        // If the part before dot is > 3 digits, it's decimal (12345.00)
        // Otherwise, likely thousands (500.00 format is rare in invoices)
        if (parts.first.length > 3) {
          _logger.fine(
              'Detected decimal format (dot=decimal, ${parts.first.length} digits before dot)');
          // Keep the dot
        } else {
          _logger.fine('Ambiguous: treating as thousands separator');
          cleaned = cleaned.replaceAll('.', '');
        }
      } else {
        // 1 digit or 4+ digits - remove the dot
        _logger
            .fine('Detected thousands separator ($afterDot digits after dot)');
        cleaned = cleaned.replaceAll('.', '');
      }
    }

    _logger.fine('_cleanupAmount after format detection: "$cleaned"');

    // Extract integer part (before any remaining decimal point)
    final parts = cleaned.split('.');
    final result = parts.first;
    _logger.fine('_cleanupAmount final result: "$result"');
    return result;
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
          '\n'
          'CRITICAL - READ THIS CAREFULLY:\n'
          '**For each item, return EXACTLY ONE AMOUNT - the rightmost/final amount only**\n'
          '\n'
          'STEP-BY-STEP INSTRUCTIONS:\n'
          '1. Item Name: Read from the LEFTMOST product description column\n'
          '\n'
          '2. Amount (MOST IMPORTANT - READ CAREFULLY):\n'
          '   - Find the ROW for that item\n'
          '   - Look at the RIGHTMOST COLUMN in that row (usually "Thành Tiền Sau Thuế")\n'
          '   - That rightmost number is THE ONLY amount you should use\n'
          '   - ABSOLUTELY DO NOT read from "Đơn Giá" (unit price) or middle columns\n'
          '   - ABSOLUTELY DO NOT concatenate or combine multiple numbers from the same row\n'
          '   - Extract just ONE final amount per item\n'
          '\n'
          '3. Vietnamese number format:\n'
          '   - Format: "[thousands].[thousands],[decimal]" → e.g., "49.800,00"\n'
          '   - Convert to integer: Remove dots and commas, keep only digits → "49800"\n'
          '   - Examples:\n'
          '     * "51.500,00" → 51500\n'
          '     * "49.800,00" → 49800\n'
          '     * "67.500" → 67500\n'
          '\n'
          '4. Output format (ONE line per item):\n'
          '   ITEM: [product name] | AMOUNT: [single final amount as digits only] | CATEGORY: [category]\n'
          '\n'
          'VALIDATION RULES:\n'
          '   - Amount must be a reasonable price (typically 1000+ in VND)\n'
          '   - DO NOT output multiple amounts per item\n'
          '   - DO NOT include totals or subtotals\n'
          '   - DO NOT include tax rows\n'
          '\n'
          'EXAMPLES (notice ONE amount per item):\n'
          'ITEM: Mì Hảo Hảo Big tôm chua cay 100g Gói | AMOUNT: 51500 | CATEGORY: Food\n'
          'ITEM: Sữa chua uống men sống Probi dâu lốc 5 x 65 ml | AMOUNT: 49800 | CATEGORY: Food';

      final body = jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content': 'You are a strict financial invoice extraction assistant specialized in Vietnamese invoices. '
                '\n'
                'PRIMARY RULE: Extract EXACTLY ONE amount per item line - always from the RIGHTMOST/FINAL column.\n'
                '\n'
                'NEVER:\n'
                '- Read from intermediate price columns\n'
                '- Concatenate multiple amounts\n'
                '- Extract unit prices\n'
                '- Include totals or tax rows\n'
                '\n'
                'ALWAYS:\n'
                '- Use the rightmost amount in each row\n'
                '- Return format: ITEM: [name] | AMOUNT: [one amount only] | CATEGORY: [type]\n'
                '- Convert Vietnamese: 49.800,00 → 49800 (single integer)\n'
                '- Verify amount is reasonable (1000+ VND)\n'
                '\n'
                'Categories: 🏠 Housing, 🍚 Food, 🚗 Transportation, 💡 Utilities, 🏥 Healthcare, 🎭 Entertainment, 🛍️ Shopping, Other.'
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
          'error':
              'AI service timeout: Image processing took too long. Please try with a clearer or smaller invoice image.'
        };
      }
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Provides AI with transaction context and financial knowledge base
  /// Returns the AI's response as a string
  /// For budget summaries, formats response as: "Based on your X monthly budget items: 1. Item (emoji): amount VND ... Total: amount VND"
  static Future<String> askFinancialQuestion(
      String question, String transactionContext) async {
    try {
      // Validate that GitHub token is configured
      if (AIConfig.githubToken.isEmpty) {
        return 'Error: GitHub token not configured. Please set GITHUB_TOKEN environment variable.';
      }

      final systemPrompt = '''You are a helpful financial advisor AI assistant. 
You have access to the user's transaction history and financial knowledge base.

## User's Transaction Context:
$transactionContext

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
        'temperature': 0.8,
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
