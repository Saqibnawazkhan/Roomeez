import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_errors.dart';

/// A table to watch, optionally narrowed to rows where [column] equals [value].
class TableWatch {
  const TableWatch(this.table, {this.column, this.value});

  final String table;
  final String? column;
  final Object? value;
}

/// Signals local writes so screens refresh immediately, without waiting for
/// (or depending on) a realtime event.
class RefreshBus {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void ping() => _controller.add(null);
}

int _channelCounter = 0;

/// Emits [fetch]'s result when listened to, then fetches again whenever one of
/// [tables] changes (Supabase Realtime, filtered by row-level security) or
/// the app writes something ([bus]). Errors are emitted as [AppException]s.
Stream<T> liveQuery<T>({
  required SupabaseClient client,
  required RefreshBus bus,
  required String name,
  required List<TableWatch> tables,
  required Future<T> Function() fetch,
}) {
  late final StreamController<T> controller;
  RealtimeChannel? channel;
  StreamSubscription<void>? busSubscription;
  Timer? debounce;
  var closed = false;

  Future<void> load() async {
    try {
      final value = await fetch();
      if (!closed) controller.add(value);
    } catch (error, stackTrace) {
      if (!closed) controller.addError(mapSupabaseError(error), stackTrace);
    }
  }

  void scheduleLoad() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 150), load);
  }

  controller = StreamController<T>(
    onListen: () {
      load();
      busSubscription = bus.stream.listen((_) => scheduleLoad());
      var next = client.channel('$name-${_channelCounter++}');
      for (final watch in tables) {
        next = next.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: watch.table,
          filter: watch.column == null
              ? null
              : PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: watch.column!, value: watch.value),
          callback: (_) => scheduleLoad(),
        );
      }
      channel = next.subscribe();
    },
    onCancel: () async {
      closed = true;
      debounce?.cancel();
      await busSubscription?.cancel();
      final current = channel;
      if (current != null) await client.removeChannel(current);
    },
  );
  return controller.stream;
}
