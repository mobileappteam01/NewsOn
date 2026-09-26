/// Canonical V2 Account Settings profile (maps server nickName/secondName).
class V2AccountProfile {
  const V2AccountProfile({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.dateOfBirth,
    this.mobileNumber = '',
    this.country = '',
    this.city = '',
    this.pincode = '',
    this.categoryIds = const [],
  });

  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;

  /// Canonical `YYYY-MM-DD` or null when unset.
  final String? dateOfBirth;
  final String mobileNumber;
  final String country;
  final String city;
  final String pincode;
  final List<String> categoryIds;

  factory V2AccountProfile.fromJson(Map<String, dynamic> json) {
    final personal = json['personalDetails'];
    Map<String, dynamic>? personalMap;
    if (personal is Map) {
      personalMap = Map<String, dynamic>.from(personal);
    }

    String? dob = _readString(json['dateOfBirth']);
    if (dob != null && dob.contains('T')) {
      dob = dob.split('T').first;
    }

    final categories = <String>[];
    final rawCats = json['categoryIds'] ?? json['category'];
    if (rawCats is List) {
      for (final item in rawCats) {
        final id = item is Map
            ? (item['id'] ?? item['_id'])?.toString()
            : item?.toString();
        final token = id?.trim() ?? '';
        if (token.isNotEmpty) categories.add(token);
      }
    }

    return V2AccountProfile(
      id: _readString(json['id'] ?? json['_id']) ?? '',
      username: _readString(json['username'] ?? json['nickName']) ?? '',
      firstName: _readString(json['firstName']) ?? '',
      lastName: _readString(json['lastName'] ?? json['secondName']) ?? '',
      email: _readString(json['email']) ?? '',
      dateOfBirth: (dob != null && dob.isNotEmpty) ? dob : null,
      mobileNumber: _readString(
            json['mobileNumber'] ?? personalMap?['mobileNumber'],
          ) ??
          '',
      country: _readString(json['country'] ?? personalMap?['country']) ?? '',
      city: _readString(json['city'] ?? personalMap?['city']) ?? '',
      pincode: _readString(json['pincode'] ?? personalMap?['pincode']) ?? '',
      categoryIds: categories,
    );
  }

  static V2AccountProfile? parseResponse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);

    // Prefer nested envelope: { success, data: { profile: {...} } }
    final data = map['data'];
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);
      final nestedProfile = dataMap['profile'];
      if (nestedProfile is Map) {
        return V2AccountProfile.fromJson(
          Map<String, dynamic>.from(nestedProfile),
        );
      }
      // Flat data fallback: { data: { username, ... } }
      return V2AccountProfile.fromJson(dataMap);
    }

    // Direct profile map or { profile: {...} }
    final profile = map['profile'];
    if (profile is Map) {
      return V2AccountProfile.fromJson(Map<String, dynamic>.from(profile));
    }
    return V2AccountProfile.fromJson(map);
  }

  Map<String, dynamic> toPatchBody({
    String? username,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    bool clearDateOfBirth = false,
    String? mobileNumber,
    String? country,
    String? city,
  }) {
    return {
      if (username != null) 'username': username.trim(),
      if (firstName != null) 'firstName': firstName.trim(),
      if (lastName != null) 'lastName': lastName.trim(),
      if (clearDateOfBirth)
        'dateOfBirth': null
      else if (dateOfBirth != null)
        'dateOfBirth': dateOfBirth,
      if (mobileNumber != null) 'mobileNumber': mobileNumber.trim(),
      if (country != null) 'country': country.trim(),
      if (city != null) 'city': city.trim(),
    };
  }

  /// PATCH body with only fields that differ from [this].
  Map<String, dynamic> changedPatchBody({
    required String nextUsername,
    required String nextFirstName,
    required String nextLastName,
    required String nextMobileNumber,
    required String? nextDateOfBirthYmd,
    required String? nextCountry,
    required String? nextCity,
  }) {
    final body = <String, dynamic>{};
    final usernameValue = nextUsername.trim();
    final firstNameValue = nextFirstName.trim();
    final lastNameValue = nextLastName.trim();
    final mobileValue = nextMobileNumber.trim();
    final countryValue = (nextCountry ?? '').trim();
    final cityValue = (nextCity ?? '').trim();
    final dobValue = (nextDateOfBirthYmd == null || nextDateOfBirthYmd.isEmpty)
        ? null
        : nextDateOfBirthYmd;

    if (usernameValue != username) body['username'] = usernameValue;
    if (firstNameValue != firstName) body['firstName'] = firstNameValue;
    if (lastNameValue != lastName) body['lastName'] = lastNameValue;
    if (mobileValue != mobileNumber) body['mobileNumber'] = mobileValue;
    if (countryValue != country) body['country'] = countryValue;
    if (cityValue != city) body['city'] = cityValue;
    if (dobValue != dateOfBirth) body['dateOfBirth'] = dobValue;
    return body;
  }

  /// Flatten into local [UserService] userData keys used elsewhere.
  Map<String, dynamic> toLocalUserData(Map<String, dynamic>? existing) {
    final merged = Map<String, dynamic>.from(existing ?? const {});
    merged['_id'] = id;
    merged['nickName'] = username;
    merged['firstName'] = firstName;
    merged['secondName'] = lastName;
    merged['email'] = email;
    if (dateOfBirth != null) {
      merged['dateOfBirth'] = dateOfBirth;
    } else {
      merged.remove('dateOfBirth');
    }
    merged['mobileNumber'] = mobileNumber;
    merged['country'] = country;
    merged['city'] = city;
    merged['pincode'] = pincode;
    merged['personalDetails'] = {
      'mobileNumber': mobileNumber,
      'country': country,
      'city': city,
      'pincode': pincode,
    };
    if (categoryIds.isNotEmpty) {
      merged['category'] = List<String>.from(categoryIds);
    }
    return merged;
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

enum V2AccountPhase {
  loading,
  loaded,
  editing,
  saving,
  saved,
  validationError,
  apiError,
}

class V2AccountState {
  const V2AccountState({
    this.phase = V2AccountPhase.loading,
    this.profile,
    this.error,
    this.fieldErrors = const {},
  });

  final V2AccountPhase phase;
  final V2AccountProfile? profile;
  final String? error;
  final Map<String, String> fieldErrors;

  bool get isLoading => phase == V2AccountPhase.loading;
  bool get isSaving => phase == V2AccountPhase.saving;
  bool get hasProfile => profile != null;

  V2AccountState copyWith({
    V2AccountPhase? phase,
    V2AccountProfile? profile,
    String? error,
    Map<String, String>? fieldErrors,
    bool clearError = false,
  }) {
    return V2AccountState(
      phase: phase ?? this.phase,
      profile: profile ?? this.profile,
      error: clearError ? null : (error ?? this.error),
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}
