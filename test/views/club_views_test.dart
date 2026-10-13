import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trackt/core/theme/app_colors.dart';
import 'package:trackt/models/club/club_member_model.dart';
import 'package:trackt/models/club/user_club_model.dart';
import 'package:trackt/services/club_service.dart';
import 'package:trackt/views/club/club_page_view.dart';
import 'package:trackt/views/club/club_view.dart';
import 'package:trackt/views/club/components/club_widgets.dart';
import 'package:trackt/views/club/create_club_view.dart';
import 'package:trackt/views/club/join_club_view.dart';

UserClub sampleClub({
  String id = 'club-1',
  String name = 'Riverside Run Club',
  String code = 'RIVER123',
}) => UserClub(
  clubId: id,
  clubName: name,
  referralCode: code,
  creatorId: 'founder',
  creatorDisplayName: 'Maya Chen',
  clubCreatedAt: DateTime(2026, 10, 1),
  joinedAt: DateTime(2026, 10, 10),
  memberCount: 2,
);

class TestClubService extends ClubService {
  TestClubService()
    : super(client: SupabaseClient('https://clubs.example', 'test-key'));

  List<UserClub> clubs = [];
  List<ClubMember> members = [
    ClubMember(
      userId: 'current-user',
      displayName: 'Alex Rivera',
      joinedAt: DateTime(2026, 10, 10),
    ),
    ClubMember(
      userId: 'founder',
      displayName: 'Maya Chen',
      joinedAt: DateTime(2026, 10, 1),
    ),
  ];
  int clubLoads = 0;
  int memberLoads = 0;
  int leaves = 0;
  bool failClubs = false;
  bool failMembers = false;
  bool leaveResult = true;
  String? createName;
  String? joinCode;
  String userId = 'current-user';
  Completer<List<ClubMember>>? memberRequest;
  String? joinError;

  @override
  String? get currentUserId => userId;

  @override
  Future<List<UserClub>> getUserClubs() async {
    clubLoads++;
    isLoading.value = true;
    userClubsError.value = null;
    await Future<void>.delayed(Duration.zero);
    if (failClubs) {
      userClubsError.value = 'Check your connection and try again.';
    } else {
      userClubs.assignAll(clubs);
    }
    isLoading.value = false;
    return userClubs.toList();
  }

  @override
  Future<List<ClubMember>> getClubMembers(String clubId) async {
    memberLoads++;
    if (failMembers) throw StateError('Test network failure');
    return memberRequest?.future ?? Future.value(members);
  }

  @override
  Future<bool> leaveClub(String clubId) async {
    leaves++;
    if (leaveResult) {
      clubs.removeWhere((club) => club.clubId == clubId);
      userClubs.removeWhere((club) => club.clubId == clubId);
    }
    return leaveResult;
  }

  @override
  Future<String?> createClub(String name) async {
    createName = name;
    final club = sampleClub(name: name);
    clubs = [club];
    userClubs.assignAll(clubs);
    return club.clubId;
  }

