import 'dart:math';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/club/user_club_model.dart';
import '../models/club/club_member_model.dart';

class ClubService extends GetxService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Observable lists
  final RxList<UserClub> userClubs = <UserClub>[].obs;
  final RxList<ClubMember> clubMembers = <ClubMember>[].obs;
  final RxBool isLoading = false.obs;

  // Expose current user id for UI logic
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Convenience: check if the current user is founder of a club
  bool isCurrentUserFounder(UserClub club) => currentUserId == club.creatorId;

  /// Create a new club and add creator as first member
  Future<String?> createClub(String name) async {
    try {
      isLoading.value = true;
      
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Generate unique referral code
      final referralCode = _generateReferralCode();
      
      // Call database function to create club and add creator as member
      final clubId = await _supabase.rpc('create_club_with_creator', params: {
        'p_name': name,
        'p_referral_code': referralCode,
        'p_creator_id': user.id,
      });

      print('✅ Club created successfully: $clubId');
      
      // Refresh user clubs
      await getUserClubs();
      
      return clubId.toString();
    } catch (e) {
      print('❌ Error creating club: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Join a club using referral code
  Future<bool> joinClub(String referralCode) async {
    try {
      isLoading.value = true;
      
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Call database function to join club
      final result = await _supabase.rpc('join_club_by_referral_code', params: {
        'p_referral_code': referralCode,
        'p_user_id': user.id,
      });

      print('✅ Joined club successfully');
      
      // Refresh user clubs
      await getUserClubs();
      
      return result as bool;
    } catch (e) {
      print('❌ Error joining club: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get all clubs for the current user
  Future<List<UserClub>> getUserClubs() async {
    try {
      isLoading.value = true;
      
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Call database function to get user clubs
      final response = await _supabase.rpc('get_user_clubs', params: {
        'p_user_id': user.id,
      });

      final clubs = (response as List)
          .map((json) => UserClub.fromJson(json))
          .toList();

      userClubs.value = clubs;
      print('✅ Retrieved ${clubs.length} user clubs');
      
      return clubs;
    } catch (e) {
      print('❌ Error getting user clubs: $e');
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  /// Get all members of a specific club
  Future<List<ClubMember>> getClubMembers(String clubId) async {
    try {
      // Don't set loading state here to avoid build conflicts
      // isLoading.value = true;
      
      // Call database function to get club members
      final response = await _supabase.rpc('get_club_members', params: {
        'p_club_id': clubId,
      });

      final members = (response as List)
          .map((json) => ClubMember.fromJson(json))
          .toList();

      // Only update reactive state if explicitly needed
      // clubMembers.value = members;
      print('✅ Retrieved ${members.length} club members for club: $clubId');
      
      return members;
    } catch (e) {
      print('❌ Error getting club members: $e');
      return [];
    }
  }

  /// Leave a club (removes current user from club members)
  /// Returns true on success. Prefers RPC `leave_club_by_member`,
  /// falls back to direct delete from `club_members` if RPC not available.
  Future<bool> leaveClub(String clubId) async {
    try {
      isLoading.value = true;

      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Try RPC first
      try {
        final result = await _supabase.rpc('leave_club_by_member', params: {
          'p_club_id': clubId,
          'p_user_id': user.id,
        });

        // Consider truthy values as success
        final success = result == true || (result is int && result > 0);
        await getUserClubs();
        print('✅ Left club via RPC: $clubId');
        return success;
      } catch (e) {
        // Fall through to direct delete if RPC is missing or fails
        print('ℹ️ RPC leave_club_by_member failed, attempting direct delete: $e');
      }

      // Fallback: direct delete from membership table (requires permissive RLS)
      await _supabase.from('club_members').delete().match({
        'club_id': clubId,
        'user_id': user.id,
      });

      await getUserClubs();
      print('✅ Left club via direct delete: $clubId');
      return true;
    } catch (e) {
      print('❌ Error leaving club: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update club members in reactive state (use when UI needs to be updated)
  Future<void> updateClubMembersReactive(String clubId) async {
    try {
      isLoading.value = true;
      
      final members = await getClubMembers(clubId);
      clubMembers.value = members;
    } catch (e) {
      print('❌ Error updating club members reactive state: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Generate a unique referral code
  String _generateReferralCode() {
    // Generate 8-character alphanumeric code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String code;
    
    do {
      code = String.fromCharCodes(
        Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
      );
    } while (code.contains('000') || code.contains('111') || 
             code.contains('AAA') || code.contains('BBB') ||
             code.contains('CCC') || code.contains('DDD') ||
             code.contains('EEE') || code.contains('FFF') ||
             code.contains('GGG') || code.contains('HHH') ||
             code.contains('III') || code.contains('JJJ') ||
             code.contains('KKK') || code.contains('LLL') ||
             code.contains('MMM') || code.contains('NNN') ||
             code.contains('OOO') || code.contains('PPP') ||
             code.contains('QQQ') || code.contains('RRR') ||
             code.contains('SSS') || code.contains('TTT') ||
             code.contains('UUU') || code.contains('VVV') ||
             code.contains('WWW') || code.contains('XXX') ||
             code.contains('YYY') || code.contains('ZZZ')); // Avoid all repeated patterns
    
    return code;
  }

  /// Check if user is a member of a specific club
  bool isUserMemberOfClub(String clubId) {
    return userClubs.any((club) => club.clubId == clubId);
  }

  /// Get club by ID from user clubs
  UserClub? getClubById(String clubId) {
    try {
      return userClubs.firstWhere((club) => club.clubId == clubId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh all club data
  Future<void> refreshClubData() async {
    await getUserClubs();
  }

  /// Clear all club data
  void clearClubData() {
    userClubs.clear();
    clubMembers.clear();
  }
}
