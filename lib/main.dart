import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'app/providers.dart';
import 'data/backend.dart';
import 'data/supabase/supabase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Without Supabase settings the app runs on in-memory demo data.
  Backend? backend;
  if (AppConfig.useSupabase) {
    backend = await connectSupabase(url: AppConfig.supabaseUrl, key: AppConfig.supabaseKey);
  }

  runApp(
    ProviderScope(
      // Retrying is pointless for permission/validation errors, so failed
      // providers surface their error immediately.
      retry: (retryCount, error) => null,
      overrides: [if (backend != null) backendProvider.overrideWithValue(backend)],
      child: const RoomeezApp(),
    ),
  );
}
