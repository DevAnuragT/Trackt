import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../services/club_service.dart';
import 'club_page_view.dart';
import 'components/club_widgets.dart';

class CreateClubView extends StatefulWidget {
  const CreateClubView({super.key});

  @override
  State<CreateClubView> createState() => _CreateClubViewState();
}

class _CreateClubViewState extends State<CreateClubView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final ClubService _clubService = Get.find<ClubService>();
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createClub() async {
    if (_creating || !_formKey.currentState!.validate()) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final id = await _clubService.createClub(_nameController.text.trim());
      if (id == null || id.isEmpty) {
        throw StateError('The server did not return a created club.');
      }
      if (!mounted) return;
      final club = _clubService.getClubById(id);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => club == null
              ? ClubPageView.fromClubId(clubId: id)
              : ClubPageView.fromClub(club: club),
        ),
      );
    } catch (error) {
      debugPrint('Could not create club: $error');
      if (mounted) {
        setState(
          () => _error =
              'Could not create your club. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClubFormLayout(
      title: 'Create club',
      description:
          'Bring your running crew together. Choose a name, then invite '
          "members with your club's unique code.",
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Club name',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              enabled: !_creating,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _createClub(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g. Riverside Run Club',
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Enter a club name';
                if (name.length < 3) return 'Use at least 3 characters';
                if (name.length > 50) return 'Use no more than 50 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              '3-50 characters. Your invite code is generated automatically.',
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
              onPressed: _creating ? null : _createClub,
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
              child: Text(_creating ? 'Creating club...' : 'Create club'),
            ),
          ],
        ),
      ),
    );
  }
}
