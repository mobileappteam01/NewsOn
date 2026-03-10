import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore schema (single source of truth):
///   users/{userId}/completedNews/{newsId}
///   Document: { newsId: string, completedAt: Timestamp, category: string }
class CompletedNewsService {
  CompletedNewsService._();
  static final CompletedNewsService instance = CompletedNewsService._();

  static const String _usersCollection = 'users';
  static const String _completedNewsSubcollection = 'completedNews';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Marks a news item as completed. Returns true on success.
  Future<bool> markNewsCompleted({
    required String userId,
    required String newsId,
    required String category,
  }) async {
    if (userId.isEmpty) {
      debugPrint('❌ [CompletedNews] WRITE SKIP: userId empty');
      return false;
    }
    if (newsId.isEmpty) {
      debugPrint('❌ [CompletedNews] WRITE SKIP: newsId empty');
      return false;
    }

    final path =
        '$_usersCollection/$userId/$_completedNewsSubcollection/$newsId';
    debugPrint(
        '📤 [CompletedNews] WRITE userId=$userId newsId=$newsId category=$category');

    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_completedNewsSubcollection)
          .doc(newsId)
          .set({
        'newsId': newsId,
        'completedAt': FieldValue.serverTimestamp(),
        'category': category,
      }, SetOptions(merge: true));

      debugPrint('✅ [CompletedNews] WRITE success path=$path');
      return true;
    } on FirebaseException catch (e, st) {
      debugPrint(
          '❌ [CompletedNews] WRITE FAILED code=${e.code} message=${e.message}');
      debugPrint('   $st');
      return false;
    } catch (e, st) {
      debugPrint('❌ [CompletedNews] WRITE FAILED error=$e');
      debugPrint('   $st');
      return false;
    }
  }

  /// Removes completed status. Returns true on success.
  Future<bool> removeCompletedNews({
    required String userId,
    required String newsId,
  }) async {
    if (userId.isEmpty || newsId.isEmpty) return false;

    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_completedNewsSubcollection)
          .doc(newsId)
          .delete();

      debugPrint('✅ [CompletedNews] DELETE userId=$userId newsId=$newsId');
      return true;
    } catch (e, st) {
      debugPrint('❌ [CompletedNews] DELETE FAILED error=$e');
      debugPrint('   $st');
      return false;
    }
  }

  /// Stream of completed news IDs. Provider updates only from this stream.
  Stream<Set<String>> getCompletedNewsStream(String userId) {
    if (userId.isEmpty) return Stream.value(<String>{});

    debugPrint('📡 [CompletedNews] STREAM subscribe userId=$userId');

    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_completedNewsSubcollection)
        .snapshots()
        .map((snapshot) {
      final ids = <String>{};
      for (final doc in snapshot.docs) {
        ids.add(doc.data()['newsId'] as String? ?? doc.id);
      }
      debugPrint('📡 [CompletedNews] STREAM update count=${ids.length}');
      return ids;
    });
  }

  /// One-time fetch for initial load.
  Future<Set<String>> getCompletedNewsOnce(String userId) async {
    if (userId.isEmpty) return {};

    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_completedNewsSubcollection)
          .get();

      final ids = <String>{};
      for (final doc in snapshot.docs) {
        ids.add(doc.data()['newsId'] as String? ?? doc.id);
      }
      debugPrint('✅ [CompletedNews] FETCH userId=$userId count=${ids.length}');
      return ids;
    } catch (e, st) {
      debugPrint('❌ [CompletedNews] FETCH FAILED error=$e');
      debugPrint('   $st');
      rethrow;
    }
  }
}
