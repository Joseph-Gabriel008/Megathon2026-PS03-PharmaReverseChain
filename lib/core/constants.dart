import 'dart:convert';

/// MediLoop — App-wide constants
/// Replace placeholder values with real credentials before running.
class AppConstants {
  // ───────────────────────────────────────────────────────
  //  Supabase credentials — live project
  // ───────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://hfiyeaiaqliilpmpbntk.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_cVGbwhDrz5zY1-85hqnzIQ_PJiIcTv_';

  /// Toggle this to TRUE if hackathon Wi-Fi is down or backend is unreachable.
  /// Runs 100% locally with zero network calls using in-memory MockDatabase.
  static const bool forceOfflineDemoMode = false;

  // ───────────────────────────────────────────────────────
  //  Gemini API
  // ───────────────────────────────────────────────────────
  static String get geminiApiKey {
    const fromEnv = String.fromEnvironment('GEMINI_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return utf8.decode(base64Decode('QVEuQWI4Uk42SkJRb1gwZmxOOWtfa09DSkgzSTItMkJrUnZKblBpbnc0R2tIYXFuRTBENlE='));
  }
  static const String geminiModel = 'gemini-3.6-flash';

  // ───────────────────────────────────────────────────────
  //  Demo credentials (seeded in Supabase Auth)
  // ───────────────────────────────────────────────────────
  static const String demoPassword = 'Demo@2025';
  static const Map<String, String> demoLogins = {
    'retailer': 'retailer@demo.com',
    'distributor': 'distributor@demo.com',
    'manufacturer': 'manufacturer@demo.com',
    'facility': 'facility@demo.com',
    'admin': 'admin@demo.com',
  };

  // ───────────────────────────────────────────────────────
  //  Batch status lifecycle
  // ───────────────────────────────────────────────────────
  static const List<String> batchStatusLifecycle = [
    'ACTIVE',
    'EXPIRING_SOON',
    'EXPIRED',
    'RETURN_INITIATED',
    'IN_TRANSIT',
    'COLLECTED',
    'DISTRIBUTOR_VERIFIED',
    'MANUFACTURER_RECEIVED',
    'DISPOSAL_PENDING',
    'SENT_FOR_DESTRUCTION',
    'DESTROYED',
    'CLOSED',
  ];

  // ───────────────────────────────────────────────────────
  //  Supabase Storage
  // ───────────────────────────────────────────────────────
  static const String certificatesBucket = 'certificates';

  // ───────────────────────────────────────────────────────
  //  Demo batch for fraud demo
  // ───────────────────────────────────────────────────────
  static const String demoBatchNumber = 'PARA500-2026-001';
}
