import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/on_chain_leaderboard_service.dart';

class OnChainLeaderboardPage extends StatefulWidget {
  final OnChainLeaderboardService service;

  const OnChainLeaderboardPage({super.key, required this.service});

  @override
  State<OnChainLeaderboardPage> createState() => _OnChainLeaderboardPageState();
}

class _OnChainLeaderboardPageState extends State<OnChainLeaderboardPage> {
  late Future<List<OnChainRunner>> _runners;

  @override
  void initState() {
    super.initState();
    _runners = widget.service.fetchLeaderboard();
  }

  void _refresh() {
    setState(() {
      _runners = widget.service.fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('On-chain standings'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh standings',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Real Monad claims, indexed by Envio.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ranked by currently owned area. Local demo proofs are not included.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<OnChainRunner>>(
                future: _runners,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.error.toString(),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final runners = snapshot.data!;
                  if (runners.isEmpty) {
                    return const Text(
                      'No on-chain claims indexed yet. Complete a funded claim '
                      'and wait for the indexer to sync.',
                      style: TextStyle(color: AppColors.textSecondary),
                    );
                  }
                  return ListView.separated(
                    itemCount: runners.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: AppColors.border),
                    itemBuilder: (context, index) {
                      final runner = runners[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Text(
                          '${index + 1}',
                          style: const TextStyle(color: AppColors.accent),
                        ),
                        title: Text(
                          runner.shortAddress,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        subtitle: Text(
                          '${runner.territoryCount} territories, '
                          '${runner.conquestCount} conquests',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            '${runner.totalArea} m²',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
