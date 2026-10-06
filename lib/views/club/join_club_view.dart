import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/club_service.dart';
import 'club_page_view.dart';

class JoinClubView extends StatefulWidget {
  const JoinClubView({super.key});

  @override
  State<JoinClubView> createState() => _JoinClubViewState();
}

class _JoinClubViewState extends State<JoinClubView> {
  final _formKey = GlobalKey<FormState>();
  final _referralCodeController = TextEditingController();
  final ClubService _clubService = Get.find<ClubService>();
  bool _isJoining = false;

  @override
  void dispose() {
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinClub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final success = await _clubService.joinClub(_referralCodeController.text.trim().toUpperCase());
      
      if (success) {
        Get.snackbar(
          'Success',
          'Successfully joined the club!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        
        // Get the club details and navigate to club page
        await _clubService.refreshClubData();
        final userClubs = _clubService.userClubs;
        if (userClubs.isNotEmpty) {
          // Find the most recently joined club (should be the one we just joined)
          final latestClub = userClubs.last;
          // Navigate to club page and remove join page from stack
          Get.off(() => ClubPageView.fromClub(club: latestClub));
        } else {
          // Fallback: go back to clubs view
          Get.back();
        }
      }
    } catch (e) {
      String errorMessage = 'Failed to join club';
      
      if (e.toString().contains('not found')) {
        errorMessage = 'Club with this referral code not found';
      } else if (e.toString().contains('already a member')) {
        errorMessage = 'You are already a member of this club';
      } else {
        errorMessage = 'Failed to join club: ${e.toString()}';
      }
      
      Get.snackbar(
        'Error',
        errorMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('Join Club'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              
              // Icon
              Icon(
                Icons.group_add,
                size: 80,
                color: Colors.green[400],
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Join a Club',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Enter the referral code to join an existing club',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Referral Code Input
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _referralCodeController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Referral Code',
                    labelStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    hintText: 'ABCD1234',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontFamily: 'monospace',
                      fontSize: 20,
                    ),
                    prefixIcon: Icon(
                      Icons.code,
                      color: Colors.green[400],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.green[400]!, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[850],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a referral code';
                    }
                    if (value.trim().length != 8) {
                      return 'Referral code must be 8 characters';
                    }
                    return null;
                  },
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Join Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _joinClub,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Join Club',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[900]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[700]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.green[400],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Referral codes are 8 characters long and are case-insensitive',
                        style: TextStyle(
                          color: Colors.green[200],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
