import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/widgets/main_layout.dart';
import 'package:muzo/screens/home_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
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
        showGlassSnackBar(context, 'Success! Welcome.');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainLayout(child: const HomeScreen())),
        );
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _skip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainLayout(child: const HomeScreen())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Subtle Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF121212),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Single Sleek Container
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Image.asset('assets/logo.png', width: 100, height: 100),
                        const SizedBox(height: 16),
                        Text(
                          'Muzo',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Tabs
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            indicatorPadding: const EdgeInsets.all(4),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.grey,
                            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Login'),
                              Tab(text: 'Sign Up'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Form Fields
                        SizedBox(
                          height: 200,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Login
                              Column(
                                children: [
                                  _buildTextField(
                                    controller: _emailController,
                                    hint: 'Email',
                                    icon: FluentIcons.mail_24_regular,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _passwordController,
                                    hint: 'Password',
                                    icon: FluentIcons.lock_closed_24_regular,
                                    isPassword: true,
                                  ),
                                ],
                              ),
                              // Signup
                              Column(
                                children: [
                                  _buildTextField(
                                    controller: _usernameController,
                                    hint: 'Username',
                                    icon: FluentIcons.person_24_regular,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _emailController,
                                    hint: 'Email',
                                    icon: FluentIcons.mail_24_regular,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _passwordController,
                                    hint: 'Password',
                                    icon: FluentIcons.lock_closed_24_regular,
                                    isPassword: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action Button
                        if (_isLoading)
                          const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: AnimatedBuilder(
                                animation: _tabController,
                                builder: (context, child) {
                                  return Text(
                                    _tabController.index == 0 ? 'Login' : 'Create Account',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Continue as Guest',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 14,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? FluentIcons.eye_24_regular : FluentIcons.eye_off_24_regular,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
