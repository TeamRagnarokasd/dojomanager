import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data'; // For Uint8List
import './supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDocumentService {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Fetches user documents for a specific user ID or current authenticated user
  /// Excludes documents soft-deleted by the user (deleted_by_user = true)
  Future<List<Map<String, dynamic>>> getUserDocuments({String? userId}) async {
    try {
      String? targetUserId = userId;

      if (targetUserId == null) {
        final currentUser = _client.auth.currentUser;
        if (currentUser == null) {
          throw Exception('No authenticated user found');
        }
        targetUserId = currentUser.id;
      }

      final response = await _client
          .from('user_documents')
          .select()
          .eq('user_id', targetUserId)
          .eq('deleted_by_user', false) // Hide soft-deleted docs from user view
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user documents: $e');
      return [];
    }
  }

  // Upload document from File (mobile)
  Future<Map<String, dynamic>> uploadDocument(File file) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = '${user.id}/$fileName';

      await _client.storage.from('user_docs').upload(filePath, file);

      final fileExtension = fileName.split('.').last.toLowerCase();
      String fileType = 'other';
      if (['jpg', 'jpeg', 'png', 'webp'].contains(fileExtension)) {
        fileType = 'image';
      } else if (fileExtension == 'pdf') {
        fileType = 'pdf';
      } else if (['doc', 'docx'].contains(fileExtension)) {
        fileType = 'document';
      }

      final response = await _client
          .from('user_documents')
          .insert({
            'user_id': user.id,
            'file_name': fileName,
            'file_url': filePath,
            'file_type': fileType,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Upload failed: ${e.toString()}');
    }
  }

  // Upload document from bytes (web and mobile)
  Future<Map<String, dynamic>> uploadDocumentFromBytes(
    List<int> bytes,
    String fileName,
  ) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = '${timestamp}_$fileName';
      final filePath = '${user.id}/$newFileName';

      await _client.storage
          .from('user_docs')
          .uploadBinary(filePath, Uint8List.fromList(bytes));

      final fileExtension = fileName.split('.').last.toLowerCase();
      String fileType = 'other';
      if (['jpg', 'jpeg', 'png', 'webp'].contains(fileExtension)) {
        fileType = 'image';
      } else if (fileExtension == 'pdf') {
        fileType = 'pdf';
      } else if (['doc', 'docx'].contains(fileExtension)) {
        fileType = 'document';
      }

      final response = await _client
          .from('user_documents')
          .insert({
            'user_id': user.id,
            'file_name': newFileName,
            'file_url': filePath,
            'file_type': fileType,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Upload failed: ${e.toString()}');
    }
  }

  // Pick and upload document
  Future<Map<String, dynamic>?> pickAndUploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return null;

      final pickedFile = result.files.first;

      if (kIsWeb) {
        if (pickedFile.bytes == null) {
          throw Exception('Failed to read file data');
        }
        return await uploadDocumentFromBytes(
          pickedFile.bytes!,
          pickedFile.name,
        );
      }

      if (pickedFile.path == null) {
        throw Exception('File path is null');
      }
      final file = File(pickedFile.path!);
      return await uploadDocument(file);
    } catch (e) {
      throw Exception('Pick and upload failed: ${e.toString()}');
    }
  }

  // Get documents for specific user (admin only) - shows ALL documents including soft-deleted
  Future<List<Map<String, dynamic>>> getUserDocumentsByUserId(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('user_documents')
          .select()
          .eq('user_id', userId)
          // Admin sees ALL documents, including soft-deleted ones
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch documents: ${e.toString()}');
    }
  }

  // Get signed URL for document
  Future<String> getDocumentUrl(String filePath) async {
    try {
      final signedUrl = await _client.storage
          .from('user_docs')
          .createSignedUrl(filePath, 3600);
      return signedUrl;
    } catch (e) {
      throw Exception('Failed to get document URL: ${e.toString()}');
    }
  }

  /// Soft-delete: marks document as deleted by user (hidden from user, visible to admin)
  Future<void> softDeleteDocument(String documentId) async {
    try {
      await _client.from('user_documents').update({
        'deleted_by_user': true,
        'deleted_by_user_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', documentId);
    } catch (e) {
      throw Exception('Failed to soft-delete document: ${e.toString()}');
    }
  }

  /// Hard-delete: permanently removes document from storage and database (admin only)
  Future<void> deleteDocument(String documentId, String filePath) async {
    try {
      await _client.storage.from('user_docs').remove([filePath]);
      await _client.from('user_documents').delete().eq('id', documentId);
    } catch (e) {
      throw Exception('Failed to delete document: ${e.toString()}');
    }
  }

  // Download document (get signed URL for download)
  Future<String> downloadDocument(String filePath) async {
    try {
      return await getDocumentUrl(filePath);
    } catch (e) {
      throw Exception('Failed to download document: ${e.toString()}');
    }
  }
}
