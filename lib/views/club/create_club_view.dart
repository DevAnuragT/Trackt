import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/club_service.dart';
import '../club/club_page_view.dart'; // Added import for ClubPageView

class CreateClubView extends StatefulWidget {
  const CreateClubView({super.key});

  @override
  State<CreateClubView> createState() => _CreateClubViewState();
}

class _CreateClubViewState extends State<CreateClubView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final ClubService _clubService = Get.find<ClubService>();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final clubId = await _clubService.createClub(_nameController.text.trim());
      
      if (clubId != null) {
        Get.snackbar(
          'Success',
          'Club created successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        
        // Refresh club data first
        await Get.find<ClubService>().refreshClubData();
        
        // Get the newly created club
        final newClub = Get.find<ClubService>().getClubById(clubId);
        
        if (newClub != null) {
          // Navigate to the club page removing current page from stack
          Get.off(() => ClubPageView.fromClub(club: newClub));
        } else {
          // Fallback: go back to clubs view
          Get.back();
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create club: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('Create Club'),
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
                Icons.add_circle_outline,
                size: 80,
                color: Colors.blue[400],
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Create a New Club',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Start a club and invite others to join using the referral code',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Club Name Input
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _nameController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Club Name',
                    labelStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    hintText: 'Enter club name',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.edit,
                      color: Colors.blue[400],
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
                      borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
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
                      return 'Please enter a club name';
                    }
                    if (value.trim().length < 3) {
                      return 'Club name must be at least 3 characters';
                    }
                    if (value.trim().length > 50) {
                      return 'Club name must be less than 50 characters';
                    }
                    return null;
                  },
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Create Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createClub,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Club',
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
                  color: Colors.blue[900]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[700]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[400],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A unique referral code will be automatically generated for your club',
                        style: TextStyle(
                          color: Colors.blue[200],
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
