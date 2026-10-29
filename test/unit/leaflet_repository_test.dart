import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/firebase/firebase_services.dart';
import 'package:koala/entity/leaflet_entity.dart';

class _Auth implements FirebaseAuthGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DatabaseReference {
  _Reference(this.path, this.updates, this.values);

  @override
  final String path;
  final Map<String, Map<String, Object?>> updates;
  final StreamController<DatabaseEvent> values;

  @override
  DatabaseReference child(String path) =>
      _Reference('${this.path}/$path', updates, values);

  @override
  Future<void> update(Map<String, Object?> value) async {
    updates[path] = Map.of(value);
  }

  @override
  Stream<DatabaseEvent> get onValue => values.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DataSnapshot {
  _Snapshot(this.value);

  @override
  final Object? value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Event implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);

  @override
  final DataSnapshot snapshot;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Map<String, Map<String, Object?>> updates;
  late StreamController<DatabaseEvent> values;
  late FirebaseLeafletRepository repository;

  setUp(() {
    updates = {};
    values = StreamController<DatabaseEvent>.broadcast();
    repository = FirebaseLeafletRepository(
      _Reference('', updates, values),
      _Auth(),
    );
  });

  tearDown(() async => values.close());

  test('period writes exactly four period fields', () async {
    final first = DateTime.utc(2030, 1, 1);
    final last = DateTime.utc(2030, 1, 3);
    await repository.updateLeafletPeriod(
      'K',
      firstDate: first,
      lastDate: last,
      firstTimeZoneId: 'Asia/Tokyo',
      lastTimeZoneId: 'Europe/Paris',
    );
    expect(updates, {
      '/leaflets/K': {
        'firstDate': first.millisecondsSinceEpoch ~/ 1000,
        'lastDate': last.millisecondsSinceEpoch ~/ 1000,
        'firstTimeZoneId': 'Asia/Tokyo',
        'lastTimeZoneId': 'Europe/Paris',
      },
    });

    await repository.updateLeafletPeriod('K');
    expect(updates['/leaflets/K'], {
      'firstDate': null,
      'lastDate': null,
      'firstTimeZoneId': null,
      'lastTimeZoneId': null,
    });
  });

  test('title and cover never write period or owner fields', () async {
    await repository.updateLeafletTitle('K', 'Latest');
    expect(updates['/leaflets/K'], {'title': 'Latest'});
    await repository.updateLeafletCover(
      'K',
      imageUrl: '🌴',
      coverColor: 0xFF123456,
    );
    expect(updates['/leaflets/K'], {
      'imageUrl': '🌴',
      'coverColor': 0xFF123456,
    });
    await repository.updateLeafletCover('K');
    expect(updates['/leaflets/K'], {'imageUrl': null, 'coverColor': null});
  });

  test(
    'single subscription emits latest, missing and invalid values',
    () async {
      final seen = <LeafletEntity?>[];
      final subscription = repository.watchLeaflet('K').listen(seen.add);
      values
        ..add(_Event({'title': 'Old'}))
        ..add(_Event({'title': 'Latest'}))
        ..add(_Event(null))
        ..add(_Event({'title': 42}));
      await Future<void>.delayed(Duration.zero);
      expect(seen.map((leaflet) => leaflet?.title), [
        'Old',
        'Latest',
        null,
        null,
      ]);
      expect(seen.first!.key, 'K');
      await subscription.cancel();
      expect(values.hasListener, isFalse);
    },
  );

  test(
    'single subscription forwards access errors and can be canceled',
    () async {
      final errors = <Object>[];
      final subscription = repository
          .watchLeaflet('K')
          .listen((_) {}, onError: errors.add, cancelOnError: true);
      final error = Exception('permission-denied');
      values.addError(error);
      await Future<void>.delayed(Duration.zero);
      expect(errors, [error]);
      expect(values.hasListener, isFalse);
      await subscription.cancel();
    },
  );
}
