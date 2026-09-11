import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import '../core/constants.dart';

class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  Future<void> _ensureSession() async {
    if (_client.auth.currentSession == null) {
      try {
        await _client.auth.signInWithPassword(
          email: 'retailer@demo.com',
          password: AppConstants.demoPassword,
        );
      } catch (e) {
        debugPrint('StorageService session login note: $e');
      }
    }
  }

  /// Upload a destruction certificate document.
  /// Returns a signed URL (or object path) of the uploaded file in the private certificates bucket.
  Future<String> uploadCertificate({
    required File file,
    required String disposalRecordId,
  }) async {
    await _ensureSession();
    final ext = p.extension(file.path);
    final path = 'certificates/$disposalRecordId$ext';
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

    await _client.storage
        .from(AppConstants.certificatesBucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    try {
      final signedUrl = await _client.storage
          .from(AppConstants.certificatesBucket)
          .createSignedUrl(path, 60 * 60 * 24 * 365); // 1-year valid signed URL
      return signedUrl;
    } catch (_) {
      return path;
    }
  }

  /// Upload a pharmacy return proof photo to the private certificates bucket.
  /// Stores under: `proofs/<unique-proof-filename>.jpg`
  /// Returns a signed URL (or object path) valid for viewing the private object.
  Future<String> uploadProof({
    required File file,
    String? batchId,
  }) async {
    await _ensureSession();
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final idPart = batchId ?? 'batch';
    final fileName = 'proof_${idPart}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final path = 'proofs/$fileName';
    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';

    await _client.storage
        .from(AppConstants.certificatesBucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    try {
      final signedUrl = await _client.storage
          .from(AppConstants.certificatesBucket)
          .createSignedUrl(path, 60 * 60 * 24 * 365); // 1-year valid signed URL
      return signedUrl;
    } catch (_) {
      return path;
    }
  }

  /// Upload a destruction video to the private certificates bucket.
  /// Stores under: `videos/<unique-video-filename>.mp4`
  /// Returns a signed URL (or object path) valid for viewing the private object.
  Future<String> uploadDestructionVideo({
    required File file,
    required String batchId,
  }) async {
    await _ensureSession();
    final ext = p.extension(file.path).isEmpty ? '.mp4' : p.extension(file.path);
    final fileName = 'video_${batchId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final path = 'videos/$fileName';
    final mimeType = lookupMimeType(file.path) ?? 'video/mp4';

    await _client.storage
        .from(AppConstants.certificatesBucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    try {
      final signedUrl = await _client.storage
          .from(AppConstants.certificatesBucket)
          .createSignedUrl(path, 60 * 60 * 24 * 365); // 1-year valid signed URL
      return signedUrl;
    } catch (_) {
      return path;
    }
  }
}

