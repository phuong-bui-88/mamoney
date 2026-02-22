import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Simple [TextInputFormatter] that inserts thousands separators as the user
/// types.  This is used throughout the app wherever users enter numeric
/// amounts so that the interface feels more natural ("1,234" instead of
/// "1234").
///
/// The implementation lives in its own file so it can be shared between
/// multiple screens and tested in isolation.  Previously the formatter was
/// duplicated in both `add_transaction_screen.dart` and
/// `edit_transaction_screen.dart` which made reuse hard and led to duplicated
/// tests.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // When the field is empty we simply propagate the change.  This also
    // handles the case where the user deletes all text.
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove any existing commas before attempting to parse - the formatter
    // will re-insert them where appropriate.
    final text = newValue.text.replaceAll(',', '');

    if (text.isEmpty) {
      return newValue;
    }

    final formatter = NumberFormat('#,##0', 'en_US');
    try {
      final value = double.parse(text);

      // Disallow negative numbers – the UI only works with positive amounts.
      if (value < 0) {
        return oldValue;
      }

      // Truncate any decimal portion rather than rounding so that "1234.5"
      // becomes "1,234" instead of "1,235".  This matches user expectations
      // when typing amounts (they are usually integers).
      final int intVal = value.truncate();
      final formatted = formatter.format(intVal);

      // Maintain the position of the cursor.  `newValue.selection.baseOffset`
      // is the cursor position in the *unformatted* text, so we need to
      // offset it by the number of commas that appear before that position
      // in the formatted string.
      int unformattedCursorPos = newValue.selection.baseOffset;
      if (unformattedCursorPos < 0) {
        // When the selection isn't provided (e.g. when constructing a
        // TextEditingValue directly in tests) the baseOffset will be -1.  In
        // that case treat the cursor as being at the end of the input.
        unformattedCursorPos = text.length;
      }

      int commasBeforeCursor = 0;
      int digitsSeen = 0;
      for (int i = 0;
          i < formatted.length && digitsSeen < unformattedCursorPos;
          i++) {
        if (formatted[i] == ',') {
          commasBeforeCursor++;
        } else {
          digitsSeen++;
        }
      }

      final newCursorPos = unformattedCursorPos + commasBeforeCursor;

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: newCursorPos),
      );
    } catch (e) {
      // If parsing fails for any reason, fall back to the previous value so
      // that we don't corrupt the input.
      return oldValue;
    }
  }
}
