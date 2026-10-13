import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../models/club/user_club_model.dart';
import '../../services/club_service.dart';
import 'club_page_view.dart';
import 'components/club_widgets.dart';
import 'create_club_view.dart';
import 'join_club_view.dart';

class ClubView extends StatefulWidget {
  const ClubView({super.key});

  @override
  State<ClubView> createState() => _ClubViewState();
}

class _ClubViewState extends State<ClubView> {
  late final ClubService _clubService;

  @override
  void initState() {
    super.initState();
    _clubService = Get.isRegistered<ClubService>()
        ? Get.find<ClubService>()
        : Get.put(ClubService());
    _loadUserClubs();
  }

  Future<void> _loadUserClubs() async {
    await _clubService.getUserClubs();
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _loadUserClubs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clubs'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _loadUserClubs,
          child: Obx(() {
            final clubs = _clubService.userClubs.toList();
            final loading = _clubService.isLoading.value;
            final error = _clubService.userClubsError.value;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverList.list(
                    children: [
                      const Text(
                        'Your running community, in one place.',
                        style: clubBodyStyle,
                      ),
                      const SizedBox(height: 24),
                      _buildActions(),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Your clubs', style: clubHeadingStyle),
                          ),
                          ClubBadge(label: '${clubs.length}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (loading && clubs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          ),
                        )
                      else if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClubMessage(
                            title: 'Could not refresh clubs',
                            message: error,
                            onRetry: loading ? null : _loadUserClubs,
                          ),
                        )
                      else if (clubs.isEmpty)
                        const ClubMessage(
                          title: 'No clubs yet',
                          message:
                              'Create a club for your crew, or use an invite code '
                              'to join an existing one.',
                        ),
                      if (loading && clubs.isNotEmpty) ...[
                        const LinearProgressIndicator(
                          color: AppColors.accent,
                          backgroundColor: AppColors.surfaceVariant,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.builder(
                    itemCount: clubs.length,
                    itemBuilder: (_, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildClubCard(clubs[index]),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildActions() {
    final create = ElevatedButton.icon(
      onPressed: () => _openPage(const CreateClubView()),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Create club'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    final join = OutlinedButton.icon(
      onPressed: () => _openPage(const JoinClubView()),
      icon: const Icon(Icons.group_add_outlined, size: 18),
      label: const Text('Join club'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledText = MediaQuery.textScalerOf(context).scale(14);
        if (constraints.maxWidth < 330 || scaledText > 18) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [create, const SizedBox(height: 10), join],
          );
        }
        return Row(
          children: [
            Expanded(child: create),
            const SizedBox(width: 12),
            Expanded(child: join),
          ],
        );
      },
    );
  }

  Widget _buildClubCard(UserClub club) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _openPage(ClubPageView.fromClub(club: club)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClubAvatar(name: club.clubName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club.clubName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${club.memberCount} ${club.memberCount == 1 ? 'member' : 'members'}',
                          style: clubBodyStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClubInviteCode(code: club.referralCode),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Joined ${formatClubDate(club.joinedAt)}',
                    style: clubBodyStyle,
                  ),
                  if (_clubService.isCurrentUserFounder(club))
                    const ClubBadge(label: 'Founder'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
