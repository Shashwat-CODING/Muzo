import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:muzo/models/user_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      final user = await api.getProfile();
      setState(() {
        _user = user;
        _usernameController.text = user.username;
        _emailController.text = user.email;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both password fields')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    if (_user == null && _isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          children: [
            // Avatar + Name header
            _buildAvatarHeader(isDark),
            const SizedBox(height: 32),

            // Personal Info card
            _buildCard(
              cardColor: cardColor,
              borderColor: borderColor,
              title: 'Personal Info',
              icon: FluentIcons.person_24_regular,
              children: [
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
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.black : Colors.white))
                        : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Security card
            if (_user?.hasPassword ?? false)
              _buildCard(
                cardColor: cardColor,
                borderColor: borderColor,
                title: 'Security',
                icon: FluentIcons.shield_24_regular,
                children: [
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
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Logout
            TextButton.icon(
              onPressed: () async {
                final storage = ref.read(storageServiceProvider);
                await storage.clearUserSession();
                if (mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          ],
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    FluentIcons.camera_24_filled,
                    color: isDark ? Colors.black : Colors.white,
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
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _user?.email ?? '',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required Color cardColor,
    required Color borderColor,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
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
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
