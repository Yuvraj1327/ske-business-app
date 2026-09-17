import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_mode_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Light theme is the default; Dark theme is available via Settings and
/// persists across restarts (see theme_mode_provider.dart).
class SkeApp extends ConsumerWidget {
  const SkeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Sai Krishna Enterprises',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
