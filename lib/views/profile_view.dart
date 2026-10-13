import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/auth/auth_controller.dart';
import '../controllers/map/run_tracker_controller.dart';
import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/power_up_service.dart';
import '../services/territory_service.dart';
import '../services/user_preferences_service.dart';
import 'profile/notifications_page.dart';
import 'profile/run_history_page.dart';
import 'profile/user_stats_page.dart';
import 'store/store_view.dart';

class ProfileView extends StatefulWidget {
  final UserPreferencesService? preferences;
  final User? Function()? currentUser;

  const ProfileView({super.key, this.preferences, this.currentUser});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _name = TextEditingController();
  UserPreferencesService? _prefs;
  bool _ready = false;
  bool _dirty = false;
  bool _saving = false;
  bool _changingColor = false;
  bool _signingOut = false;
  String? _error;
  static const _colors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFF00BCD4),
    Color(0xFFFFEB3B),
  ];
  static const _colorNames = [
    'Blue',
    'Green',
    'Orange',
    'Pink',
    'Purple',
    'Red',
    'Cyan',
    'Yellow',
  ];

  @override
  void initState() {
    super.initState();
    _name.addListener(_nameChanged);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _prefs =
          widget.preferences ??
          (Get.isRegistered<UserPreferencesService>()
              ? Get.find<UserPreferencesService>()
              : await Get.putAsync(() => UserPreferencesService().init()));
      if (!mounted) return;
      _name.text = _prefs!.username.value;
      setState(() {
        _ready = true;
        _dirty = false;
        _error = null;
      });
    } catch (exception) {
      debugPrint('Profile initialization failed: ${exception.runtimeType}');
      if (mounted) {
        setState(() => _error = 'Could not load your profile. Try again.');
      }
    }
  }

  User? get _user {
    if (widget.currentUser != null) return widget.currentUser!();
    if (Get.isRegistered<AuthController>()) {
      return Get.find<AuthController>().user;
    }
    return Supabase.instance.client.auth.currentUser;
  }

  void _nameChanged() {
    if (_prefs == null || !mounted) return;
    final dirty = _name.text.trim() != _prefs!.username.value.trim();
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  void _notify(String text) {
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _saveName() async {
    if (_prefs == null || _saving) return;
    final name = _name.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_.-]{3,20}$').hasMatch(name)) {
      _notify('Use 3-20 characters: letters, numbers, _ . -');
      return;
    }
    setState(() => _saving = true);
    try {
      await _prefs!.setUsername(name);
      if (!mounted) return;
      setState(() => _dirty = false);
      _notify('Username updated');
    } catch (exception) {
      debugPrint('Profile username update failed: ${exception.runtimeType}');
      _notify(
        exception.toString().contains('username_taken')
            ? 'Username already taken'
            : 'Could not save your username. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refresh() async {
    if (_prefs == null) return;
    try {
      await _prefs!.forceRefreshProfile();
      if (!mounted) return;
      if (!_dirty) _name.text = _prefs!.username.value;
      setState(() => _error = null);
    } catch (exception) {
      debugPrint('Profile refresh failed: ${exception.runtimeType}');
      _notify('Could not refresh your profile. Check your connection.');
    }
  }

  bool get _customUnlocked =>
      Get.isRegistered<PowerUpService>() &&
      Get.find<PowerUpService>().isActive('flag');

  Future<void> _customColor() async {
    if (!_customUnlocked) {
      _notify('Unlock custom territory colors with Custom Flag in the Shop.');
      return;
    }
    var selected = _prefs!.userColor.value;
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Custom territory color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: selected,
            onColorChanged: (color) => selected = color,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsl,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (color != null && mounted) await _changeColor(color);
  }

  Future<void> _changeColor(Color color) async {
    if (_changingColor || color == _prefs!.userColor.value) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Change territory color?'),
        content: const Text(
          'This updates the color of your territories on the map.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change color'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _changingColor = true);
    try {
      final database = Get.find<DatabaseService>();
      await database.updateAllTerritoryColors(
        '#${color.toARGB32().toRadixString(16).toUpperCase()}',
      );
      await _prefs!.setUserColor(color);
      if (Get.isRegistered<RunTrackerController>()) {
        Get.find<RunTrackerController>().refreshUserColor();
      }
      if (Get.isRegistered<TerritoryService>()) {
        final territories = Get.find<TerritoryService>();
        await territories.refreshNearbyTerritories();
        await territories.fetchUserTerritories();
      }
      _notify('Territory color updated');
    } catch (exception) {
      debugPrint('Territory color update failed: ${exception.runtimeType}');
      _notify('Could not update every territory. Refresh and try again.');
    } finally {
      if (mounted) setState(() => _changingColor = false);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your saved wallet stays on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      if (Get.isRegistered<AuthController>()) {
        await Get.find<AuthController>().signOut();
      } else {
        await AuthService().signOut();
        if (mounted) Navigator.of(context).pushReplacementNamed('/signin');
      }
    } catch (exception) {
      debugPrint('Profile sign out failed: ${exception.runtimeType}');
      _notify('Could not sign out. Try again.');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: !_ready
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: _initialize,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
            )
          : _user == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Your running profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in to manage your profile and territory history.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/signin'),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 24),
                    _sectionTitle('Activity'),
                    const SizedBox(height: 12),
                    _panel(
                      Column(
                        children: [
                          _action(
                            Icons.history,
                            'Territory history',
                            'Review your claimed areas',
                            () => _open(const TerritoryHistoryPage()),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          _action(
                            Icons.insights_outlined,
                            'Your statistics',
                            'Distance, runs and territory',
                            () => _open(const UserStatsPage()),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          _action(
                            Icons.notifications_outlined,
                            'Notifications',
                            'Stay up to date with your activity',
                            () => _open(const NotificationsPage()),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          _action(
                            Icons.storefront_outlined,
                            'Power-up shop',
                            'Use your in-game coins',
                            () => _open(const StoreView()),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 28),
                    _sectionTitle('Personalize'),
                    const SizedBox(height: 12),
                    _username(),
                    const SizedBox(height: 16),
                    _colorsPanel(),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _signingOut ? null : _signOut,
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(_signingOut ? 'Signing out...' : 'Sign out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _header() => Obx(() {
    final username = _prefs!.username.value;
    final initial = username.trim().isEmpty
        ? '?'
        : username.trim().characters.first.toUpperCase();
    return _panel(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              initial,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username.isEmpty ? 'Your profile' : username,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_user?.email != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _user!.email!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '${_prefs!.userCoins.value} in-game coins',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Shop balance, separate from wallet tokens.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  });

  Widget _username() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Username',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          enabled: !_saving,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (_dirty) _saveName();
          },
          decoration: const InputDecoration(hintText: 'Your username'),
        ),
        const SizedBox(height: 10),
        const Text(
          '3-20 characters. Letters, numbers, _ . -',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _dirty && !_saving ? _saveName : null,
          child: Text(_saving ? 'Saving...' : 'Save username'),
        ),
      ],
    ),
  );

  Widget _colorsPanel() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Territory color',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose how your territories appear on the map.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Obx(() {
          final selected = _prefs!.userColor.value;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < _colors.length; index++)
                Tooltip(
                  message: _colorNames[index],
                  child: Semantics(
                    label: '${_colorNames[index]} territory color',
                    selected: selected == _colors[index],
                    button: true,
                    child: InkWell(
                      onTap: _changingColor
                          ? null
                          : () => _changeColor(_colors[index]),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _colors[index],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected == _colors[index]
                                ? AppColors.textPrimary
                                : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: selected == _colors[index]
                            ? Icon(
                                Icons.check,
                                color: _colors[index].computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _changingColor ? null : _customColor,
          icon: Icon(
            _customUnlocked ? Icons.palette_outlined : Icons.lock_outline,
            size: 18,
          ),
          label: const Text('Custom color'),
        ),
        if (_changingColor)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    ),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _panel(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(16),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    leading: Icon(icon, color: AppColors.textSecondary, size: 20),
    title: Text(
      title,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      color: AppColors.textMuted,
      size: 18,
    ),
    onTap: onTap,
  );

  Future<void> _open(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_nameChanged);
    _name.dispose();
    super.dispose();
  }
}
