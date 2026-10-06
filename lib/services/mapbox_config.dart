import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapboxConfig {
  static String get accessToken {
    try {
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
      print('Retrieved token: ${token?.substring(0, 20) ?? 'null'}...');
      
      if (token == null || token.isEmpty || token == 'YOUR_MAPBOX_TOKEN_HERE') {
        throw Exception(
          'Mapbox access token not found. Please add MAPBOX_ACCESS_TOKEN to your .env file.'
        );
      }
      return token;
    } catch (e) {
      print('Error getting Mapbox token: $e');
      rethrow;
    }
  }

  /// Map style URI to use across the app. Falls back to Mapbox Outdoors if not set.
  static String get styleUri {
    try {
      final uri = dotenv.env['MAPBOX_STYLE_URI'];
      if (uri == null || uri.isEmpty) {
        // Default to a safe built-in style if not provided
        return 'mapbox://styles/mapbox/outdoors-v12';
      }
      return uri;
    } catch (e) {
      print('Error getting Mapbox style URI: $e');
      return 'mapbox://styles/mapbox/outdoors-v12';
    }
  }

  static bool get isConfigured {
    try {
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
      final isValid = token != null && 
             token.isNotEmpty && 
             token != 'YOUR_MAPBOX_TOKEN_HERE' &&
             token.startsWith('pk.');
      final style = dotenv.env['MAPBOX_STYLE_URI'];
      print('Mapbox style configured: ${style != null && style.isNotEmpty}');
      
      print('Mapbox configuration check: $isValid');
      print('Token exists: ${token != null}');
      print('Token not empty: ${token?.isNotEmpty ?? false}');
      print('Token starts with pk.: ${token?.startsWith('pk.') ?? false}');
      
      return isValid;
    } catch (e) {
      print('Error checking Mapbox config: $e');
      return false;
    }
  }

  static void validateToken() {
    if (!isConfigured) {
      throw Exception(
        'Invalid Mapbox configuration. Please ensure MAPBOX_ACCESS_TOKEN is set with a valid public token (starts with "pk.")'
      );
    }
  }
}
