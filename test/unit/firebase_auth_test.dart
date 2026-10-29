import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/data/data_types.dart';
import 'package:koala/data/firebase/firebase_services.dart';

class _User implements User {
  Exception? error;
  Completer<void>? pending;
  int deletes = 0;

  @override
  Future<void> reload() async {
    if (error case final error?) throw error;
    await pending?.future;
  }

  @override
  Future<void> delete() async {
    deletes++;
    await pending?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth(this.currentUser);

  @override
  User? currentUser;

  final StreamController<User?> states = StreamController.broadcast();

  @override
  Stream<User?> authStateChanges() => states.stream;

  @override
  Future<void> signOut() async => currentUser = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('signedOut emits only when the user is signed out', () async {
    final user = _User();
    final auth = _Auth(user);
    var events = 0;
    final subscription = FirebaseAuthGateway(auth).signedOut
        .listen((_) => events++);

    auth.states.add(user);
    await Future<void>.delayed(Duration.zero);
    expect(events, 0);

    auth.states.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(events, 1);
    await subscription.cancel();
  });

  test('reload checks the server and sign-out clears the local user', () async {
    final auth = _Auth(_User());
    final gateway = FirebaseAuthGateway(auth);
    expect(await gateway.accountExists(), isTrue);
    await gateway.signOut();
    expect(auth.currentUser, isNull);
    expect(await gateway.accountExists(), isFalse);
  });

  for (final code in [
    'user-not-found',
    'user-token-expired',
    'invalid-user-token',
  ]) {
    test('reload recognizes $code without deleting data', () async {
      final user = _User()..error = FirebaseAuthException(code: code);
      expect(await FirebaseAuthGateway(_Auth(user)).accountExists(), isFalse);
      expect(user.deletes, 0);
    });
  }

  for (final code in [
    'network-request-failed',
    'requires-recent-login',
    'user-disabled',
  ]) {
    test('reload propagates $code rather than signing out', () async {
      final user = _User()..error = FirebaseAuthException(code: code);
      final auth = _Auth(user);
      await expectLater(
        FirebaseAuthGateway(auth).accountExists(),
        throwsA(isA<FirebaseAuthException>()),
      );
      expect(auth.currentUser, same(user));
    });
  }

  testWidgets('a stalled reload fails after 15 seconds', (tester) async {
    final user = _User()..pending = Completer<void>();
    final result = expectLater(
      FirebaseAuthGateway(_Auth(user)).accountExists(),
      throwsA(isA<TimeoutException>()),
    );
    await tester.pump(const Duration(seconds: 15));
    await result;
    user.pending!.complete();
  });

  testWidgets('a stalled delete is unconfirmed after 15 seconds', (
    tester,
  ) async {
    final user = _User()..pending = Completer<void>();
    final result = expectLater(
      FirebaseAuthGateway(_Auth(user)).deleteAccount(),
      throwsA(isA<WriteUnconfirmed>()),
    );
    await tester.pump(const Duration(seconds: 15));
    await result;
    user.pending!.complete();
  });
}
