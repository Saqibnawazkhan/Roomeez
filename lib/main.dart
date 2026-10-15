import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  runApp(
    // Retrying is pointless for permission/validation errors from the mock
    // repositories, so failed providers surface their error immediately.
    ProviderScope(retry: (retryCount, error) => null, child: const RoomeezApp()),
  );
}
