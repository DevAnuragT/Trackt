import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class AiRecap {
  final String message;
  final String model;

  const AiRecap({required this.message, required this.model});
}

class AiRecapException implements Exception {
  final String message;

  const AiRecapException(this.message);

  @override
  String toString() => message;
}

class AiService extends GetxService {
  final String projectUrl;
  final String anonKey;
  final String? Function() accessToken;
  final bool enabled;
  final http.Client _client;

  AiService({
    required this.projectUrl,
    required this.anonKey,
    required this.accessToken,
    this.enabled = true,
    http.Client? client,
  }) : _client = client ?? http.Client();

  bool get isConfigured => projectUrl.isNotEmpty && anonKey.isNotEmpty;
  bool get isSignedIn => accessToken()?.isNotEmpty ?? false;

  Future<AiRecap> conquestRecap({
    required String city,
    required double areaSqMeters,
    required double distanceMeters,
  }) async {
    if (!enabled) {
      throw const AiRecapException('AI recaps are disabled.');
    }
    if (!isConfigured) {
      throw const AiRecapException('AI recaps are not configured.');
    }
    final token = accessToken();
    if (token == null || token.isEmpty) {
      throw const AiRecapException('Sign in to generate a KIMI recap.');
    }
    try {
      final response = await _client
          .post(
            Uri.parse(
              '${projectUrl.replaceFirst(RegExp(r'/+$'), '')}/functions/v1/conquest-ai',
            ),
            headers: {
              'Content-Type': 'application/json',
              'apikey': anonKey,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'city': city,
              'areaSqMeters': areaSqMeters,
              'distanceMeters': distanceMeters,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        debugPrint('KIMI proxy HTTP ${response.statusCode}');
        final data = jsonDecode(response.body);
        final message = data is Map ? data['error'] : null;
        throw AiRecapException(
          message is String
              ? message
              : 'AI recaps are temporarily unavailable.',
        );
      }
      final data = jsonDecode(response.body);
      if (data is! Map ||
          data['source'] != 'kimi' ||
          data['message'] is! String ||
          (data['message'] as String).trim().isEmpty ||
          data['model'] is! String) {
        throw const FormatException('Invalid KIMI recap response');
      }
      return AiRecap(
        message: (data['message'] as String).trim(),
        model: data['model'] as String,
      );
    } on TimeoutException {
      debugPrint('KIMI proxy request timed out');
      throw const AiRecapException(
        'AI recap timed out. Your conquest is saved.',
      );
    } on http.ClientException {
      debugPrint('KIMI proxy network request failed');
      throw const AiRecapException(
        'AI recap unavailable. Check your connection.',
      );
    } on FormatException {
      debugPrint('KIMI proxy returned an invalid response');
      throw const AiRecapException(
        'AI recap service returned an invalid response.',
      );
    }
  }

  @override
  void onClose() {
    _client.close();
    super.onClose();
  }
}
