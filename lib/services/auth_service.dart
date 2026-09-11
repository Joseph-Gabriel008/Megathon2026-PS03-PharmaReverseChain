import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../data/mock_database.dart';
import '../models/app_user.dart';

class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get currentRole => _currentUser?.role;

  final SupabaseClient _client;

  AuthService(this._client) {
    try {
      _client.auth.onAuthStateChange.listen((event) async {
        if (event.event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          notifyListeners();
        } else if (event.event == AuthChangeEvent.signedIn ||
            event.event == AuthChangeEvent.tokenRefreshed) {
          await _loadCurrentUser();
        }
      });
      // Check existing session on startup
      if (_client.auth.currentSession != null) {
        _loadCurrentUser();
      }
    } catch (e) {
      debugPrint('AuthService initialization note: $e');
    }
  }

  static String normalizeEmail(String input) {
    final clean = input.trim().toLowerCase();
    return switch (clean) {
      'distributor' ||
      'distributer' ||
      'distributor@medplus.com' ||
      'distributor@medsupply.com' ||
      'distributor@mediloop.com' =>
        'distributor@demo.com',
      'retailer' ||
      'pharmacy' ||
      'retailer@apollo.com' ||
      'retailer@mediloop.com' =>
        'retailer@demo.com',
      'manufacturer' ||
      'manufacturer@cipla.com' ||
      'manufacturer@mediloop.com' =>
        'manufacturer@demo.com',
      'facility' ||
      'waste' ||
      'waste_facility' ||
      'facility@bioclean.com' =>
        'facility@demo.com',
      'admin' ||
      'regulator' ||
      'cdsco' ||
      'admin@cdsco.gov.in' =>
        'admin@demo.com',
      _ => clean,
    };
  }

  Future<void> loginAsDemoRole(String role) async {
    _isLoading = true;
    notifyListeners();
    try {
      final emailKey = AppConstants.demoLogins[role.toLowerCase()] ??
          normalizeEmail(role);
      final mockUser = MockDatabase.instance.getUser(emailKey);
      if (mockUser != null) {
        _currentUser = mockUser;
      }
      try {
        await _client.auth.signInWithPassword(
          email: emailKey,
          password: AppConstants.demoPassword,
        );
      } catch (e) {
        debugPrint('loginAsDemoRole Supabase auth note: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return;
    try {
      final data = await _client
          .from('users')
          .select('*, organizations(name, type)')
          .eq('id', authUser.id)
          .single();
      _currentUser = AppUser.fromJson(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load user profile: $e');
      final email = authUser.email;
      if (email != null) {
        final mock = MockDatabase.instance.getUser(normalizeEmail(email));
        if (mock != null) {
          _currentUser = mock;
          notifyListeners();
        }
      }
    }
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final normalized = normalizeEmail(email);
    final mockUser = MockDatabase.instance.getUser(normalized);
    final isDemoPassword = password == AppConstants.demoPassword ||
        password.toLowerCase() == 'demo' ||
        password.toLowerCase() == 'distributor' ||
        password.toLowerCase() == 'distributer' ||
        password == '123456';

    // 1. Instant access for recognized demo users with valid demo password
    if (mockUser != null && (isDemoPassword || password.isEmpty)) {
      _currentUser = mockUser;
      _isLoading = false;
      notifyListeners();
      try {
        await _client.auth.signInWithPassword(
          email: normalized,
          password: AppConstants.demoPassword,
        );
      } catch (e) {
        debugPrint('Demo login Supabase auth note: $e');
      }
      return null;
    }

    try {
      // 2. Direct offline demo login if placeholder Supabase
      if (AppConstants.supabaseUrl.contains('YOUR_PROJECT_ID')) {
        if (mockUser != null) {
          _currentUser = mockUser;
          return null;
        }
      }

      // 3. Attempt real Supabase authentication
      await _client.auth.signInWithPassword(
        email: normalized,
        password: password,
      );
      await _loadCurrentUser();

      // If auth succeeded but profile row missing, fallback to mockUser
      if (_currentUser == null && mockUser != null) {
        _currentUser = mockUser;
      }

      return _currentUser != null ? null : 'User profile not found in database.';
    } on AuthException catch (e) {
      // Fallback to offline mock for demo accounts
      if (mockUser != null && isDemoPassword) {
        _currentUser = mockUser;
        return null;
      }
      return e.message;
    } catch (e) {
      // Fallback for network loss / offline debugging
      if (mockUser != null) {
        _currentUser = mockUser;
        return null;
      }
      return 'Login failed. Check your connection or use demo access.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _client.auth.signOut().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('Supabase signOut timed out, proceeding with local logout');
        },
      );
    } catch (e) {
      debugPrint('Supabase signOut note: $e');
    }
    _currentUser = null;
    notifyListeners();
  }
}
