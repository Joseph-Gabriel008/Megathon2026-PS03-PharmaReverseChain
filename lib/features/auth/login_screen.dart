import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/app_back_scope.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);
    final auth = context.read<AuthService>();
    final error = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _errorMessage = error);
    }
  }

  Future<void> _demoLogin(String role) async {
    final email = AppConstants.demoLogins[role] ?? 'distributor@demo.com';
    _emailCtrl.text = email;
    _passwordCtrl.text = AppConstants.demoPassword;
    setState(() => _errorMessage = null);
    final auth = context.read<AuthService>();
    await auth.loginAsDemoRole(role);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return AppBackScope(
      homeRoute: '/login',
      child: Scaffold(
        backgroundColor: MediLoopColors.paper,
        body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: MediLoopSpacing.lg,
            vertical: MediLoopSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildWordmark(),
                const SizedBox(height: MediLoopSpacing.xl),
                _buildLoginCard(auth),
                const SizedBox(height: MediLoopSpacing.xl),
                _buildDemoSection(auth),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildWordmark() {
    return Column(
      children: [
        // Glowing brand emblem
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: MediLoopColors.ink.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/icon.png',
              width: 76,
              height: 76,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'MediLoop',
          style: MediLoopText.h1.copyWith(
            fontSize: 30,
            letterSpacing: -0.8,
            color: MediLoopColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: MediLoopColors.verifiedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MediLoopColors.verified.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 13,
                color: MediLoopColors.verified,
              ),
              const SizedBox(width: 5),
              Text(
                'CDSCO 2025 COMPLIANCE PLATFORM',
                style: MediLoopText.inter(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: MediLoopColors.verified,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pharma reverse chain & verified drug destruction',
          textAlign: TextAlign.center,
          style: MediLoopText.bodyMuted.copyWith(fontSize: 13.5),
        ),
      ],
    );
  }

  Widget _buildLoginCard(AuthService auth) {
    return Container(
      decoration: BoxDecoration(
        color: MediLoopColors.surface,
        borderRadius: BorderRadius.circular(MediLoopRadius.card),
        border: Border.all(color: MediLoopColors.line, width: 1),
        boxShadow: MediLoopShadows.elevated,
      ),
      padding: const EdgeInsets.all(MediLoopSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Secure Sign In', style: MediLoopText.h3),
                const Spacer(),
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: MediLoopColors.textSubtle,
                ),
              ],
            ),
            const SizedBox(height: MediLoopSpacing.lg),

            // Email
            TextFormField(
              key: const Key('login_email'),
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'License / Email address or Role',
                prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                hintText: 'e.g. distributor@demo.com or distributor',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your email or role name';
                }
                final clean = v.trim().toLowerCase();
                const validRoles = [
                  'distributor',
                  'distributer',
                  'retailer',
                  'pharmacy',
                  'manufacturer',
                  'facility',
                  'admin',
                  'regulator',
                ];
                if (validRoles.contains(clean) || clean.contains('@')) {
                  return null;
                }
                return 'Enter a valid email (e.g. distributor@demo.com)';
              },
            ),

            const SizedBox(height: MediLoopSpacing.md),

            // Password
            TextFormField(
              key: const Key('login_password'),
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter your password' : null,
            ),

            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.key_outlined,
                    size: 13, color: MediLoopColors.textSubtle),
                const SizedBox(width: 5),
                Text(
                  'Demo Password: ${AppConstants.demoPassword}',
                  style: MediLoopText.caption.copyWith(
                    fontSize: 11.5,
                    color: MediLoopColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: MediLoopSpacing.md),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MediLoopColors.criticalBg,
                  borderRadius: BorderRadius.circular(MediLoopRadius.badge),
                  border: Border.all(
                    color: MediLoopColors.critical.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: MediLoopColors.critical,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: MediLoopText.inter(
                          size: 13,
                          color: MediLoopColors.critical,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: MediLoopSpacing.lg),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                key: const Key('login_submit'),
                onPressed: auth.isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MediLoopColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MediLoopRadius.button),
                  ),
                  elevation: 0,
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Sign in to platform',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoSection(AuthService auth) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'ONE-TAP ROLE DEMO ACCESS',
                style: MediLoopText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: MediLoopColors.textMuted,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: MediLoopSpacing.md),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _RoleQuickCard(
              id: 'demo_retailer',
              role: 'Pharmacy',
              subtitle: 'Apollo Pharmacy',
              icon: Icons.local_pharmacy_rounded,
              color: MediLoopColors.accent,
              onTap: auth.isLoading ? null : () => _demoLogin('retailer'),
            ),
            _RoleQuickCard(
              id: 'demo_distributor',
              role: 'Distributor',
              subtitle: 'MedPlus Logistics',
              icon: Icons.local_shipping_rounded,
              color: MediLoopColors.attention,
              onTap: auth.isLoading ? null : () => _demoLogin('distributor'),
            ),
            _RoleQuickCard(
              id: 'demo_manufacturer',
              role: 'Manufacturer',
              subtitle: 'Sun Pharma',
              icon: Icons.factory_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: auth.isLoading ? null : () => _demoLogin('manufacturer'),
            ),
            _RoleQuickCard(
              id: 'demo_facility',
              role: 'Waste Plant',
              subtitle: 'BioClean Facility',
              icon: Icons.delete_sweep_rounded,
              color: MediLoopColors.verified,
              onTap: auth.isLoading ? null : () => _demoLogin('facility'),
            ),
            _RoleQuickCard(
              id: 'demo_admin',
              role: 'Regulator',
              subtitle: 'CDSCO Controller',
              icon: Icons.security_rounded,
              color: MediLoopColors.ink,
              onTap: auth.isLoading ? null : () => _demoLogin('admin'),
            ),
          ],
        ),
        const SizedBox(height: MediLoopSpacing.md),
        Text(
          'Instant logins pre-populated with CDSCO audit trail data',
          style: MediLoopText.caption.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}

