import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../models/club/club_member_model.dart';
import '../../models/club/user_club_model.dart';
import '../../services/club_service.dart';
import 'components/club_widgets.dart';

class ClubPageView extends StatefulWidget {
  final String? clubId;
  final UserClub? club;

  const ClubPageView({super.key, this.clubId, this.club});
  const ClubPageView.fromClubId({super.key, required this.clubId})
    : club = null;
  const ClubPageView.fromClub({super.key, required this.club}) : clubId = null;

  @override
  State<ClubPageView> createState() => _ClubPageViewState();
}

class _ClubPageViewState extends State<ClubPageView> {
  late final ClubService _clubService;
  UserClub? _club;
  List<ClubMember> _members = [];
  bool _loading = true;
  bool _leaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clubService = Get.isRegistered<ClubService>()
        ? Get.find<ClubService>()
        : Get.put(ClubService());
    _club = widget.club;
    _loadClub(refreshDetails: _club == null);
  }

  Future<void> _loadClub({bool refreshDetails = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = _club?.clubId ?? widget.clubId;
      if (id == null) throw StateError('No club was selected.');
      if (refreshDetails) {
        await _clubService.refreshClubData();
        if (_clubService.userClubsError.value != null) {
          throw StateError(_clubService.userClubsError.value!);
        }
        final club = _clubService.getClubById(id);
        if (club == null) {
          throw StateError('This club is no longer in your memberships.');
        }
        if (!mounted) return;
        _club = club;
      }
      final members = await _clubService.getClubMembers(id);
      if (!mounted) return;
      setState(() => _members = members);
    } catch (error) {
      debugPrint('Could not load club details: $error');
      if (mounted) {
        setState(
          () => _error =
              'Check your connection and try again. '
              'If you left this club, return to your clubs list.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _leaveClub() async {
    final club = _club;
    if (club == null || _leaving) return;
    final founder = _clubService.isCurrentUserFounder(club);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Leave this club?', style: clubHeadingStyle),
        content: Text(
          founder
              ? 'Ownership will transfer to the earliest joined member. '
                    'If you are the only member, the club will be deleted.'
              : 'You will leave ${club.clubName}. Keep the invite code if you want to rejoin.',
          style: clubBodyStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onAccent,
              elevation: 0,
            ),
            child: const Text('Leave club'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      final left = await _clubService.leaveClub(club.clubId);
      if (!left) {
        throw StateError('The server did not confirm that you left the club.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('You left ${club.clubName}')));
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Could not leave club: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not leave the club. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = _club;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Club overview'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (club != null)
            PopupMenuButton<String>(
              enabled: !_leaving,
              tooltip: 'Club options',
              color: AppColors.surface,
              icon: const Icon(Icons.more_horiz),
              onSelected: (_) => _leaveClub(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'leave',
                  child: Text(
                    'Leave club',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadClub,
          color: AppColors.accent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList.list(
                  children: [
                    if (club != null) ...[
                      _buildOverview(club),
                      const SizedBox(height: 16),
                      ClubPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Invite members',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Share this code to invite another runner.',
                              style: clubBodyStyle,
                            ),
                            const SizedBox(height: 14),
                            ClubInviteCode(code: club.referralCode),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Members', style: clubHeadingStyle),
                          ),
                          if (!_loading && _error == null)
                            ClubBadge(label: '${_members.length}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your club roster and membership details.',
                        style: clubBodyStyle,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_leaving) ...[
                      const LinearProgressIndicator(color: AppColors.accent),
                      const SizedBox(height: 16),
                    ],
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        ),
                      )
                    else if (_error != null)
                      ClubMessage(
                        title: club == null
                            ? 'Club unavailable'
                            : 'Could not load members',
                        message: _error!,
                        onRetry: _loadClub,
                      )
                    else if (_members.isEmpty)
                      const ClubMessage(
                        title: 'No members to show',
                        message: 'Pull down to refresh the member list.',
                      ),
                  ],
                ),
              ),
              if (!_loading && _error == null && club != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.builder(
                    itemCount: _members.length,
                    itemBuilder: (_, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildMember(_members[index], club),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverview(UserClub club) {
    return ClubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClubAvatar(name: club.clubName, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.clubName, style: clubHeadingStyle),
                    const SizedBox(height: 6),
                    Text(
                      'Created by ${club.creatorDisplayName ?? 'a club member'}',
                      style: clubBodyStyle,
                    ),
                    if (_clubService.isCurrentUserFounder(club)) ...[
                      const SizedBox(height: 8),
                      const ClubBadge(label: 'Your club'),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          Wrap(
            spacing: 28,
            runSpacing: 16,
            children: [
              _stat(
                'Members',
                '${_error == null && !_loading ? _members.length : club.memberCount}',
              ),
              _stat('Created', formatClubDate(club.clubCreatedAt)),
              _stat('You joined', formatClubDate(club.joinedAt)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: clubBodyStyle),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildMember(ClubMember member, UserClub club) {
    final name = member.displayName?.trim().isNotEmpty == true
        ? member.displayName!
        : member.userEmail ?? 'Club member';
    final founder = member.userId == club.creatorId;
    final you = member.userId == _clubService.currentUserId;
    return ClubPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClubAvatar(name: name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Joined ${formatClubDate(member.joinedAt)}',
                  style: clubBodyStyle,
                ),
                if (founder || you) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (founder) const ClubBadge(label: 'Founder'),
                      if (you) const ClubBadge(label: 'You'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
