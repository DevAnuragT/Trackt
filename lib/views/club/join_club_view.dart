import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../models/club/user_club_model.dart';
import '../../services/club_service.dart';
import 'club_page_view.dart';
import 'components/club_widgets.dart';

class JoinClubView extends StatefulWidget {
  const JoinClubView({super.key});

  @override
  State<JoinClubView> createState() => _JoinClubViewState();
}

class _JoinClubViewState extends State<JoinClubView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final ClubService _clubService = Get.find<ClubService>();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinClub() async {
    if (_joining || !_formKey.currentState!.validate()) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    final code = _codeController.text.trim().toUpperCase();
    try {
      final joined = await _clubService.joinClub(code);
      if (!joined) {
        throw StateError('The server did not confirm the membership.');
      }
      await _clubService.refreshClubData();
      if (!mounted) return;
      UserClub? joinedClub;
      for (final club in _clubService.userClubs) {
        if (club.referralCode.toUpperCase() == code) {
          joinedClub = club;
          break;
        }
      }
      final club = joinedClub;
      if (club != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ClubPageView.fromClub(club: club),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Club joined. Refresh your clubs list to see it.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      debugPrint('Could not join club: $error');
      if (mounted) {
        setState(() {
          final message = error.toString().toLowerCase();
          _error = message.contains('not found')
              ? 'No club matches this invite code.'
              : message.contains('already a member')
              ? 'You are already a member of this club.'
              : 'Could not join the club. Check your code and connection, then try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClubFormLayout(
      title: 'Join club',
      description: 'Have a crew in mind? Enter their invite code to join them.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Invite code',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeController,
              enabled: !_joining,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onFieldSubmitted: (_) => _joinClub(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
                fontSize: 17,
                letterSpacing: 1,
              ),
              decoration: const InputDecoration(
                hintText: 'ABCD1234',
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
              validator: (value) {
                final code = value?.trim() ?? '';
                if (code.isEmpty) return 'Enter an invite code';
                if (code.length != 8) return 'Invite codes have 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask a club member for their 8-character code. '
              'Uppercase and lowercase both work.',
              style: clubBodyStyle,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _joining ? null : _joinClub,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_joining ? 'Joining club...' : 'Join club'),
            ),
          ],
        ),
      ),
    );
  }
}
