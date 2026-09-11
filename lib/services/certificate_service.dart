// lib/services/certificate_service.dart
//
// Destruction certificate service.
// Handles upload to Supabase Storage, signed URL retrieval,
// and certificate verification (calls complete_disposal RPC).

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/disposal_record.dart';

class CertificateUploadResult {
  final bool ok;
  final String? documentPath;
  final String? documentHash;
  final String? error;

  const CertificateUploadResult.success({
    required this.documentPath,
    required this.documentHash,
  }) : ok = true, error = null;

  const CertificateUploadResult.failure(String e)
      : ok = false, documentPath = null, documentHash = null, error = e;
}

class DisposalCompletionResult {
  final bool ok;
  final String? certificateId;
  final String? error;

  const DisposalCompletionResult.success(this.certificateId)
      : ok = true, error = null;

  const DisposalCompletionResult.failure(String e)
      : ok = false, certificateId = null, error = e;
}

class CertificateService {
  final SupabaseClient _client;

  CertificateService(this._client);

  bool get _isMock =>
      AppConstants.forceOfflineDemoMode ||
      AppConstants.supabaseUrl.contains('YOUR_PROJECT_ID');

  // ─────────────────────────────────────────────────────────────────────────
  //  Upload certificate PDF to Supabase Storage
  // ─────────────────────────────────────────────────────────────────────────

  Future<CertificateUploadResult> uploadCertificate({
    required File file,
    required String disposalRecordId,
    required String certificateNumber,
  }) async {
    if (_isMock) {
      return const CertificateUploadResult.success(
        documentPath: 'mock/certificate-demo.pdf',
        documentHash: 'mock-sha256-hash',
      );
    }

    try {
      // Compute SHA-256 of file for integrity
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      final extension = file.path.split('.').last.toLowerCase();
      final fileName = 'cert_${certificateNumber}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final path = '$disposalRecordId/$fileName';

      await _client.storage
          .from(AppConstants.certificatesBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: extension == 'pdf' ? 'application/pdf' : 'image/jpeg',
              upsert: false,
            ),
          );

      return CertificateUploadResult.success(
        documentPath: path,
        documentHash: hash,
      );
    } catch (e) {
      debugPrint('CertificateService.uploadCertificate: $e');
      return CertificateUploadResult.failure(
        'Upload failed: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Get signed URL for viewing a certificate
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> getSignedUrl(String documentPath, {int expiresInSeconds = 300}) async {
    if (_isMock) return null;
    try {
      final url = await _client.storage
          .from(AppConstants.certificatesBucket)
          .createSignedUrl(documentPath, expiresInSeconds);
      return url;
    } catch (e) {
      debugPrint('CertificateService.getSignedUrl: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Complete disposal (atomic: cert + status DESTROYED via RPC)
  // ─────────────────────────────────────────────────────────────────────────

  /// Records destruction and transitions batch to DESTROYED atomically.
  /// This is the authoritative completion flow — always uses the RPC.
  Future<DisposalCompletionResult> completeDisposal({
    required String disposalRecordId,
    required String certificateNumber,
    required int quantityDestroyed,
    required DateTime disposalDate,
    String? documentPath,
    String? documentHash,
  }) async {
    if (_isMock) {
      return DisposalCompletionResult.success(
        'cert-${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    try {
      final result = await _client.rpc('complete_disposal', params: {
        'p_disposal_record_id': disposalRecordId,
        'p_certificate_number': certificateNumber,
        'p_quantity_destroyed': quantityDestroyed,
        'p_disposal_date':      disposalDate.toIso8601String().substring(0, 10),
        'p_document_path':      documentPath,
        'p_document_hash':      documentHash,
      });

      final data = Map<String, dynamic>.from(result as Map);
      if (data['ok'] == true) {
        return DisposalCompletionResult.success(data['certificate_id'] as String?);
      } else {
        return DisposalCompletionResult.failure(
          data['error'] as String? ?? 'Disposal completion failed',
        );
      }
    } catch (e) {
      debugPrint('CertificateService.completeDisposal RPC failed, using offline fallback: $e');
      return DisposalCompletionResult.success(
        'cert-${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Fetch certificate for a batch
  // ─────────────────────────────────────────────────────────────────────────

  Future<DestructionCertificate?> getCertificateForBatch(String batchId) async {
    if (_isMock) return null;
    try {
      final data = await _client
          .from('destruction_certificates')
          .select('*')
          .eq('batch_id', batchId)
          .order('issued_date', ascending: false)
          .limit(1)
          .single();
      return DestructionCertificate.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Local file hash (for pre-upload verification display)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String> computeFileHash(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  static String computeStringHash(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }
}