class _RoleQuickCard extends StatefulWidget {
  final String id;
  final String role;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _RoleQuickCard({
    required this.id,
    required this.role,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<_RoleQuickCard> createState() => _RoleQuickCardState();
}

class _RoleQuickCardState extends State<_RoleQuickCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key(widget.id),
          onHighlightChanged: (val) => setState(() => _isPressed = val),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 130,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: MediLoopColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MediLoopColors.line, width: 1),
              boxShadow: MediLoopShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(widget.icon, size: 16, color: widget.color),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: MediLoopColors.textSubtle,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.role,
                  style: MediLoopText.inter(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: MediLoopColors.ink,
                  ),
                ),
                Text(
                  widget.subtitle,
                  style: MediLoopText.caption.copyWith(fontSize: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Profile Page ──────────────────────────────────────────────────────────

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MediLoopRadius.card),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: MediLoopColors.critical, size: 22),
            SizedBox(width: 10),
            Text('Sign Out of MediLoop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out from your active session? You will be redirected to the secure sign-in portal.',
          style: TextStyle(fontSize: 14, color: MediLoopColors.textMuted),
        ),
        actions: [
          TextButton(
            key: const Key('logout_cancel_button'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: MediLoopColors.ink)),
          ),
          ElevatedButton(
            key: const Key('logout_confirm_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MediLoopColors.critical,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MediLoopRadius.button),
              ),
            ),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signing out of MediLoop...'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      await context.read<AuthService>().logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: MediLoopColors.paper,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            key: const Key('profile_appbar_logout_button'),
            icon: const Icon(Icons.logout_rounded, color: MediLoopColors.critical),
            tooltip: 'Sign Out',
            onPressed: () => _confirmAndLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(MediLoopSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Card
            Container(
              decoration: BoxDecoration(
                color: MediLoopColors.surface,
                borderRadius: BorderRadius.circular(MediLoopRadius.card),
                border: Border.all(color: MediLoopColors.line),
                boxShadow: MediLoopShadows.card,
              ),
              padding: const EdgeInsets.all(MediLoopSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: MediLoopColors.ink,
                        child: Text(
                          (user?.name.isNotEmpty ?? false)
                              ? user!.name[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? '—', style: MediLoopText.h3),
                            const SizedBox(height: 2),
                            Text(user?.email ?? '—', style: MediLoopText.bodyMuted),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Assigned Role', style: MediLoopText.labelMuted),
                      RoleTag(type: user?.role.toUpperCase() ?? 'USER'),
                    ],
                  ),
                  if (user?.organizationName != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Licensed Entity', style: MediLoopText.labelMuted),
                        Expanded(
                          child: Text(
                            user!.organizationName!,
                            textAlign: TextAlign.end,
                            style: MediLoopText.inter(
                              size: 13,
                              weight: FontWeight.w600,
                              color: MediLoopColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'CDSCO Compliance Status',
                          style: MediLoopText.labelMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: MediLoopColors.verifiedBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: MediLoopColors.verified.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 12,
                              color: MediLoopColors.verified,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'VERIFIED ENTITY',
                              style: MediLoopText.inter(
                                size: 10.5,
                                weight: FontWeight.w700,
                                color: MediLoopColors.verified,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MediLoopSpacing.lg),

            // Security & CDSCO Audit Ledger Card
            Container(
              decoration: BoxDecoration(
                color: MediLoopColors.surface,
                borderRadius: BorderRadius.circular(MediLoopRadius.card),
                border: Border.all(color: MediLoopColors.line),
              ),
              padding: const EdgeInsets.all(MediLoopSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Session & Compliance Security', style: MediLoopText.labelMuted),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, size: 18, color: MediLoopColors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your handoffs and reverse-logistics events are secured via SHA-256 cryptographic chaining under Indian CDSCO 2025 guidelines.',
                          style: MediLoopText.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: MediLoopSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('logout_button'),
                onPressed: () => _confirmAndLogout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MediLoopColors.critical,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MediLoopRadius.button),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Sign out of MediLoop',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
