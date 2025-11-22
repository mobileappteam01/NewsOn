import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/fcm_service.dart';

/// Profile Service - Handles user profile related API calls
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final ApiService _apiService = ApiService();
  final UserService _userService = UserService();
  final FcmService _fcmService = FcmService();

  /// Update FCM Token
  /// Called when home page initializes
  Future<ApiResponse> updateFCMToken() async {
    try {
      debugPrint('🔄 Updating FCM Token...');

      // Get FCM token
      final fcmToken = await _fcmService.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ FCM Token not available, skipping update');
        return ApiResponse(
          success: false,
          data: null,
          error: 'FCM token not available',
          statusCode: 0,
        );
      }

      // Get user token for authorization
      final userToken = _userService.getToken();
      if (userToken == null || userToken.isEmpty) {
        debugPrint('⚠️ User not logged in, skipping FCM token update');
        return ApiResponse(
          success: false,
          data: null,
          error: 'User not logged in',
          statusCode: 401,
        );
      }

      // Make API call (PUT method)
      final response = await _apiService.put(
        'profile',
        'updateFCMToken',
        body: {'fcmTokenUser': fcmToken},
        bearerToken: userToken,
      );

      if (response.success) {
        debugPrint('✅ FCM Token updated successfully');
      } else {
        debugPrint('❌ Failed to update FCM Token: ${response.error}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ Error updating FCM Token: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Get User Profile
  /// Fetches user profile data from the server
  Future<ApiResponse> getUserProfile() async {
    try {
      debugPrint('👤 Fetching user profile...');

      // Get user token for authorization
      final userToken = _userService.getToken();
      if (userToken == null || userToken.isEmpty) {
        debugPrint('⚠️ User not logged in');
        return ApiResponse(
          success: false,
          data: null,
          error: 'User not logged in',
          statusCode: 401,
        );
      }

      // Make API call
      final response = await _apiService.get(
        'profile',
        'getMyProfile',
        bearerToken: userToken,
      );

      if (response.success) {
        debugPrint('✅ User profile fetched successfully');
        // Update local user data if response contains user data
        // Response structure: {"message": "success", "data": {...userData...}}
        if (response.data != null && response.data is Map) {
          final responseMap = response.data as Map<String, dynamic>;
          // Extract user data from response.data['data']
          final userData = responseMap['data'] as Map<String, dynamic>?;
          if (userData != null) {
            debugPrint('📦 User data extracted:');
            debugPrint('   NickName: ${userData['nickName']}');
            debugPrint('   Email: ${userData['email']}');
            debugPrint('   FirstName: ${userData['firstName']}');
            // Update user service with fresh data
            await _userService.saveUserData(
              token: userToken,
              userData: userData,
            );
          }
        }
      } else {
        debugPrint('❌ Failed to fetch user profile: ${response.error}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Update User Profile
  /// Updates user profile with all provided fields
  Future<ApiResponse> updateProfile({
    required String nickName,
    required String email,
    required String firstName,
    required String secondName,
    Map? personalDetails,
    String? mobileNumber,
    String? city,
    String? pincode,
    String? country,
    List? category,
  }) async {
    try {
      debugPrint('💾 Updating user profile...');

      // Get user token for authorization
      final userToken = _userService.getToken();
      if (userToken == null || userToken.isEmpty) {
        debugPrint('⚠️ User not logged in');
        return ApiResponse(
          success: false,
          data: null,
          error: 'User not logged in',
          statusCode: 401,
        );
      }

      // Get FCM token
      final fcmToken = await _fcmService.getToken();

      // Build request body
      final requestBody = <String, dynamic>{
        'nickName': nickName,
        'email': email,
        'firstName': firstName,
        'secondName': secondName,
        'personalDetails': personalDetails,
        'fcmTokenUser': fcmToken ?? '',
        if (category != null && category.isNotEmpty) 'category': category,
        if (mobileNumber != null && mobileNumber.isNotEmpty)
          'mobileNumber': mobileNumber,
        if (city != null && city.isNotEmpty) 'city': city,
        if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
        if (country != null && country.isNotEmpty) 'country': country,
      };

      debugPrint('📦 Update Profile Request Body: $requestBody');

      // Make API call
      final response = await _apiService.put(
        'profile',
        'updateProfile',
        body: requestBody,
        bearerToken: userToken,
      );

      if (response.success) {
        debugPrint('✅ User profile updated successfully');
        // Update local user data if response contains updated user data
        // Response structure: {"message": "success", "data": {...userData...}}
        if (response.data != null && response.data is Map) {
          final responseMap = response.data as Map<String, dynamic>;
          // Extract user data from response.data['data']
          final userData = responseMap['data'] as Map<String, dynamic>?;
          if (userData != null) {
            // Update user service with fresh data
            await _userService.saveUserData(
              token: userToken,
              userData: userData,
            );
          }
        }
      } else {
        debugPrint('❌ Failed to update user profile: ${response.error}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }

  /// Logout User
  /// Calls logout API endpoint
  Future<ApiResponse> logout() async {
    try {
      debugPrint('🚪 Logging out user...');

      // Get user token for authorization
      final userToken = _userService.getToken();
      if (userToken == null || userToken.isEmpty) {
        debugPrint('⚠️ User not logged in');
        return ApiResponse(
          success: false,
          data: null,
          error: 'User not logged in',
          statusCode: 401,
        );
      }

      // Make API call
      final response = await _apiService.post(
        'profile',
        'logout',
        bearerToken: userToken,
      );

      if (response.success) {
        debugPrint('✅ User logged out successfully');
        // Clear local user data
        await _userService.clearUserData();
        // Clear FCM token
        await _fcmService.deleteToken();
      } else {
        debugPrint('❌ Failed to logout: ${response.error}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ Error logging out: $e');
      return ApiResponse(
        success: false,
        data: null,
        error: e.toString(),
        statusCode: 0,
      );
    }
  }
}
