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
