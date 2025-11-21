import 'package:newson/data/services/api_service.dart';

/// Auth API Service for handling authentication-related API calls
class AuthApiService {
  final ApiService _apiService = ApiService();

  /// Sign up user after Google Sign-In and category selection
  /// Maps Google Sign-In account data to the required API request body
  Future<SignUpResponse> signUp({
    required Map<String, dynamic> googleAccountData,
    required String nickName,
    String? fcmToken,
    required List<String> categoryIds, // Array of category IDs
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
        'nickName':
            nickName.isNotEmpty
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
          message:
              response.data is Map
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
          message:
              response.data is Map
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
