# synchronized_lite

A locking mechanism for Dart analogous to Java `synchronized` blocks. By wrapping asynchronous
Dart code with `synchronized()`, you can ensure mutually-exclusive, sequential execution of
otherwise parallel operations.

The design of this package was inspired by package
[synchronized](https://pub.dartlang.org/packages/synchronized).
In fact, the API provided by `synchronized_lite` is compatible with `synchronized` and can be used
as a drop-in replacement, except:

* It does not support reenterant locks;
* It does not support timeouts.

## Motivation

In some applications, it can be possible to call an asynchronous function repeatedly,
which may lead to inconsistent state. The problem gets more complex when several different
asynchronous functions change a shared state. I found myself implementing over an over a pattern
that involves storing a future of the currently running asynchronous task and waiting on it before
initiating another asynchronous task.

I discovered [synchronized](https://pub.dartlang.org/packages/synchronized) after implementing my
own version and found that my implementation is much simpler. I did performance tests and
concluded that it's also faster and uses less memory. I decided to
make it available for everyone who doesn't need the bells and whistles of
[synchronized](https://pub.dartlang.org/packages/synchronized) but wants to enjoy the benefits of
`synchronized_lite`, which are:

* Simple and clear implementation.
  You can review the code and understand how it works in a few minutes.
* Linear complexity and minimal memory/CPU overhead.

This package will work in a Flutter app and can be useful for ensuring sequential I/O operations
such as database updates.

## Usage

The example below demonstrates how to ensure that an object is created in the database only once
and that incremental `save()` operations produce a consistent result. Exceptions that occur inside of
the `synchronized()` call get propagated to the caller.

```dart
import 'package:synchronized_lite/synchronized_lite.dart';

abstract class FirebasePersistentModel {

  final _saveLock = Lock();
  Map<String, dynamic> _data;
  DocumentReference _docRef;

  Future<DocumentReference> create() async {
    return await _saveLock.synchronized(() async {
      if(_docRef != null)
        return _docRef;
      _data = _createData();
      _docRef = await _collectionRef.add(_data);
      return _docRef;
    });
  }

  Future<bool> save() async {
    return await _saveLock.synchronized<bool>(() async {
      if(_docRef == null)
        throw Exception("Model has not been created");
      Map<String, dynamic> newData = _createData();
      Map<String, dynamic> changes = getChanges(newData, _data);
      if(changes.length == 0)
        return false;
      await _docRef.setData(changes, merge: true);
      _data = newData;
      return true;
    });
  }

  // implementations of _createData(), getChanges() and other details
  // are omitted in this example.
}
```

Please note that nested `synchronized()` calls on the same lock will produce a deadlock.
Such behavior is precisely what distinguishes non-reenterant locks from reenterant locks,
and `synchronized_lite` locks are non-reenterant:

```dart
import 'package:synchronized_lite/synchronized_lite.dart';

main() async {
  var lock = Lock();
  await lock.synchronized(() async {
    await lock.synchronized(() async {
      // This will never be executed
      print("It works!");
    });
  });
}
```

Another example of using `synchronized()` is provided in the `/example` folder, which uses a Lock
object as a mixin, making synchronized blocks look more Java-like, if you prefer.

If you still need more details,
[synchronized package documentation](https://github.com/tekartik/synchronized.dart)
also has a thorough explanation on how `synchronized()` blocks work.

## Implementation

Below is the entire source code of this package:

```dart
library synchronized_lite;

import 'dart:async';

class Lock {

  Future _last;

  Future<T> synchronized<T>(FutureOr<T> func()) async {
    final prev = _last;
    final completer = Completer();
    _last = completer.future;
    if(prev != null)
      await prev;
    try {
      return await func();
    } finally {
      completer.complete();
    }
  }

}
```

## Testing

I wrote unit tests that ensure `synchronized_lite` works as expected. I
verified that it behaves identically to `synchronized` by running the same tests against
the `synchronized` implementation. Below is the output:

```dart
00:00 +0: Without synchronized(), all incrementers run concurrently
00:00 +1: With synchronized(), all incrementers run sequentially
00:00 +2: Non-async functions work correctly with synchronized()
00:00 +3: Exceptions are propagated
00:00 +4: All tests passed!
```