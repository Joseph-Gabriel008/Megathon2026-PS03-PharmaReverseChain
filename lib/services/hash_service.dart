import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashService {
  /// Compute SHA-256 of (previousHash + eventData) to form the chain.
  static String computeEventHash({
    required String previousHash,
    required String eventData,
  }) {
    final input = previousHash + eventData;
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compute a standalone SHA-256 of any string (for certificate hashes).
  static String sha256Hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify that a sequence of events forms a valid hash chain.
  /// Returns null if valid, or an error message if tampered.
  static String? verifyChain(List<Map<String, dynamic>> events) {
    // events must be ordered by timestamp ascending
    String? previousHash;
    for (final event in events) {
      final storedHash = event['event_hash'] as String? ?? '';
      final storedPrevHash = event['previous_event_hash'] as String? ?? '';

      if (previousHash != null && storedPrevHash != previousHash) {
        return 'Hash chain broken at event ${event['id']}. '
            'Expected previous hash $previousHash but got $storedPrevHash.';
      }

      final eventData = json.encode({
        'batch_id': event['batch_id'],
        'event_type': event['event_type'],
        'actor_id': event['actor_id'],
        'quantity': event['quantity'],
        'new_status': event['new_status'],
        'timestamp': event['timestamp'],
      });

      final expectedHash = computeEventHash(
        previousHash: storedPrevHash,
        eventData: eventData,
      );

      if (storedHash != expectedHash) {
        return 'Hash mismatch at event ${event['id']}. '
            'Data may have been tampered.';
      }

      previousHash = storedHash;
    }
    return null; // chain is valid
  }
}
