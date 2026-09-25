import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ske_app/app/shell/app_shell.dart';
import 'package:ske_app/core/auth/auth_state.dart';
import 'package:ske_app/features/auth/domain/app_user.dart';

const _adminUser = AppUser(
  id: 'test-admin',
  fullName: 'Test Admin',
  roleName: 'admin',
  isActive: true,
  permissions: {},
);

Future<void> _pumpShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserProvider.overrideWith((ref) async => _adminUser)],
      child: const MaterialApp(
        home: AppShell(currentPath: '/dashboard', child: SizedBox()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('wide sidebar: no overflow at short viewport height', (tester) async {
    await _pumpShell(tester, const Size(1200, 500));
    expect(tester.takeException(), isNull, reason: 'NavigationRail should not overflow when short');
  });

  testWidgets('wide sidebar: all nav items exist in the tree, including the last one', (tester) async {
    await _pumpShell(tester, const Size(1200, 500));
    for (final label in [
      'Dashboard',
      'Customers',
      'Products',
      'Sales',
      'Payments',
      'Cash / UPI / Bank',
      'Sales Returns',
      'Expenses',
      'Salesmen',
      'Reports',
      'Excel Import',
      'Picklists',
      'Settlements',
      'Users',
      'Roles & Permissions',
    ]) {
      expect(find.text(label), findsWidgets, reason: '$label should be present in the rail');
    }
  });

  testWidgets('wide sidebar: destination list scrolls while logo leading stays pinned', (tester) async {
    await _pumpShell(tester, const Size(1200, 500));

    final scrollable = find.byType(SingleChildScrollView);
    expect(scrollable, findsOneWidget, reason: 'scrollable: true should wrap the destinations in a SingleChildScrollView');

    final logoFinder = find.byType(Image).first;
    final dashboardFinder = find.text('Dashboard').first;
    final rolesFinder = find.text('Roles & Permissions').first;

    final logoBefore = tester.getTopLeft(logoFinder);
    final dashboardBefore = tester.getTopLeft(dashboardFinder);

    // Roles & Permissions (last item) is off-screen before scrolling at this height.
    expect(tester.getTopLeft(rolesFinder).dy, greaterThan(500), reason: 'last item should start below the short viewport');

    await tester.drag(scrollable, const Offset(0, -600));
    await tester.pump();

    final logoAfter = tester.getTopLeft(logoFinder);
    final dashboardAfter = tester.getTopLeft(dashboardFinder);

    expect(logoAfter, equals(logoBefore), reason: 'leading logo must stay pinned while scrolling');
    expect(dashboardAfter.dy, lessThan(dashboardBefore.dy), reason: 'destinations must move as the list scrolls');

    // After scrolling, the last item should now be reachable within the viewport.
    expect(tester.getTopLeft(rolesFinder).dy, lessThan(500));
  });

  testWidgets('wide sidebar: no overflow at a tall viewport either (responsive)', (tester) async {
    await _pumpShell(tester, const Size(1400, 1600));
    expect(tester.takeException(), isNull);
    for (final label in ['Dashboard', 'Roles & Permissions']) {
      expect(find.text(label), findsWidgets);
    }
  });
}
