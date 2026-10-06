import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../../services/user_preferences_service.dart';
import '../../services/location_service.dart';
import '../../controllers/map/map_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppIntroPage extends StatefulWidget {
  const AppIntroPage({super.key});

  @override
  State<AppIntroPage> createState() => _AppIntroPageState();
}

class _AppIntroPageState extends State<AppIntroPage> with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _backgroundController;
  late AnimationController _polygonController;
  int _currentPageIndex = 0;
  late MapController _mapController;

  // Updated locations: Tokyo -> Paris -> Spain (Madrid)
  final List<_MapTarget> _mapTargets = const [
    // Tokyo Tower
    _MapTarget(latitude: 35.6586, longitude: 139.7454, zoom: 16.5, pitch: 30.0, bearing: -20.0),
    // Paris (Eiffel Tower)
    _MapTarget(latitude: 48.8584, longitude: 2.2945, zoom: 16.5, pitch: 30.0, bearing: -25.0),
    // Spain (Madrid, Plaza Mayor)
    _MapTarget(latitude: 40.4154, longitude: -3.7074, zoom: 16.0, pitch: 30.0, bearing: -10.0),
  ];

  final List<_IntroConfig> _pages = const [
    _IntroConfig(
      title: 'Create territory',
      subtitle: 'Start by outlining your zone to establish your first territory.',
      color: Colors.greenAccent,
      sides: 6,
      wobbleEven: 1.05,
      wobbleOdd: 0.95,
      rotation: 0.0,
      polygonScale: 0.9, // Added polygonScale for first slide
    ),
    _IntroConfig(
      title: 'Conquer territories',
      subtitle: 'Expand your domain by overtaking nearby zones.',
      color: Colors.orange,
      sides: 9,
      wobbleEven: 1.20,
      wobbleOdd: 0.85,
      rotation: 0.0,
      secondaryColor: Colors.cyan,
      polygonScale: 0.75, // Increased from 0.65 to make polygons larger
    ),
    _IntroConfig(
      title: 'Merge your land',
      subtitle: 'Connect zones to form powerful regions and grow faster.',
      color: Colors.cyan,
      sides: 6,
      wobbleEven: 1.01,
      wobbleOdd: 0.99,
      rotation: 0.5235987755982988, // ~pi/6
      polygonScale: 1.0, // Added polygonScale for third slide
    ),
  ];

  bool _showPolygon = false;

  @override
  void initState() {
    super.initState();
    // Ensure map and location services exist before creating MapWidget
    if (!Get.isRegistered<LocationService>()) {
      Get.put(LocationService());
    }
    if (!Get.isRegistered<MapController>()) {
      _mapController = Get.put(MapController(), permanent: true);
    } else {
      _mapController = Get.find<MapController>();
    }
    _pageController = PageController();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _polygonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    
    // Add safety check for animation controller
    _polygonController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Ensure controller doesn't exceed bounds
        if (_polygonController.value > 1.0) {
          _polygonController.value = 1.0;
        }
      }
    });
    
    // Delay polygon appearance for 1.5 seconds on first load
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showPolygon = true;
        });
        _polygonController
          ..reset()
          ..forward();
      }
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _polygonController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeIntro() async {
    try {
      print('🔍 Completing intro and setting first launch as completed...');
      
      final prefs = Get.find<UserPreferencesService>();
      await prefs.setFirstLaunchCompleted();
      
      // Also clear the first launch flag from SharedPreferences directly
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isFirstLaunch', false);
        print('✅ First launch flag cleared from SharedPreferences');
      } catch (e) {
        print('⚠️ Error clearing first launch flag from SharedPreferences: $e');
      }
      
      // Verify the flag was set correctly
      print('🔍 Verifying first launch flag after completion...');
      print('  - isFirstLaunch: ${prefs.isFirstLaunch.value}');
      print('  - hasCompletedSetup: ${prefs.hasCompletedSetup}');
      
      print('✅ Intro completed, requesting location permission...');
      
      // Request location permission before navigating to signin
      await _requestLocationPermission();
      
      print('✅ Intro completed, navigating to signin...');
      Get.offAllNamed('/signin');
    } catch (_) {
      print('⚠️ Error with UserPreferencesService, initializing and retrying...');
      final prefs = await Get.putAsync(() => UserPreferencesService().init());
      await prefs.setFirstLaunchCompleted();
      
      // Verify again
      print('🔍 Verifying first launch flag after retry...');
      print('  - isFirstLaunch: ${prefs.isFirstLaunch.value}');
      print('  - hasCompletedSetup: ${prefs.hasCompletedSetup}');
      
      print('✅ Intro completed (retry), requesting location permission...');
      
      // Request location permission before navigating to signin
      await _requestLocationPermission();
      
      print('✅ Intro completed (retry), navigating to signin...');
      Get.offAllNamed('/signin');
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      print('🔍 Requesting location permission from app intro...');
      
      // Get the location service
      final locationService = Get.find<LocationService>();
      
      // Request location permission
      final hasPermission = await locationService.requestLocationPermission();
      
      if (hasPermission) {
        print('✅ Location permission granted during app intro');
      } else {
        print('⚠️ Location permission not granted during app intro');
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

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
      _showPolygon = false;
    });

    // Fly to the new map location first
    _flyToPage(index);

    // Delay polygon animation until map transition completes
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _currentPageIndex == index) {
        setState(() {
          _showPolygon = true;
        });
        // Reset and start polygon animation
        _polygonController
          ..reset()
          ..forward();
      }
    });
  }

  Future<void> _flyToPage(int index) async {
    if (_mapController.mapboxMap == null) return;
    final t = _mapTargets[index];
    await _mapController.animateTo(
      latitude: t.latitude,
      longitude: t.longitude,
      zoom: t.zoom,
      pitch: t.pitch,
      bearing: t.bearing,
      duration: const Duration(milliseconds: 1400),
    );
  }

  void _onIntroMapCreated(mapbox.MapboxMap map) {
    // Disable auto-centering to user for intro
    _mapController.autoCenterOnLocation = false;
    _mapController.onMapCreated(map);
    // Ensure we start at the first slide's target shortly after style setup
    Future.delayed(const Duration(milliseconds: 300), () => _flyToPage(0));
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _pages[_currentPageIndex].color;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: Stack(
        children: [
          // Map background
          Positioned.fill(
            child: mapbox.MapWidget(
              key: const ValueKey('intro_map'),
              cameraOptions: mapbox.CameraOptions(
                center: mapbox.Point(coordinates: mapbox.Position.named(
                  lng: _mapTargets[0].longitude,
                  lat: _mapTargets[0].latitude,
                )),
                zoom: _mapTargets[0].zoom,
                bearing: _mapTargets[0].bearing,
                pitch: _mapTargets[0].pitch,
              ),
              styleUri: _mapController.initialMapStyle,
              textureView: true,
              onMapCreated: _onIntroMapCreated,
            ),
          ),
          // Animated grid background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, _) => CustomPaint(
                painter: _GridBackgroundPainter(
                  scrollProgress: _backgroundController.value,
                  accentColor: themeColor,
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: ConstrainedBox( // Add constraints to prevent overflow
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9, // Limit height to 90% of screen
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Prevent column from expanding too much
                  children: [
                  // Removed top scrim to avoid pushing content down
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: themeColor.withOpacity(0.35)),
                        ),
                        child: Icon(Icons.grid_view_rounded, color: themeColor),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Trackt',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _completeIntro,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Pages
                  Expanded(
                    child: ConstrainedBox( // Add constraints to prevent overflow
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.6, // Limit height to 60% of screen
                      ),
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          // Only show polygon after 1.5s delay
                          return SingleChildScrollView( // Add scroll view to prevent overflow
                            physics: const NeverScrollableScrollPhysics(), // Disable scrolling to prevent conflicts
                            child: ConstrainedBox( // Add constraints to prevent overflow
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.7, // Limit height to 70% of screen
                              ),
                              child: _IntroSlide(
                                title: page.title,
                                subtitle: page.subtitle,
                                color: page.color,
                                controller: _polygonController,
                                sides: page.sides,
                                wobbleEven: page.wobbleEven,
                                wobbleOdd: page.wobbleOdd,
                                rotation: page.rotation,
                                secondaryColor: index == 1 ? (page.secondaryColor ?? Colors.cyan) : null,
                                polygonScale: page.polygonScale, // Use the scale from config instead of hardcoded values
                                showPolygon: _showPolygon,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Indicators and action
                  Row(
                    children: [
                      Row(
                        children: List.generate(_pages.length, (i) {
                          final isActive = i == _currentPageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 18 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? themeColor : Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          if (_currentPageIndex < _pages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOut,
                            );
                          } else {
                            _completeIntro();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Text(_currentPageIndex == _pages.length - 1 ? 'Get Started' : 'Next',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          )
        ],
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final AnimationController controller;
  final int sides;
  final double wobbleEven;
  final double wobbleOdd;
  final double rotation;
  final Color? secondaryColor;
  final double polygonScale;
  final bool showPolygon;

  const _IntroSlide({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.controller,
    required this.sides,
    required this.wobbleEven,
    required this.wobbleOdd,
    required this.rotation,
    this.secondaryColor,
    this.polygonScale = 1.0,
    this.showPolygon = true,
  });

  @override
  Widget build(BuildContext context) {
    // For the second slide (Conquer territories), use smaller height and move polygon up
    final bool isSecondSlide = title == 'Conquer territories';
    final double polygonHeight = isSecondSlide ? 320.0 : 320.0; // Increased height for second slide to accommodate larger polygon
    
    // Add safety check for polygon scale
    final double safePolygonScale = polygonScale.isInfinite || polygonScale.isNaN || polygonScale <= 0 
        ? 1.0 
        : polygonScale.clamp(0.1, 2.0); // Clamp scale to reasonable bounds
    
    // Add safety check for polygon height
    final double safePolygonHeight = polygonHeight.isInfinite || polygonHeight.isNaN || polygonHeight <= 0
        ? 320.0
        : polygonHeight.clamp(100.0, 400.0); // Clamp height to reasonable bounds
    
    // Debug information
    if (isSecondSlide) {
      print('🔍 Second slide polygon: height=$safePolygonHeight, scale=$safePolygonScale (original: $polygonScale)');
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
      children: [
        if (showPolygon)
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              // Add safety check for controller value
              if (controller.value.isInfinite || controller.value.isNaN) {
                return SizedBox(
                  width: 320,
                  height: safePolygonHeight,
                );
              }
              
              final primaryProgress = Curves.easeOutCubic.transform(controller.value);
              
              // Add safety check for progress value
              if (primaryProgress.isInfinite || primaryProgress.isNaN || primaryProgress < 0 || primaryProgress > 1) {
                return SizedBox(
                  width: 320,
                  height: safePolygonHeight,
                );
              }
              
              return SizedBox(
                width: 320,
                height: safePolygonHeight,
                child: Stack(
                  children: [
                    if (secondaryColor != null)
                      CustomPaint(
                        size: Size(320, safePolygonHeight),
                        painter: _PolygonPainter(
                          progress: 0.95,
                          fillColor: secondaryColor!.withOpacity(0.8),
                          strokeColor: Colors.white.withOpacity(0.6),
                          sides: sides,
                          wobbleEven: wobbleEven,
                          wobbleOdd: wobbleOdd,
                          rotation: rotation + 0.35,
                          centerOffset: Offset(34, 12) * safePolygonScale,
                          radiusScale: 0.92 * safePolygonScale,
                        ),
                      ),
                    CustomPaint(
                      size: Size(320, safePolygonHeight),
                      painter: _PolygonPainter(
                        progress: primaryProgress,
                        fillColor: color.withOpacity(0.85),
                        strokeColor: Colors.white.withOpacity(0.9),
                        sides: sides,
                        wobbleEven: wobbleEven,
                        wobbleOdd: wobbleOdd,
                        rotation: rotation,
                        radiusScale: safePolygonScale,
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        else
          SizedBox(
            width: 320,
            height: safePolygonHeight,
          ),
        SizedBox(height: isSecondSlide ? 20 : 18), // Reduced spacing for second slide
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 3)),
              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
        ),
        SizedBox(height: isSecondSlide ? 10 : 10), // Keep consistent spacing
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isSecondSlide ? 14 : 12), // Reduced padding for second slide
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSecondSlide ? 15 : 16, // Keep smaller font for second slide
              height: 1.3, // Reduced line height to prevent overflow
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
                Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
        // Add minimal bottom margin for second slide
        if (isSecondSlide) const SizedBox(height: 10),
      ],
    );
  }
}

class _IntroConfig {
  final String title;
  final String subtitle;
  final Color color;
  const _IntroConfig({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.sides,
    required this.wobbleEven,
    required this.wobbleOdd,
    required this.rotation,
    this.secondaryColor,
    this.polygonScale = 1.0,
  });
  final int sides;
  final double wobbleEven;
  final double wobbleOdd;
  final double rotation;
  final Color? secondaryColor;
  final double polygonScale;
}

class _MapTarget {
  final double latitude;
  final double longitude;
  final double zoom;
  final double pitch;
  final double bearing;
  const _MapTarget({
    required this.latitude,
    required this.longitude,
    this.zoom = 12.0,
    this.pitch = 0.0,
    this.bearing = 0.0,
  });
}

class _GridBackgroundPainter extends CustomPainter {
  final double scrollProgress; // 0..1
  final Color accentColor;

  _GridBackgroundPainter({
    required this.scrollProgress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Don't paint a solid background; let the map show through
    final spacing = 36.0;
    final offset = scrollProgress * spacing;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;

    // Diagonal scroll effect
    final dx = offset;
    final dy = -offset * 0.7;

    for (double x = -spacing * 2 + dx; x < size.width + spacing * 2; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = -spacing * 2 + dy; y < size.height + spacing * 2; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Subtle glow at center
    final center = size.center(Offset.zero);
    final radial = Paint()
      ..shader = RadialGradient(
        colors: [accentColor.withOpacity(0.12), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.shortestSide * 0.6));
    canvas.drawCircle(center, size.shortestSide * 0.6, radial);
  }

  @override
  bool shouldRepaint(covariant _GridBackgroundPainter oldDelegate) {
    return oldDelegate.scrollProgress != scrollProgress || oldDelegate.accentColor != accentColor;
  }
}

class _PolygonPainter extends CustomPainter {
  final double progress; // 0..1
  final Color fillColor;
  final Color strokeColor;
  final int sides;
  final double wobbleEven;
  final double wobbleOdd;
  final double rotation;
  final Offset centerOffset;
  final double radiusScale;

  _PolygonPainter({
    required this.progress,
    required this.fillColor,
    required this.strokeColor,
    required this.sides,
    required this.wobbleEven,
    required this.wobbleOdd,
    required this.rotation,
    this.centerOffset = Offset.zero,
    this.radiusScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Add safety checks to prevent overflow
    if (size.width <= 0 || size.height <= 0) return;
    
    final center = Offset(size.width / 2, size.height / 2) + centerOffset;

    // Base and max radius for expansion with safety limits
    final minRadius = size.shortestSide * 0.08;
    final maxRadius = size.shortestSide * 0.42;
    final radius = lerpDouble(minRadius, maxRadius, progress)! * radiusScale;
    
    // Add safety check for radius
    if (radius <= 0 || radius.isInfinite || radius.isNaN) return;

    // Create an irregular polygon to feel like territory borders
    final Path path = Path();
    for (int i = 0; i < sides; i++) {
      final t = i / sides;
      final angle = t * 6.283185307179586 + rotation; // 2*pi + rotation
      // Blend wobble in over time so early frames are smoother
      final wobbleBlend = Curves.easeOut.transform(progress);
      final wobbleBase = i.isEven ? wobbleEven : wobbleOdd;
      final wobble = lerpDouble(1.0, wobbleBase, wobbleBlend)! * (1.0 + 0.06 * (progress - 0.5));
      final r = radius * wobble;
      
      // Add safety check for point coordinates
      if (r.isInfinite || r.isNaN) continue;
      
      final point = center + Offset(r * math.cos(angle), r * math.sin(angle));
      
      // Add bounds checking
      if (point.dx.isInfinite || point.dx.isNaN || 
          point.dy.isInfinite || point.dy.isNaN) {
        continue;
      }
      
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    // Fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Stroke with slight dash accent
    final strokePaint = Paint()
      ..color = strokeColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(path, strokePaint);

    // Inner grid-like lines with safety checks
    final innerPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final metrics = path.computeMetrics();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final inner = metric.length;
    
    // Add safety check for inner length
    if (inner.isInfinite || inner.isNaN || inner <= 0) return;
    
    for (double d = 0; d < inner; d += 18) {
      final tangent = metric.getTangentForOffset(d);
      if (tangent == null) continue;
      final p = tangent.position;
      
      // Add bounds checking for inner lines
      if (p.dx.isInfinite || p.dx.isNaN || 
          p.dy.isInfinite || p.dy.isNaN ||
          center.dx.isInfinite || center.dx.isNaN || 
          center.dy.isInfinite || center.dy.isNaN) {
        continue;
      }
      
      canvas.drawLine(p, center, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeColor != strokeColor;
  }
}

// Minimal lerp helper to avoid extra imports
double? lerpDouble(num a, num b, double t) => a + (b - a) * t;
