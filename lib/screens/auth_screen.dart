import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/providers/auth_gate_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  // 0 = intro, 1 = auth form
  int _page = 0;

  late TabController _tabController;
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToAuth({int tab = 0}) {
    _tabController.animateTo(tab);
    setState(() => _page = 1);
  }

  void _back() => setState(() => _page = 0);

  void _skip() {
    // Set guest mode — AuthGate will reactively show the main app.
    ref.read(isGuestModeProvider.notifier).state = true;
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleAuth() async {
    if (_isLoading) return;

    final authService = ref.read(authServiceProvider);
    final isLogin = _tabController.index == 0;

    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
          throw Exception('Please fill in all fields');
        }
        await authService.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        if (_usernameController.text.isEmpty ||
            _emailController.text.isEmpty ||
            _passwordController.text.isEmpty) {
          throw Exception('Please fill in all fields');
        }
        await authService.signup(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }

      if (mounted) {
        showGlassSnackBar(context, 'Welcome to Muzo!');
        // AuthGate watches authServiceProvider and will reactively
        // switch to MainLayout+HomeScreen now that auth token is set.
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final primaryColor = Theme.of(context).primaryColor;
    final orbColor1 = isDark
        ? primaryColor.withValues(alpha: 0.08)
        : primaryColor.withValues(alpha: 0.15);
    final orbColor2 = isDark
        ? primaryColor.withValues(alpha: 0.04)
        : primaryColor.withValues(alpha: 0.1);

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        children: [
          // Background decorative orbs
          Positioned(
            top: -120, left: -80,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(
                width: 340, height: 340,
                decoration: BoxDecoration(shape: BoxShape.circle, color: orbColor1),
              ),
            ),
          ),
          Positioned(
            bottom: -80, right: -60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(shape: BoxShape.circle, color: orbColor2),
              ),
            ),
          ),

          // Page content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                begin: _page == 0
                    ? const Offset(-1, 0)
                    : const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
            child: _page == 0
                ? _IntroPage(
                    key: const ValueKey('intro'),
                    onLogin: () => _goToAuth(tab: 0),
                    onSignup: () => _goToAuth(tab: 1),
                    onGuest: _skip,
                    onSurface: onSurface,
                    isDark: isDark,
                  )
                : _AuthPage(
                    key: const ValueKey('auth'),
                    tabController: _tabController,
                    usernameController: _usernameController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    isLoading: _isLoading,
                    obscurePassword: _obscurePassword,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onAuth: _handleAuth,
                    onBack: _back,
                    onSurface: onSurface,
                    isDark: isDark,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INTRO PAGE
// ─────────────────────────────────────────────
class _IntroPage extends ConsumerWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onGuest;
  final Color onSurface;
  final bool isDark;

  const _IntroPage({
    super.key,
    required this.onLogin,
    required this.onSignup,
    required this.onGuest,
    required this.onSurface,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),

            // Logo + wordmark
            Row(
              children: [
                Image.asset('assets/logo.png', width: 52, height: 52),
                const SizedBox(width: 14),
                Text(
                  'Muzo',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Tagline
            Text(
              'Music without\nlimits.',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: onSurface,
                height: 1.1,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stream, discover, and vibe — all in one place. Free, forever.',
              style: TextStyle(
                fontSize: 15,
                color: onSurface.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),

            // Feature pills
            const SizedBox(height: 32),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _pill(context, Icons.music_note_rounded, 'Millions of songs'),
                _pill(context, Icons.lyrics_rounded, 'Live lyrics'),
                _pill(context, Icons.queue_music_rounded, 'Smart queue'),
                _pill(context, Icons.offline_bolt_rounded, 'No ads'),
              ],
            ),

            const Spacer(flex: 3),

            // CTA Buttons
            if (!Platform.isWindows) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final authService = ref.read(authServiceProvider);
                    try {
                      await authService.loginWithGoogle();
                      if (context.mounted) {
                        showGlassSnackBar(context, 'Signed in with Google');
                        // AuthGate watches authServiceProvider and will
                        // reactively switch to MainLayout+HomeScreen.
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showGlassSnackBar(context, e.toString().replaceAll('Exception: ', ''));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    foregroundColor: onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: onSurface.withValues(alpha: 0.15)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/google_logo.svg',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('Continue with Google',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onSignup,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Sign up with Email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: onLogin,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: onSurface.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Log in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    )),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: onGuest,
                child: Text(
                  'Continue as Guest',
                  style: TextStyle(
                    fontSize: 14,
                    color: onSurface.withValues(alpha: 0.45),
                    decoration: TextDecoration.underline,
                    decorationColor: onSurface.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label) {
    final primaryColor = Theme.of(context).primaryColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onSurf.withValues(alpha: 0.85),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AUTH FORM PAGE (Login / Signup tabs)
// ─────────────────────────────────────────────
class _AuthPage extends StatelessWidget {
  final TabController tabController;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onAuth;
  final VoidCallback onBack;
  final Color onSurface;
  final bool isDark;

  const _AuthPage({
    super.key,
    required this.tabController,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onAuth,
    required this.onBack,
    required this.onSurface,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurface, size: 20),
              onPressed: onBack,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Heading
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to your account or create a new one',
                    style: TextStyle(
                      fontSize: 14,
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Tab bar
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: tabController,
                      indicator: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorPadding: const EdgeInsets.all(4),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Theme.of(context).colorScheme.onPrimary,
                      unselectedLabelColor: onSurface.withValues(alpha: 0.5),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      dividerColor: Colors.transparent,
                      tabs: const [Tab(text: 'Log in'), Tab(text: 'Sign up')],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Forms
                  SizedBox(
                    height: 260,
                    child: TabBarView(
                      controller: tabController,
                      children: [
                        // Login tab
                        Column(
                          children: [
                            _buildField(context, controller: emailController,
                                hint: 'Email', icon: FluentIcons.mail_24_regular),
                            const SizedBox(height: 14),
                            _buildField(context, controller: passwordController,
                                hint: 'Password', icon: FluentIcons.lock_closed_24_regular,
                                isPassword: true,
                                obscure: obscurePassword,
                                onToggle: onTogglePassword),
                          ],
                        ),
                        // Signup tab
                        Column(
                          children: [
                            _buildField(context, controller: usernameController,
                                hint: 'Username', icon: FluentIcons.person_24_regular),
                            const SizedBox(height: 14),
                            _buildField(context, controller: emailController,
                                hint: 'Email', icon: FluentIcons.mail_24_regular),
                            const SizedBox(height: 14),
                            _buildField(context, controller: passwordController,
                                hint: 'Password', icon: FluentIcons.lock_closed_24_regular,
                                isPassword: true,
                                obscure: obscurePassword,
                                onToggle: onTogglePassword),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: isLoading
                        ? Center(
                            child: SizedBox(
                              height: 24, width: 24,
                              child: CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor, strokeWidth: 2),
                            ),
                          )
                        : FilledButton(
                            onPressed: onAuth,
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: AnimatedBuilder(
                              animation: tabController,
                              builder: (_, __) => Text(
                                tabController.index == 0 ? 'Log in' : 'Create account',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return TextField(
      controller: controller,
      obscureText: isPassword && obscure,
      style: TextStyle(color: onSurf),
      cursorColor: onSurf,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: onSurf.withValues(alpha: 0.06),
        hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.35)),
        prefixIcon: Icon(icon, color: onSurf.withValues(alpha: 0.45), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? FluentIcons.eye_24_regular
                      : FluentIcons.eye_off_24_regular,
                  color: onSurf.withValues(alpha: 0.4),
                  size: 20,
                ),
                onPressed: onToggle,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: onSurf.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
