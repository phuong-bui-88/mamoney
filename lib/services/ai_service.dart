import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

  /// Extract text from invoice image using OCR (Google ML Kit)
  /// Handles mobile (imagePath) - web has limitations with on-device OCR
  /// Returns extracted text or error message
  static Future<String> _extractTextFromImage(
    String? imagePath, {
    Uint8List? imageBytes,
  }) async {
    try {
      // For web, image bytes can't be directly processed by on-device ML Kit
      // We would need to use cloud-based OCR (not implemented)
      if (kIsWeb && imageBytes != null && imagePath == null) {
        const errorMsg =
            'OCR on web platform requires cloud-based processing (not currently configured). Please use mobile app for invoice parsing.';
        _logger.warning(errorMsg);
        return errorMsg;
      }

      if (imagePath == null || imagePath.isEmpty) {
        const errorMsg =
            'Failed to extract text: Image path not provided. OCR only works on mobile platforms.';
        _logger.warning(errorMsg);
        return errorMsg;
      }

      _logger.info('OCR: Processing image file: $imagePath');

      // Create input image from file
      final inputImage = InputImage.fromFilePath(imagePath);

      // Create text recognizer and extract text
      final textRecognizer = TextRecognizer();
      _logger.info('OCR: Starting text recognition...');

      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // Combine all extracted text blocks
      final extractedText = recognizedText.text;
      _logger.info(
          'OCR: Successfully extracted ${extractedText.length} characters');

      if (extractedText.isNotEmpty) {
        _logger.fine(
            'Extracted text preview:\n${extractedText.substring(0, min(200, extractedText.length))}...');
      }

      await textRecognizer.close();

      return extractedText.isNotEmpty
          ? extractedText
          : 'OCR: No text found in image. Is this a valid invoice?';
    } catch (e, stackTrace) {
      final errorMsg = 'OCR extraction failed: $e';
      _logger.severe(errorMsg, e, stackTrace);
      return errorMsg;
    }
  }
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
    // Generate unique invoiceId and timestamp for this invoice import
    final invoiceId = const Uuid().v4();
    final invoiceDate = DateTime.now();

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

    // Step 1: Extract text from image using OCR
    _logger.info('Step 1: Extracting text from invoice image using OCR...');
    final extractedText = await _extractTextFromImage(
      imagePath,
      imageBytes: imageBytes,
    );

    // Check if OCR extraction failed
    if (extractedText.startsWith('OCR') || extractedText.startsWith('Failed')) {
      _logger.warning('OCR extraction failed: $extractedText');
      return {
        'items': [
          {'error': 'Failed to extract text from invoice: $extractedText'}
        ],
        'invoiceId': invoiceId,
        'invoiceDate': invoiceDate,
      };
    }

    _logger.info(
        'Step 2: Sending extracted text to AI for parsing (${extractedText.length} characters)...');

    // Step 2: Call GitHub Models API with extracted text (not image)
    final response = await _callGitHubModelsWithText(extractedText);

    if (response['success']) {
      final items = _extractInvoiceLineItems(response['message']);
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

  /// Extract all line items from invoice response
  /// Parses response lines with format: ITEM: [name] | AMOUNT: [amount] | CATEGORY: [category]
  /// Returns list of transaction maps
  static List<Map<String, String>> _extractInvoiceLineItems(String response) {
    final List<Map<String, String>> items = [];
    final lines = response.split('\n');

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      final item = _parseInvoiceItemLine(line);
      if (item.isNotEmpty) {
        items.add(item);
        _logger
            .info('✅ Parsed item: ${item['description']} - ${item['amount']}');
      }
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
      final cleanedAmount = cleanupAmount(amountStr);

      // Validate amount: reasonable invoice line item range (1,000-500,000 VND)
      // Amounts > 500k are likely subtotals or grand totals and are rejected
      if (cleanedAmount.isNotEmpty) {
        final amountNum = int.tryParse(cleanedAmount) ?? 0;
        if (amountNum >= 1000 && amountNum <= 500000) {
          // Valid Vietnamese line item amount
          result['amount'] = cleanedAmount;
        } else if (amountNum > 500000) {
          // Likely a total/subtotal - reject it
          _logger.info(
              'Rejected amount $amountNum: exceeds 500k (likely a total)');
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
  static String cleanupAmount(String amountStr) {
    if (amountStr.isEmpty) return '';

    _logger.fine('cleanupAmount input: "$amountStr"');

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

    _logger.fine('cleanupAmount after format detection: "$cleaned"');

    // Extract integer part (before any remaining decimal point)
    final parts = cleaned.split('.');
    final result = parts.first;
    _logger.fine('cleanupAmount final result: "$result"');
    return result;
  }

  /// Call GitHub Models API with extracted text from OCR
  static Future<Map<String, dynamic>> _callGitHubModelsWithText(
    String extractedText,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AIConfig.githubToken}',
      };

      // Updated prompt for OCR-extracted text (not image)
      final invoicePrompt =
          'Extract line items from this Vietnamese invoice text (extracted via OCR).\n'
          'Return ONLY the items list, no markdown, no explanation.\n'
          'Format EACH item: ITEM: [product name] | AMOUNT: [number] | CATEGORY: [category]\n'
          '\n'
          'CRITICAL RULES:\n'
          '1. Parse the extracted text to find product/item names and their amounts\n'
          '2. Match EACH item name with the amount on the SAME LINE - this is critical!\n'
          '3. Convert format: "27.500,00" → 27500 (remove separators, drop decimals)\n'
          '4. SKIP: Header rows, summary/total/subtotal rows, tax rows\n'
          '5. Item names should be product names (not column headers or totals)\n'
          '6. Do NOT confuse amounts between different items\n'
          '\n'
          'Categories (text only, NO EMOJIS): Housing, Food, Transportation, Utilities, Healthcare, Entertainment, Shopping, Other\n'
          '\n'
          'Example output:\n'
          'ITEM: Nước rửa chén Sunlight chanh 750g | AMOUNT: 27500 | CATEGORY: Shopping\n'
          'ITEM: Sữa chua uống men sống Probi dâu | AMOUNT: 124500 | CATEGORY: Food\n'
          '\n'
          'Extracted invoice text:\n$extractedText';

      final body = jsonEncode({
        'messages': [
          {
            'role': 'system',
            'content': 'You are a precise invoice data extraction specialist. '
                'Extract items from OCR-extracted text in this EXACT format: ITEM: [name] | AMOUNT: [number] | CATEGORY: [category] '
                'READ CAREFULLY: Match item descriptions with amounts from the SAME LINE ONLY. '
                'Do NOT mix up amounts between different items - each item gets ONE correct amount. '
                'Convert Vietnamese numbers (27.500,00) to plain integers (27500). '
                'Use ONLY text category names (Food, Housing, etc) - NO EMOJI symbols. '
                'Output ONLY the item lines, no JSON, no markdown, no explanations.',
          },
          {
            'role': 'user',
            'content': invoicePrompt,
          }
        ],
        'temperature': 0.3,
        'max_tokens': 2000,
        'model': AIConfig.model,
      });

      final response = await http
          .post(
            Uri.parse(AIConfig.getApiUrl()),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 60));

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
          _logger.info('API response received: ${data.runtimeType}');
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
              'AI service timeout: Text processing took too long. Please try again.'
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

## IMPORTANT INSTRUCTION:
If the user asks for a TOTAL (keywords: "tổng", "total", "bao nhiêu"), respond with ONLY the total amount:
"Total: amount VND"

For example:
- Question: "Cho tôi tổng chi trong tháng 3" → Answer: "Total: 18,685,580 VND"
- Question: "Tổng tiêu trong tháng 2 là bao nhiêu?" → Answer: "Total: 2,700,000 VND"

DO NOT show individual transactions if asked for a total.

FOR DETAILED BUDGET SUMMARIES (if user doesn't ask for just a total): Format as:
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
