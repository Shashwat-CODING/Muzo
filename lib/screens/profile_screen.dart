import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzo/models/user_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/providers/auth_gate_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  bool _isLoading = false;
  User? _user;
  Stats? _stats;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(muzoApiServiceProvider);
      final userData = await api.getUserData();
      setState(() {
        _user = userData.user;
        _stats = userData.stats;
        _usernameController.text = userData.user.username;
        _emailController.text = userData.user.email;
      });
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, 'Error loading profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(muzoApiServiceProvider);
      final updatedUser = await api.updateProfile(
        username: _usernameController.text,
        email: _emailController.text,
      );
      
      final storage = ref.read(storageServiceProvider);
      await storage.setUserInfo(updatedUser.username, updatedUser.email, avatarUrl: updatedUser.avatar);
      
      setState(() => _user = updatedUser);
      
      if (mounted) {
        showGlassSnackBar(context, 'Profile updated successfully');
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      showGlassSnackBar(context, 'Please fill in both password fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(muzoApiServiceProvider);
      await api.updateProfile(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      
      _currentPasswordController.clear();
      _newPasswordController.clear();
      
      if (mounted) {
        showGlassSnackBar(context, 'Password changed successfully');
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final api = ref.read(muzoApiServiceProvider);
      final avatarUrl = await api.updateAvatar(image.path);
      
      final storage = ref.read(storageServiceProvider);
      await storage.setUserInfo(_usernameController.text, _emailController.text, avatarUrl: avatarUrl);
      
      await _loadProfile();
      
      if (mounted) {
        showGlassSnackBar(context, 'Avatar updated successfully');
      }
    } catch (e) {
      if (mounted) {
        showGlassSnackBar(context, 'Error uploading avatar: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmClearHistory() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Clear Playback History?'),
        content: const Text('This will delete your playback history from the server and local cache. This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final storage = ref.read(storageServiceProvider);
                await storage.clearHistory();
                if (mounted) {
                  showGlassSnackBar(context, 'Playback history cleared successfully');
                  _loadProfile(); // Refresh stats
                }
              } catch (e) {
                if (mounted) {
                  showGlassSnackBar(context, 'Error clearing history: $e');
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final storage = ref.read(storageServiceProvider);
              await storage.clearUserSession();
              // Reset guest mode so AuthGate returns to AuthScreen.
              ref.read(isGuestModeProvider.notifier).state = false;
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_user == null && _isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Profile'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
          child: Column(
            children: [
              // Avatar + Name header
              _buildAvatarHeader(isDark),
              
              // Stats Grid
              if (_stats != null) ...[
                const SizedBox(height: 24),
                _buildStatsGrid(_stats!),
              ],
              
              const SizedBox(height: 28),
    
              // Personal Info card
              _buildSection(
                'Personal Info',
                [
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: FluentIcons.person_24_regular,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: FluentIcons.mail_24_regular,
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  _buildSaveButton(),
                ],
              ),
              const SizedBox(height: 20),
    
              // Security card
              if (_user?.hasPassword ?? false) ...[
                _buildSection(
                  'Security',
                  [
                    _buildTextField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      icon: FluentIcons.lock_closed_24_regular,
                      isDark: isDark,
                      obscureText: true,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      icon: FluentIcons.lock_closed_24_regular,
                      isDark: isDark,
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    _buildChangePasswordButton(),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Connected Accounts card
              if (_user?.hasGoogle ?? false) ...[
                _buildSection(
                  'Connected Accounts',
                  [
                    Row(
                      children: [
                        const Icon(FluentIcons.connector_24_regular, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Account',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                              ),
                              Text(
                                'Linked with ${_user?.email}',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Connected',
                            style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
 
              // Account Actions Section (Clear History & Logout)
              _buildSection(
                'Account Actions',
                [
                  _buildActionRow(
                    icon: FluentIcons.history_24_regular,
                    title: 'Clear Playback History',
                    color: Colors.redAccent,
                    onTap: _confirmClearHistory,
                  ),
                  Divider(height: 24, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
                  _buildActionRow(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    color: Colors.red,
                    onTap: _logout,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarHeader(bool isDark) {
    final storage = ref.watch(storageServiceProvider);

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: ValueListenableBuilder(
                  valueListenable: storage.userAvatarListenable,
                  builder: (context, box, _) {
                    final avatarUrl = _user?.avatar ?? storage.avatarUrl;
                    final cachedSvg = storage.getUserAvatar();

                    final isSvg = avatarUrl == null || 
                                  avatarUrl.contains('.svg') || 
                                  avatarUrl.contains('dicebear');

                    if (isSvg && cachedSvg != null) {
                      return SvgPicture.string(cachedSvg, fit: BoxFit.cover);
                    }
                    
                    if (avatarUrl != null) {
                      if (isSvg) {
                        return SvgPicture.network(avatarUrl, fit: BoxFit.cover);
                      } else {
                        return CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => const Icon(FluentIcons.person_24_filled, size: 48),
                        );
                      }
                    }
                    return const Icon(FluentIcons.person_24_filled, size: 48);
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickAndUploadAvatar,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  ),
                  child: const Icon(
                    FluentIcons.camera_24_filled,
                    color: Colors.black,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _user?.username ?? 'User',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _user?.email ?? '',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Stats stats) {
    return Row(
      children: [
        Expanded(child: _buildStatItem('Playlists', stats.playlistsCount, FluentIcons.music_note_2_24_regular)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatItem('Favorites', stats.favoritesCount, FluentIcons.heart_24_regular)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatItem('Channels', stats.subscriptionsCount, FluentIcons.person_24_regular)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatItem('History', stats.historyCount, FluentIcons.history_24_regular)),
      ],
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03);
    final cardBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cardBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).primaryColor),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03);
    final cardBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cardBorder,
                  width: 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    final fieldFill = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02);
    final fieldBorder = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
        filled: true,
        fillColor: fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: fieldBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: fieldBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildSaveButton() {
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton(
        onPressed: _isLoading ? null : _updateProfile,
        style: FilledButton.styleFrom(
          backgroundColor: onSurfaceColor,
          foregroundColor: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: _isLoading 
            ? SizedBox(
                height: 18, 
                width: 18, 
                child: CircularProgressIndicator(strokeWidth: 2, color: surfaceColor),
              )
            : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
 
  Widget _buildChangePasswordButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderCol = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _changePassword,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: borderCol),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isLoading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface),
              )
            : const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
