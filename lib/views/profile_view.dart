import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/auth_service.dart';
import '../services/user_preferences_service.dart';
import '../services/database_service.dart';
import '../services/territory_service.dart';

import '../controllers/map/run_tracker_controller.dart';
import '../views/profile/run_history_page.dart';
import '../views/profile/user_stats_page.dart';
import 'profile/notifications_page.dart';
import 'store/store_view.dart';
// import '../routes/app_routes.dart';
// import '../controllers/auth/auth_controller.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _nameController = TextEditingController();
  UserPreferencesService? _prefs;
  bool _isInitialized = false;
  bool _isNameDirty = false;
  bool _isSavingName = false;
  // Removed Add Password feature from Profile view
  
  // Predefined color options (aligned with setup page)
  final List<Color> _colorOptions = [
    const Color(0xFF2196F3), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFF9800), // Orange
    const Color(0xFFE91E63), // Pink
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFF44336), // Red
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFFFFEB3B), // Yellow
  ];

  @override
  void initState() {
    super.initState();
    _initializePreferences();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initializePreferences() async {
    try {
      _prefs = Get.find<UserPreferencesService>();
    } catch (e) {
      _prefs = await Get.putAsync(() => UserPreferencesService().init());
    }

    if (_prefs != null) {
      _nameController.text = _prefs!.username.value;
      
      setState(() {
        _isInitialized = true;
        _isNameDirty = false;
      });
    }
  }

  

  void _onNameChanged() {
    if (_prefs == null) return;
    final current = _nameController.text.trim();
    final stored = _prefs!.username.value.trim();
    final dirty = current != stored;
    if (dirty != _isNameDirty) {
      setState(() {
        _isNameDirty = dirty;
      });
    }
  }

  Future<void> _saveUsername() async {
    if (_prefs == null) return;
    final text = _nameController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }
  // Basic format validation
  final isValid = RegExp(r'^[A-Za-z0-9_.-]{3,20}$').hasMatch(text);
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use 3-20 chars: letters, numbers, _ . -')),
      );
      return;
    }
    try {
      setState(() {
        _isSavingName = true;
      });
      // Check availability case-insensitively
      try {
        final db = Get.find<DatabaseService>();
        final taken = await db.isDisplayNameTaken(text);
        if (taken) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username already taken')),
          );
          return;
        }
      } catch (_) {
        // Continue; server-side unique index will still enforce
      }

      await _prefs!.setUsername(text);
      setState(() {
        _isNameDirty = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated')),
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('username_taken')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username already taken')),
        );
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update username: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
      }
    }
  }

  void _refreshProfile() async {
    if (_prefs == null) return;
    
    try {
      print('🔄 Refreshing profile from cloud...');
      await _prefs!.forceRefreshProfile();
      
      // Profile refreshed successfully - UI will update automatically
      
      // Update the UI
      setState(() {});
    } catch (e) {
      print('❌ Error refreshing profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh profile: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }



  void _showCustomColorPicker() {
    if (_prefs == null) return;
    
    Color tempColor = _prefs!.userColor.value; // Store temporary color
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Pick a custom color',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (color) {
                tempColor = color; // Update temporary color
                setDialogState(() {}); // Update dialog UI
              },
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsl,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _changeUserColor(tempColor);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'Apply',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle user color change with confirmation dialog
  Future<void> _changeUserColor(Color selectedColor) async {
    if (_prefs == null) return;
    
    // Check if color actually changed
    if (selectedColor == _prefs!.userColor.value) {
      print('🎨 Color unchanged, skipping update');
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Change Territory Color',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(children: [
          const Text(
            "This will change the color of all your territories on the map. Continue?",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 5),
          const Text(
            "Restarting the app may be required to see changes.",
            style: TextStyle(color: Colors.white70, fontSize: 10,fontStyle: FontStyle.italic),
          )
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text(
              'Change Color',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Update user color in preferences and database
      await _prefs!.setUserColor(selectedColor);
      
      // Update all territory colors in database
      final databaseService = Get.find<DatabaseService>();
      String colorHex = '#${selectedColor.value.toRadixString(16).toUpperCase()}';
      await databaseService.updateAllTerritoryColors(colorHex);
      
      // Update run tracker color if available
      try {
        final runTracker = Get.find<RunTrackerController>();
        runTracker.refreshUserColor();
      } catch (e) {
        print('Could not update run tracker color: $e');
      }
      
      // Refresh territory service to update frontend
      try {
        final territoryService = Get.find<TerritoryService>();
        await territoryService.refreshNearbyTerritories();
        await territoryService.fetchUserTerritories();
      } catch (e) {
        print('Could not refresh territory service: $e');
      }
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Trigger UI rebuild
      setState(() {});
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Territory color updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update color: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    // Show loading while initializing
    if (!_isInitialized || _prefs == null) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'You are not signed in.',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/signin'),
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _refreshProfile(),
              child: ListView(
                padding: const EdgeInsets.all(10.0),
                children: [
                  _buildProfileHeader(user.email),
                  const SizedBox(height: 20),
                  _buildStoreButton(),
                  const SizedBox(height: 5),
                  _buildQuickActionsList(),
                  const SizedBox(height: 5),
                  _buildUsernameField(),
                  const SizedBox(height: 5),
                  _buildColorSelector(),
                  const SizedBox(height: 20),
                  // Profile sync card removed
                  _buildSignOutButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(String? email) {
    return Obx(() {
      final color = _prefs!.userColor.value;
      final username = _prefs!.username.value.isNotEmpty ? _prefs!.username.value : 'Set your username';
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: color,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Coins display
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: Colors.amber[400],
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Obx(() => Text(
                        '${_prefs!.userCoins.value} Coins',
                        style: TextStyle(
                          color: Colors.amber[400],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildUsernameField() {
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Username',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter your username',
                      hintStyle: const TextStyle(color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: _isSavingName
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                        )
                      : FilledButton.icon(
                          onPressed: _isNameDirty ? _saveUsername : null,
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Removed Profile sync card per request

  Widget _buildColorSelector() {
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This color represents you on the map.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Color options display
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Predefined color options
                ..._colorOptions.map((color) => GestureDetector(
                  onTap: () {
                    _changeUserColor(color);
                  },
                  child: Obx(() => Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12), // Square with curved corners
                      boxShadow: [
                        if (_prefs!.userColor.value == color)
                          BoxShadow(
                            color: color.withOpacity(0.7),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 0),
                          ),
                      ],
                      border: Border.all(
                        color: _prefs!.userColor.value == color 
                            ? Colors.white 
                            : Colors.grey[600]!,
                        width: _prefs!.userColor.value == color ? 3 : 2,
                      ),
                    ),
                    child: _prefs!.userColor.value == color 
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  )),
                )),
                // Custom color option (last icon)
                GestureDetector(
                  onTap: _showCustomColorPicker,
                  child: Obx(() {
                    final isCustomColor = !_colorOptions.contains(_prefs!.userColor.value);
                    return Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isCustomColor ? _prefs!.userColor.value : Colors.grey[700],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCustomColor ? Colors.white : Colors.grey[600]!,
                          width: isCustomColor ? 3 : 2,
                        ),
                      ),
                      child: Icon(
                        Icons.palette,
                        color: isCustomColor ? Colors.white : Colors.grey[400],
                        size: 20,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreButton() {
    return _ActionTile(
      color: Colors.orange,
      icon: Icons.shopping_bag,
      title: 'Store',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StoreView(),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsList() {
    return Column(
      children: [
        _ActionTile(
          color: Colors.blue,
          icon: Icons.history,
          title: 'Territory History',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TerritoryHistoryPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        _ActionTile(
          color: Colors.green,
          icon: Icons.analytics,
          title: 'User Stats',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserStatsPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        _ActionTile(
          color: Colors.amber,
          icon: Icons.notifications,
          title: 'Notifications',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsPage(),
              ),
            );
          },
        ),
  // Removed Add Password action from Profile view
      ],
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: 100,
      child: ElevatedButton(
        onPressed: () async {
          await AuthService().signOut();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/signin');
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('Sign Out'),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}
