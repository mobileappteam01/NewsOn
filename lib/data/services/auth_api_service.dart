import 'package:newson/data/services/api_service.dart';

/// Parsed result from auth sign-up / sign-in endpoint.
class AuthSignUpResult {
  const AuthSignUpResult({
    required this.success,
    required this.message,
    this.token,
    this.userData,
    this.isNewUser = false,
  });

  final bool success;
  final String message;
  final String? token;
  final Map<String, dynamic>? userData;
  final bool isNewUser;

  factory AuthSignUpResult.fromSignUpResponse(SignUpResponse response) {
    if (!response.success) {
      return AuthSignUpResult(
        success: false,
        message: response.message,
      );
    }

    if (response.data is! Map<String, dynamic>) {
      return const AuthSignUpResult(
        success: false,
        message: 'Invalid response format',
      );
    }

    final data = response.data as Map<String, dynamic>;
    final token = data['token'] as String?;
    final userData = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data['data'] is Map
            ? Map<String, dynamic>.from(data['data'] as Map)
            : null;

    final rawNewUser = data['newUser'];
    final isNewUser = rawNewUser == true ||
        rawNewUser == 1 ||
        rawNewUser?.toString().toLowerCase() == 'true';

    if (token == null || token.isEmpty || userData == null) {
      return AuthSignUpResult(
        success: false,
        message: 'Invalid response: missing token or user data',
        isNewUser: isNewUser,
      );
    }

    return AuthSignUpResult(
      success: true,
      message: data['message']?.toString() ?? response.message,
      token: token,
      userData: userData,
      isNewUser: isNewUser,
    );
  }
}

/// Auth API Service for handling authentication-related API calls
class AuthApiService {
  final ApiService _apiService = ApiService();

  /// Sign up / sign in user after OAuth (Google / Apple).
  /// [categoryIds] may be empty on first auth; new users select categories later.
  Future<SignUpResponse> signUp({
    required Map<String, dynamic> googleAccountData,
    required String nickName,
    String? fcmToken,
    List<String> categoryIds = const [],
  }) async {
    try {
      // Extract user details from Google account data
      final displayName = googleAccountData['displayName'] as String? ?? '';
      final email = googleAccountData['email'] as String? ?? '';

      // Split display name into first and last name
      final nameParts = displayName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final secondName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // Prepare request body
      final requestBody = {
        'nickName': nickName.isNotEmpty
            ? nickName
            : (firstName.isNotEmpty
                ? firstName
                : (email.isNotEmpty ? email.split('@').first : 'User')),
        'email': email,
        'firstName': firstName,
        'secondName': secondName,
        'personalDetails': {
          'firstName': firstName,
          'displayName': displayName,
          'email': email,
        },
        'fcmTokenUser': fcmToken ?? '',
        'category': categoryIds, // Send as array of IDs: ["12","13","14"]
      };

      // Make API call
      final response = await _apiService.post(
        'auth', // Module name in Firestore apiEndPoints collection
        'signUp', // Endpoint key in the auth document
        body: requestBody,
      );

      if (response.success) {
        return SignUpResponse(
          success: true,
          data: response.data,
          message: response.data is Map
              ? (response.data['message'] ?? 'Sign up successful')
              : 'Sign up successful',
        );
      } else {
        return SignUpResponse(
          success: false,
          data: response.data,
          message: response.error ?? 'Sign up failed',
        );
      }
    } catch (e) {
      return SignUpResponse(
        success: false,
        data: null,
        message: 'Error during sign up: $e',
      );
    }
  }

  /// Sign in user (if needed in future)
  Future<SignInResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final requestBody = {'email': email, 'password': password};

      final response = await _apiService.post(
        'auth',
        'signIn', // Assuming this endpoint exists
        body: requestBody,
      );

      if (response.success) {
        return SignInResponse(
          success: true,
          data: response.data,
          message: response.data is Map
              ? (response.data['message'] ?? 'Sign in successful')
              : 'Sign in successful',
        );
      } else {
        return SignInResponse(
          success: false,
          data: response.data,
          message: response.error ?? 'Sign in failed',
        );
      }
    } catch (e) {
      return SignInResponse(
        success: false,
        data: null,
        message: 'Error during sign in: $e',
      );
    }
  }
}

/// Sign Up Response model
class SignUpResponse {
  final bool success;
  final dynamic data;
  final String message;

  SignUpResponse({
    required this.success,
    required this.data,
    required this.message,
  });

  @override
  String toString() {
    return 'SignUpResponse(success: $success, message: $message)';
  }
}

/// Sign In Response model
class SignInResponse {
  final bool success;
  final dynamic data;
  final String message;

  SignInResponse({
    required this.success,
    required this.data,
    required this.message,
  });

  @override
  String toString() {
    return 'SignInResponse(success: $success, message: $message)';
  }
}
