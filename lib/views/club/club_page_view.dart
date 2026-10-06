import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import '../../models/club/user_club_model.dart';
import '../../models/club/club_member_model.dart';
import '../../services/club_service.dart';

class ClubPageView extends StatefulWidget {
  final String? clubId;
  final UserClub? club;
  
  const ClubPageView({super.key, this.clubId, this.club});
  
  // Constructor for when we have clubId (from join club)
  const ClubPageView.fromClubId({super.key, required this.clubId}) : club = null;
  
  // Constructor for when we have club object (from club list)
  const ClubPageView.fromClub({super.key, required this.club}) : clubId = null;

  @override
  State<ClubPageView> createState() => _ClubPageViewState();
}

class _ClubPageViewState extends State<ClubPageView> {
  late ClubService _clubService;
  List<ClubMember> _members = [];
  bool _isLoading = true;
  UserClub? _clubData;

  @override
  void initState() {
    super.initState();
    _clubService = Get.find<ClubService>();
    _initializeClubData();
  }

  Future<void> _initializeClubData() async {
    if (widget.club != null) {
      _clubData = widget.club;
      await _loadClubMembers();
    } else if (widget.clubId != null) {
      // We need to get the club data first
      await _loadClubData();
    }
  }

  Future<void> _loadClubData() async {
    try {
      await _clubService.refreshClubData();
      final userClubs = _clubService.userClubs;
      _clubData = userClubs.firstWhere((club) => club.clubId == widget.clubId);
      await _loadClubMembers();
    } catch (e) {
      print('Error loading club data: $e');
      Get.snackbar(
        'Error',
        'Failed to load club data',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _loadClubMembers() async {
    if (_clubData == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final members = await _clubService.getClubMembers(_clubData!.clubId);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading club members: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Get.snackbar(
          'Error',
          'Failed to load club members',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_clubData == null) {
      return Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text(_clubData!.clubName),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Leave Club (founder can also leave; ownership will transfer)
          PopupMenuButton<String>(
              color: Colors.grey[900],
              onSelected: (value) async {
                if (value == 'leave') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text('Leave Club', style: TextStyle(color: Colors.white)),
                      content: Text(
                        _clubService.isCurrentUserFounder(_clubData!)
                            ? 'You are the founder. If other members exist, ownership will transfer to the earliest joined member; if not, the club will be deleted. Continue?'
                            : 'Are you sure you want to leave "${_clubData!.clubName}"? You may need the referral code to rejoin.',
                        style: TextStyle(color: Colors.grey[300]),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel',style: TextStyle(color: Colors.white),),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text(
                            'Leave',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      // Optional local spinner via snackbar
                      Get.snackbar(
                        'Leaving',
                        'Processing your request...',
                        backgroundColor: Colors.grey[800],
                        colorText: Colors.white,
                        duration: const Duration(seconds: 1),
                      );
                      // Capture context before leaving
                      final bool wasFounder = _clubService.isCurrentUserFounder(_clubData!);
                      final int memberCountAtLeave = _members.length; // includes self

                      await _clubService.leaveClub(_clubData!.clubId);

                      String message;
                      if (wasFounder) {
                        // If only founder was present, club is deleted; otherwise ownership transfers
                        message = memberCountAtLeave <= 1
                            ? 'Club deleted. You have left ${_clubData!.clubName}'
                            : 'Ownership transferred. You have left ${_clubData!.clubName}';
                      } else {
                        message = 'You have left ${_clubData!.clubName}';
                      }

                      Get.snackbar(
                        'Left Club',
                        message,
                        backgroundColor: Colors.green,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                      if (mounted) Navigator.of(context).maybePop();
                    } catch (e) {
                      Get.snackbar(
                        'Error',
                        e.toString(),
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 3),
                      );
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Leave Club', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club Info Card
            Card(
              color: Colors.grey[850],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.group,
                          color: Colors.blue[400],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _clubData!.clubName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Creator info
                              Text(
                                'Created by ${_clubData!.creatorDisplayName ?? 'Unknown User'}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Referral Code below creator (tap to copy)
                              InkWell(
                                onTap: () async {
                                  await Clipboard.setData(ClipboardData(text: _clubData!.referralCode));
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.copy,
                                      color: Colors.green[400],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _clubData!.referralCode,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Member Count
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: Colors.orange[400],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Members: ${_members.length}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Created Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.purple[400],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Created: ${_formatDate(_clubData!.clubCreatedAt)}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Joined Date
                    Row(
                      children: [
                        Icon(
                          Icons.login,
                          color: Colors.cyan[400],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Joined: ${_formatDate(_clubData!.joinedAt)}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Members Section Header
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Club Members',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Members List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  : _members.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Members',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            return _buildMemberCard(member, index + 1);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(ClubMember member, int position) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: position == 1 
              ? Colors.amber[600]!.withOpacity(0.5)
              : Colors.grey[700]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Position Badge
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: position == 1 
                    ? Colors.amber[600]
                    : Colors.blue[600],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  position.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Member Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName ?? member.userEmail ?? 'Unknown User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey[500],
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Joined ${_formatDate(member.joinedAt)}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Role Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: position == 1 
                    ? Colors.amber[600]
                    : Colors.grey[600],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                position == 1 ? 'Founder' : 'Member',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
