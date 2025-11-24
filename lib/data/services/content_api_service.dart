import 'package:flutter/foundation.dart';
import '../models/content_model.dart';
import 'api_service.dart';

/// Content API Service for fetching Terms & Conditions and Privacy Policy
class ContentApiService {
  final ApiService _apiService = ApiService();

  /// Get all content (Terms & Conditions and Privacy Policy)
  /// Returns the active content if available
  Future<ContentResponse> getAllContents() async {
    try {
      final response = await _apiService.get(
        'app', // Module name in Firestore apiEndPoints collection
        'termsAndConditions', // Endpoint key in the app document
      );

      if (response.success) {
        if (response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          return ContentResponse.fromJson(data);
        } else if (response.data is List) {
          // If data is directly a list
          return ContentResponse.fromJson({
            'message': 'success',
            'data': response.data,
          });
        } else {
          return ContentResponse(
            success: false,
            message: 'Invalid response format',
            content: [],
          );
        }
      } else {
        return ContentResponse(
          success: false,
          message: response.error ?? 'Failed to load content',
          content: [],
        );
      }
    } catch (e) {
      debugPrint('Error loading content: $e');
      return ContentResponse(
        success: false,
        message: 'Error loading content: $e',
        content: [],
      );
    }
  }

  /// Get Terms and Conditions
  Future<String?> getTermsAndConditions() async {
    try {
      final response = await getAllContents();
      if (response.success && response.activeContent != null) {
        return response.activeContent!.termsAndCondition;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching terms and conditions: $e');
      return null;
    }
  }

  /// Get Privacy Policy
  Future<String?> getPrivacyPolicy() async {
    try {
      final response = await getAllContents();
      if (response.success && response.activeContent != null) {
        return response.activeContent!.privacyPolicy;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching privacy policy: $e');
      return null;
    }
  }
}

