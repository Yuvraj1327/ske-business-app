import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ske_app/app/shell/app_shell.dart';
import 'package:ske_app/core/auth/auth_state.dart';
import 'package:ske_app/features/auth/domain/app_user.dart';

const _adminUser = AppUser(id: 'a', fullName: 'Admin', roleName: 'admin', isActive: true, permissions: {});

/// Mirrors router.dart's structure: one ShellRoute around every page, pages
/// reached by `go` (sidebar) or `push` (drill-down), no transitions.
GoRouter _router() => GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (c, state, child) => AppShell(currentPath: state.uri.path, child: child),
          routes: [
            for (final path in ['/dashboard', '/sales', '/sales/new', '/sales/:id', '/sales/:id/return', '/settings'])
              GoRoute(
                path: path,
                pageBuilder: (c, s) => NoTransitionPage(
                  child: Center(child: Text('PAGE ${s.uri.path}')),
                ),
              ),
          ],
        ),
      ],
    );

Future<GoRouter> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = _router();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserProvider.overrideWith((ref) async => _adminUser)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

final _back = find.byIcon(Icons.arrow_back);

void main() {
  for (final size in [const Size(1200, 800), const Size(400, 800)]) {
    final label = size.width > 900 ? 'wide' : 'narrow';

    testWidgets('$label: no Back on dashboard; Back returns to exact previous page', (tester) async {
      final router = await _pump(tester, size);
      expect(_back, findsNothing);

      router.push('/sales/42');
      await tester.pumpAndSettle();
      expect(find.text('PAGE /sales/42'), findsOneWidget);
      expect(_back, findsOneWidget, reason: 'exactly one Back button');

      router.push('/sales/42/return');
      await tester.pumpAndSettle();
      expect(find.text('PAGE /sales/42/return'), findsOneWidget);

      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(find.text('PAGE /sales/42'), findsOneWidget);

      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(find.text('PAGE /dashboard'), findsOneWidget);
      expect(_back, findsNothing);
    });

    testWidgets('$label: sidebar page (no history) goes back to parent / dashboard', (tester) async {
      final router = await _pump(tester, size);
      router.go('/sales/42');
      await tester.pumpAndSettle();
      expect(_back, findsOneWidget);

      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(find.text('PAGE /sales'), findsOneWidget);

      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(find.text('PAGE /dashboard'), findsOneWidget);
    });

    testWidgets('$label: Android system back behaves like Back', (tester) async {
      final router = await _pump(tester, size);
      router.push('/sales');
      await tester.pumpAndSettle();
      router.push('/sales/new');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('PAGE /sales'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('PAGE /dashboard'), findsOneWidget);

      // Fresh deep link with no history -> parent, not app exit.
      router.go('/sales/7');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('PAGE /sales'), findsOneWidget);
    });

    testWidgets('$label: Settings has Back', (tester) async {
      final router = await _pump(tester, size);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('PAGE /settings'), findsOneWidget);
      expect(_back, findsOneWidget);
      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(find.text('PAGE /dashboard'), findsOneWidget);
      expect(router.canPop(), isFalse);
    });
  }
}
