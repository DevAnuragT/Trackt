import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class OnChainRunner {
  final String address;
  final int territoryCount;
  final BigInt totalArea;
  final int conquestCount;

  const OnChainRunner({
    required this.address,
    required this.territoryCount,
    required this.totalArea,
    required this.conquestCount,
  });

  factory OnChainRunner.fromJson(Map<String, dynamic> data) {
    final address = data['address'];
    final territories = data['territoryCount'];
    final conquests = data['conquestCount'];
    final area = BigInt.tryParse('${data['totalArea']}');
    if (address is! String ||
        !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address) ||
        territories is! int ||
        territories < 0 ||
        conquests is! int ||
        conquests < 0 ||
        area == null ||
        area.isNegative) {
      throw const FormatException('Invalid indexed runner');
    }
    return OnChainRunner(
      address: address,
      territoryCount: territories,
      totalArea: area,
      conquestCount: conquests,
    );
  }

  String get shortAddress =>
      '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

class LeaderboardException implements Exception {
  final String message;

  const LeaderboardException(this.message);

  @override
  String toString() => message;
}

class OnChainLeaderboardService extends GetxService {
  final String endpoint;
  final http.Client _client;

  OnChainLeaderboardService({required this.endpoint, http.Client? client})
    : _client = client ?? http.Client();

  Future<List<OnChainRunner>> fetchLeaderboard() async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const LeaderboardException(
        'The Envio leaderboard is not configured. Deploy the indexer and set '
        'ENVIO_GRAPHQL_URL to its public HTTPS endpoint.',
      );
    }
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': '''
query TracktLeaderboard {
  Player(
    where: {territoryCount: {_gt: 0}}
    order_by: [{totalArea: desc}, {territoryCount: desc}, {address: asc}]
    limit: 20
  ) {
    address
    territoryCount
    totalArea
    conquestCount
  }
}
''',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('Envio leaderboard HTTP ${response.statusCode}');
        throw const LeaderboardException(
          'The indexer is unavailable. Try again.',
        );
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid indexer response');
      }
      if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
        debugPrint('Envio rejected the leaderboard query');
        throw const LeaderboardException(
          'The indexer rejected the query. Check its deployment and schema.',
        );
      }
      final result = data['data'];
      final players = result is Map ? result['Player'] : null;
      if (players is! List) {
        throw const FormatException('Missing indexed players');
      }
      return players.map((player) {
        if (player is! Map<String, dynamic>) {
          throw const FormatException('Invalid indexed player');
        }
        return OnChainRunner.fromJson(player);
      }).toList();
    } on TimeoutException {
      debugPrint('Envio leaderboard timed out');
      throw const LeaderboardException('The indexer timed out. Try again.');
    } on http.ClientException {
      debugPrint('Envio leaderboard network request failed');
      throw const LeaderboardException('Check your connection and try again.');
    } on FormatException {
      debugPrint('Envio returned an invalid leaderboard response');
      throw const LeaderboardException(
        'The indexer returned unexpected data. Check its schema.',
      );
    }
  }

  @override
  void onClose() {
    _client.close();
    super.onClose();
  }
}