  @override
  Future<bool> joinClub(String referralCode) async {
    joinCode = referralCode;
    if (joinError != null) throw StateError(joinError!);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestClubService service;

  setUp(() {
    Get.reset();
    service = TestClubService();
    Get.put<ClubService>(service);
  });

  tearDown(() {
    Get.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: const ColorScheme.dark(primary: AppColors.accent),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    );
  }

  testWidgets('clubs load once, with working empty state and no overflow', (
    tester,
  ) async {
    await pumpPage(tester, const ClubView(), scale: 1.5);
    await tester.pumpAndSettle();
    expect(service.clubLoads, 1);
    expect(find.text('No clubs yet'), findsOneWidget);
    expect(find.text('Create club'), findsOneWidget);
    expect(find.text('Join club'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a failed refresh keeps existing club cards visible with an error',
    (tester) async {
      service.clubs = [sampleClub()];
      await pumpPage(tester, const ClubView());
      await tester.pumpAndSettle();
      service.failClubs = true;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      await refresh;
      expect(find.text('Could not refresh clubs'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Riverside Run Club'), 120);
      expect(find.text('Riverside Run Club'), findsOneWidget);
      expect(find.text('No clubs yet'), findsNothing);
    },
  );

  testWidgets('a confirmed leave returns to the refreshed clubs list', (
    tester,
  ) async {
    service.clubs = [sampleClub()];
    await pumpPage(tester, const ClubView());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Riverside Run Club'), 120);
    await tester.tap(find.text('Riverside Run Club'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Club options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave club'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Leave club'));
    await tester.pumpAndSettle();
    expect(service.leaves, 1);
    expect(find.byType(ClubPageView), findsNothing);
    expect(find.text('No clubs yet'), findsOneWidget);
    expect(service.clubLoads, 2);
  });

  testWidgets('long club names and scaled list actions remain usable', (
    tester,
  ) async {
    service.clubs = [
      sampleClub(name: 'Riverside International Running Community Club'),
    ];
    await pumpPage(tester, const ClubView(), scale: 2);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('RIVER123'), 180);
    expect(
      find.text('Riverside International Running Community Club'),
      findsOneWidget,
    );
    expect(find.text('2 members'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'list load errors remain distinct from an empty membership list',
    (tester) async {
      service.failClubs = true;
      await pumpPage(tester, const ClubView());
      await tester.pumpAndSettle();
      expect(find.text('Could not refresh clubs'), findsOneWidget);
      expect(find.text('No clubs yet'), findsNothing);
      service.failClubs = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No clubs yet'), findsOneWidget);
      expect(service.clubLoads, 2);
    },
  );

  testWidgets('invite code copies without opening the club', (tester) async {
    String? clipboard;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    service.clubs = [sampleClub()];
    await pumpPage(tester, const ClubView());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('RIVER123'), 120);
    await tester.tap(find.text('RIVER123'));
    await tester.pump();
    expect(clipboard, 'RIVER123');
    expect(find.text('Invite code copied'), findsOneWidget);
    expect(find.byType(ClubPageView), findsNothing);
  });

  testWidgets('opening and returning from a club refreshes the list', (
    tester,
  ) async {
    service.clubs = [sampleClub()];
    await pumpPage(tester, const ClubView());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Riverside Run Club'), 120);
    await tester.tap(find.text('Riverside Run Club'));
    await tester.pumpAndSettle();
    expect(find.byType(ClubPageView), findsOneWidget);
    Navigator.of(tester.element(find.byType(ClubPageView))).pop();
    await tester.pumpAndSettle();
    expect(service.clubLoads, 2);
  });

  testWidgets('founder badge follows creator ID, not list position', (
    tester,
  ) async {
    await pumpPage(tester, ClubPageView.fromClub(club: sampleClub()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Maya Chen'), 180);
    final founderPanel = find.ancestor(
      of: find.text('Maya Chen'),
      matching: find.byType(ClubPanel),
    );
    final memberPanel = find.ancestor(
      of: find.text('Alex Rivera'),
      matching: find.byType(ClubPanel),
    );
    expect(
      find.descendant(of: founderPanel, matching: find.text('Founder')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: memberPanel, matching: find.text('Founder')),
      findsNothing,
    );
    expect(
      find.descendant(of: memberPanel, matching: find.text('You')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('club detail is scrollable with long names and large text', (
    tester,
  ) async {
    service.members = [
      ClubMember(
        userId: 'founder',
        displayName:
            'A very long runner display name that must wrap gracefully',
        joinedAt: DateTime(2026, 10, 1),
      ),
    ];
    await pumpPage(
      tester,
      ClubPageView.fromClub(
        club: sampleClub(
          name: 'Riverside International Running Community Club',
        ),
      ),
      scale: 2,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Founder'), 250);
    expect(find.text('Founder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed member load can retry and is never shown as no members', (
    tester,
  ) async {
    service.clubs = [sampleClub()];
    service.failMembers = true;
    await pumpPage(tester, ClubPageView.fromClub(club: sampleClub()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Try again'), 150);
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Try again'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load members'), findsOneWidget);
    expect(find.text('No members to show'), findsNothing);
    service.failMembers = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Alex Rivera'), 150);
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(service.memberLoads, 2);
  });

  testWidgets('club ID load errors end the loading state and expose retry', (
    tester,
  ) async {
    service.failClubs = true;
    await pumpPage(tester, const ClubPageView.fromClubId(clubId: 'missing'));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Club unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'a disposed club screen does not update state after member loading',
    (tester) async {
      service.memberRequest = Completer<List<ClubMember>>();
      await pumpPage(tester, ClubPageView.fromClub(club: sampleClub()));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      service.memberRequest!.complete([]);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leave confirmation preserves membership when cancelled', (
    tester,
  ) async {
    service.userId = 'founder';
    await pumpPage(tester, ClubPageView.fromClub(club: sampleClub()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Club options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave club'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ownership will transfer'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.leaves, 0);
    expect(find.byType(ClubPageView), findsOneWidget);
  });

  testWidgets(
    'an unconfirmed leave never dismisses the club or claims success',
    (tester) async {
      service.leaveResult = false;
      await pumpPage(tester, ClubPageView.fromClub(club: sampleClub()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Club options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave club'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Leave club'));
      await tester.pumpAndSettle();
      expect(service.leaves, 1);
      expect(find.byType(ClubPageView), findsOneWidget);
      expect(
        find.text('Could not leave the club. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'create and join forms stay scrollable with keyboard and large text',
    (tester) async {
      for (final page in [const CreateClubView(), const JoinClubView()]) {
        await pumpPage(tester, page, scale: 2);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byType(ElevatedButton), 200);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('creating a club validates and opens the created club', (
    tester,
  ) async {
    await pumpPage(tester, const CreateClubView());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create club'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a club name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  Morning Miles  ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create club'));
    await tester.pumpAndSettle();
    expect(service.createName, 'Morning Miles');
    expect(find.byType(ClubPageView), findsOneWidget);
    expect(find.text('Morning Miles'), findsOneWidget);
  });

  testWidgets(
    'joining opens the matching code rather than the last listed club',
    (tester) async {
      service.clubs = [
        sampleClub(name: 'Correct Club', code: 'RIGHT123'),
        sampleClub(id: 'club-2', name: 'Other Club', code: 'OTHER123'),
      ];
      await pumpPage(tester, const JoinClubView());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'right123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Join club'));
      await tester.pumpAndSettle();
      expect(service.joinCode, 'RIGHT123');
      expect(find.text('Correct Club'), findsOneWidget);
      expect(find.text('Other Club'), findsNothing);
    },
  );

  testWidgets('joining reports an invalid code without navigating', (
    tester,
  ) async {
    service.joinError = 'Club not found';
    await pumpPage(tester, const JoinClubView());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'WRONG123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Join club'));
    await tester.pumpAndSettle();
    expect(find.text('No club matches this invite code.'), findsOneWidget);
    expect(find.byType(JoinClubView), findsOneWidget);
    expect(find.byType(ClubPageView), findsNothing);
  });
}
