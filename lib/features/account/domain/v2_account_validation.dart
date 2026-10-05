import 'package:flutter/widgets.dart' show StringCharacters;

import 'v2_account_profile.dart';

/// Field error codes for V2 Account Settings. The screen maps each code to a
/// localized message.
abstract final class V2AccountFieldError {
  static const required = 'required';
  static const tooShort = 'too_short';
  static const placeholder = 'placeholder';
  static const invalidMobile = 'invalid_mobile';
  static const invalidDate = 'invalid_date';
  static const invalidCountry = 'invalid_country';
}

/// Rules for the Account Settings form, shared by typing, focus loss and Save.
abstract final class V2AccountValidation {
  /// Minimum visible characters (after trim) for username and first name.
  static const int minNameLength = 3;

  static final RegExp _mobile = RegExp(r'^\+?[0-9][0-9\s\-()]{6,20}$');
  static final RegExp _ymd = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static String? username(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return V2AccountFieldError.required;
    if (value.characters.length < minNameLength) {
      return V2AccountFieldError.tooShort;
    }
    if (V2AccountProfile.isPlaceholderUsername(value)) {
      return V2AccountFieldError.placeholder;
    }
    return null;
  }

  static String? firstName(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return V2AccountFieldError.required;
    if (value.characters.length < minNameLength) {
      return V2AccountFieldError.tooShort;
    }
    return null;
  }

  /// Last name is optional; any trimmed value (including empty) is accepted.
  static String? lastName(String raw) => null;

  static String? mobileNumber(String raw) {
    final value = raw.trim();
    if (value.isEmpty || _mobile.hasMatch(value)) return null;
    return V2AccountFieldError.invalidMobile;
  }

  static String? dateOfBirth(String? ymd) {
    if (ymd == null || ymd.isEmpty || _ymd.hasMatch(ymd)) return null;
    return V2AccountFieldError.invalidDate;
  }
}
