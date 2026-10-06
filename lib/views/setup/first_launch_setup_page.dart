import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/user_preferences_service.dart';
import '../../services/database_service.dart';
import '../../controllers/map/run_tracker_controller.dart';
import '../../services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirstLaunchSetupPage extends StatefulWidget {
  const FirstLaunchSetupPage({super.key});

  @override
  State<FirstLaunchSetupPage> createState() => _FirstLaunchSetupPageState();
}

class _FirstLaunchSetupPageState extends State<FirstLaunchSetupPage> {
  late UserPreferencesService _prefs;
  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;

  // Predefined color options
  final List<Color> _predefinedColors = [
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
  }

  Future<void> _initializePreferences() async {
    try {
      _prefs = Get.find<UserPreferencesService>();
    } catch (e) {
      _prefs = await Get.putAsync(() => UserPreferencesService().init());
    }
    
    // Check if user already has a profile in Supabase
    try {
      final databaseService = Get.find<DatabaseService>();
      final profile = await databaseService.getUserProfile();
      
      if (profile != null && 
          profile['display_name'] != null && 
          (profile['display_name'] as String).isNotEmpty) {
        // User already has a profile, skip setup and go to home
        print('✅ User already has profile, skipping setup');
        Get.offAllNamed('/home');
        return;
      }
    } catch (e) {
      print('⚠️ Error checking existing profile: $e');
      // Continue with setup if there's an error
    }
    
    _nameController.text = _prefs.username.value;
    _selectedColor = _prefs.userColor.value;
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Choose your color',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Predefined colors grid
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _predefinedColors.length + 1, // +1 for custom color option
                itemBuilder: (context, index) {
                  if (index == _predefinedColors.length) {
                    // Custom color picker option
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop(); // Close the color options dialog first
                        _showCustomColorPicker();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade600,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade600.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.palette,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  }

                  final color = _predefinedColors[index];
                  final isSelected = _selectedColor.value == color.value;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: isSelected ? 12 : 6,
                            spreadRadius: isSelected ? 3 : 1,
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomColorPicker() {
  print('Debug: _showCustomColorPicker called');

  Color tempColor = _selectedColor; // <-- now outside builder

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Pick custom color',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (color) {
                print('Debug: Color changed to: $color');
                setDialogState(() {
                  tempColor = color; // updates live
                });
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsl,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                print('Debug: Apply pressed with color: $tempColor');
                setState(() {
                  _selectedColor = tempColor; // persist selection to main widget
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tempColor,
              ),
              child: const Text(
                'Apply',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    ),
  );
}


  void _completeSetup() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      // Validate username format
      final isValid = RegExp(r'^[A-Za-z0-9_.-]{3,20}$').hasMatch(name);
      if (!isValid) {
        Get.snackbar('Invalid Username', 'Use 3-20 chars: letters, numbers, _ . -');
        return;
      }
      try {
        print('🔍 Completing setup...');
        
        // Check uniqueness before saving
        try {
          final db = Get.find<DatabaseService>();
          final taken = await db.isDisplayNameTaken(name);
          if (taken) {
            Get.snackbar('Username Taken', 'Please choose a different username.');
            return;
          }
        } catch (e) {
          print('⚠️ Could not verify username availability: $e');
        }
        
        // Save to local preferences
        _prefs.setUsername(name);
        _prefs.setUserColor(_selectedColor);
        _prefs.setFirstLaunchCompleted();
        
        // Also clear the first launch flag from SharedPreferences directly
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isFirstLaunch', false);
          print('✅ First launch flag cleared from SharedPreferences');
        } catch (e) {
          print('⚠️ Error clearing first launch flag from SharedPreferences: $e');
        }
        
        // Verify the flags were set correctly
        print('🔍 Verifying setup completion...');
        print('  - Username: ${_prefs.username.value}');
        print('  - isFirstLaunch: ${_prefs.isFirstLaunch.value}');
        print('  - hasCompletedSetup: ${_prefs.hasCompletedSetup}');
        
        // Save username to Supabase user metadata
    await Supabase.instance.client.auth.updateUser(
          UserAttributes(
      data: {'username': name},
          ),
        );
        
        // Create/update user profile in Supabase with color preference
        try {
          final databaseService = DatabaseService();
          String colorHex = '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
          await databaseService.upsertUserProfile(
      displayName: name,
            userColor: colorHex,
          );
          print('✅ User profile created in Supabase with color: $colorHex');
        } catch (e) {
          print('⚠️ Failed to create user profile in Supabase: $e');
          // Continue anyway - user can sync later
        }
        
        // Notify RunTrackerController to refresh color
        try {
          final runController = Get.find<RunTrackerController>();
          runController.refreshUserColor();
          print('🎨 Notified RunTrackerController to refresh color');
        } catch (e) {
          print('⚠️ Could not notify RunTrackerController: $e');
        }
        
        print('✅ Setup completed, requesting location permission...');
        
        // Request location permission before navigating to home
        await _requestLocationPermission();
        
        print('✅ Setup completed, navigating to home...');
        Get.offAllNamed('/home'); // Navigate to main app view
      } catch (e) {
        print('❌ Error completing setup: $e');
        Get.snackbar('Error', 'Failed to save setup: ${e.toString()}');
      }
    } else {
      Get.snackbar('Username Required', 'Please enter a username to continue.');
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      print('🔍 Requesting location permission from first launch setup...');
      
      // Get the location service
      final locationService = Get.find<LocationService>();
      
      // Request location permission
      final hasPermission = await locationService.requestLocationPermission();
      
      if (hasPermission) {
        print('✅ Location permission granted during first launch setup');
      } else {
        print('⚠️ Location permission not granted during first launch setup');
        // Show a helpful message to the user
        Get.snackbar(
          'Location Permission',
          'Location permission is recommended for the best experience. You can enable it later in settings.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('❌ Error requesting location permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.explore_outlined, 
                size: 80, 
                color: Color(0xFF2196F3),
              ),
              const SizedBox(height: 20),
              const Text(
                'Complete Your Profile',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Set up your username and choose your territory color',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Claim your territory. Expand your network.',
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Choose your username',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2196F3)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Color selection card
              Card(
                color: const Color(0xFF1E1E1E),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        'Choose your color',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This color will represent you on the map',
                        style: TextStyle(
                          fontSize: 14, 
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _showColorPicker,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white30, 
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _selectedColor.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: _selectedColor.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.palette, 
                            color: Colors.white, 
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _completeSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                ),
                child: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
