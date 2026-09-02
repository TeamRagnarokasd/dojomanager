import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SponsorService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get all active sponsors ordered by display_order (only category='sponsor')
  static Future<List<Map<String, dynamic>>> getActiveSponsors() async {
    try {
      final response = await _supabase
          .from('sponsors')
          .select('*')
          .eq('status', 'active')
          .eq('category', 'sponsor')
          .order('display_order', ascending: true)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching sponsors: $error');
      return [];
    }
  }

  // Get all active affiliations ordered by display_order (only category='affiliazione')
  static Future<List<Map<String, dynamic>>> getActiveAffiliazioni() async {
    try {
      final response = await _supabase
          .from('sponsors')
          .select('*')
          .eq('status', 'active')
          .eq('category', 'affiliazione')
          .order('display_order', ascending: true)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching affiliazioni: $error');
      return [];
    }
  }

  // Get all sponsors (for admin management)
  static Future<List<Map<String, dynamic>>> getAllSponsors() async {
    try {
      final response = await _supabase
          .from('sponsors')
          .select('*')
          .order('display_order', ascending: true)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching all sponsors: $error');
      return [];
    }
  }

  // Create new sponsor with file upload (admin only)
  static Future<Map<String, dynamic>?> createSponsor({
    required String name,
    required String externalUrl,
    String? description,
    String? imageFilePath,
    int displayOrder = 0,
    String category = 'sponsor',
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('User not authenticated');
        return null;
      }

      String? imageUrl;

      // Upload image if provided
      if (imageFilePath != null && imageFilePath.isNotEmpty) {
        imageUrl = await uploadSponsorImage(imageFilePath);
        if (imageUrl == null) {
          print('Failed to upload sponsor image');
          return null;
        }
      }

      final response = await _supabase
          .from('sponsors')
          .insert({
            'name': name,
            'description': description,
            'image_url': imageUrl,
            'external_url': externalUrl,
            'status': 'active',
            'display_order': displayOrder,
            'created_by': user.id,
            'category': category,
          })
          .select()
          .single();

      return response;
    } catch (error) {
      print('Error creating sponsor: $error');
      return null;
    }
  }

  // Update sponsor with file upload (admin only)
  static Future<Map<String, dynamic>?> updateSponsor({
    required String id,
    String? name,
    String? description,
    String? imageFilePath,
    String? externalUrl,
    String? status,
    int? displayOrder,
    String? currentImageUrl,
    String? category,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (externalUrl != null) updateData['external_url'] = externalUrl;
      if (status != null) updateData['status'] = status;
      if (displayOrder != null) updateData['display_order'] = displayOrder;
      if (category != null) updateData['category'] = category;

      // Handle image upload/update
      if (imageFilePath != null) {
        if (imageFilePath.isNotEmpty) {
          // Upload new image
          final newImageUrl = await uploadSponsorImage(imageFilePath);
          if (newImageUrl != null) {
            updateData['image_url'] = newImageUrl;

            // Delete old image if it exists and is from our storage
            if (currentImageUrl != null &&
                currentImageUrl.contains('/sponsor-images/')) {
              await _deleteImageFromStorage(currentImageUrl);
            }
          }
        } else {
          // Remove image (empty path means remove)
          updateData['image_url'] = null;
          if (currentImageUrl != null &&
              currentImageUrl.contains('/sponsor-images/')) {
            await _deleteImageFromStorage(currentImageUrl);
          }
        }
      }

      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('sponsors')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      return response;
    } catch (error) {
      print('Error updating sponsor: $error');
      return null;
    }
  }

  // Delete sponsor (admin only)
  static Future<bool> deleteSponsor(String id) async {
    try {
      // Get sponsor data to check for image
      final sponsorData = await _supabase
          .from('sponsors')
          .select('image_url')
          .eq('id', id)
          .single();

      // Delete from database
      await _supabase.from('sponsors').delete().eq('id', id);

      // Delete image from storage if it exists
      if (sponsorData['image_url'] != null &&
          sponsorData['image_url'].contains('/sponsor-images/')) {
        await _deleteImageFromStorage(sponsorData['image_url']);
      }

      return true;
    } catch (error) {
      print('Error deleting sponsor: $error');
      return false;
    }
  }

  // Toggle sponsor status (admin only)
  static Future<bool> toggleSponsorStatus(
    String id,
    String currentStatus,
  ) async {
    try {
      final newStatus = currentStatus == 'active' ? 'inactive' : 'active';

      await _supabase
          .from('sponsors')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      return true;
    } catch (error) {
      print('Error toggling sponsor status: $error');
      return false;
    }
  }

  // Upload sponsor image to Supabase storage
  static Future<String?> uploadSponsorImage(String filePath) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final XFile file = XFile(filePath);
      final String originalName = file.name.toLowerCase();
      String fileExtension = originalName.contains('.')
          ? originalName.split('.').last
          : 'jpg';

      // Normalize extension
      if (fileExtension == 'jpeg') fileExtension = 'jpg';
      if (!['jpg', 'png', 'webp'].contains(fileExtension)) {
        fileExtension = 'jpg';
      }

      final fileName =
          'sponsor_${timestamp}_${user.id.substring(0, 8)}.$fileExtension';

      // Determine MIME type from extension
      final Map<String, String> mimeTypes = {
        'jpg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
      };
      final String contentType = mimeTypes[fileExtension] ?? 'image/jpeg';

      final bytes = await file.readAsBytes();

      String uploadResponse;

      if (kIsWeb) {
        uploadResponse = await _supabase.storage
            .from('sponsor-images')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(contentType: contentType),
            );
      } else {
        uploadResponse = await _supabase.storage
            .from('sponsor-images')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(contentType: contentType),
            );
      }

      if (uploadResponse.isNotEmpty) {
        // Get public URL for the uploaded image
        final publicUrl = _supabase.storage
            .from('sponsor-images')
            .getPublicUrl(fileName);

        return publicUrl;
      }

      return null;
    } catch (error) {
      print('Error uploading sponsor image: $error');
      return null;
    }
  }

  // Delete image from storage (private method)
  static Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find sponsor-images segment and get filename
      int bucketIndex = pathSegments.indexOf('sponsor-images');
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final fileName = pathSegments[bucketIndex + 1];

        await _supabase.storage.from('sponsor-images').remove([fileName]);
      }
    } catch (error) {
      print('Error deleting image from storage: $error');
      // Don't throw error as this is not critical
    }
  }

  // Get sponsor statistics (for admin dashboard)
  static Future<Map<String, int>> getSponsorStats() async {
    try {
      final allSponsors = await _supabase
          .from('sponsors')
          .select('status, category');

      final total = allSponsors.length;
      final active = allSponsors.where((s) => s['status'] == 'active').length;
      final inactive = total - active;
      final affiliazioni = allSponsors
          .where((s) => s['category'] == 'affiliazione')
          .length;

      return {
        'total': total,
        'active': active,
        'inactive': inactive,
        'affiliazioni': affiliazioni,
      };
    } catch (error) {
      print('Error fetching sponsor stats: $error');
      return {'total': 0, 'active': 0, 'inactive': 0, 'affiliazioni': 0};
    }
  }

  // Validate image file
  static bool isValidImageFile(String fileName) {
    final lowercaseName = fileName.toLowerCase();
    final validExtensions = ['jpg', 'jpeg', 'png', 'webp'];

    return validExtensions.any((ext) => lowercaseName.endsWith('.$ext'));
  }

  // Get image file size in MB
  static Future<double> getImageFileSizeInMB(String filePath) async {
    try {
      if (kIsWeb) {
        final XFile file = XFile(filePath);
        final bytes = await file.readAsBytes();
        return bytes.length / (1024 * 1024);
      } else {
        final file = File(filePath);
        final sizeInBytes = await file.length();
        return sizeInBytes / (1024 * 1024);
      }
    } catch (error) {
      print('Error getting file size: $error');
      return 0;
    }
  }
}
