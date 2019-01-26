import 'package:synchronized_lite/synchronized_lite.dart';

import 'dart:async';

// Using Lock as a mixin to further mimic Java-style synchronized blocks
class SomeActivity with Lock {

  bool _started = false;

  Future<bool> start() async {
    // It's correct to return a Future returned by synchronized()
    return synchronized(() async {
      if(_started)
        return false;
      // perform the start operation
      await Future.delayed(Duration(seconds: 1));
      print("Started");
      _started = true;
      return true;
    });
  }

  Future<void> stop() async {
    // It's also correct to await a synchronized() call before returning
    // It's incorrect to neither await a synchronized() call or not return its Future.
    await synchronized(() async {
      if(!_started)
        return;
      // perform the stop operation
      await Future.delayed(Duration(seconds: 1));
      print("Stopped");
      _started = false;
    });
  }
}

// Prints:
//   Started
//   Stopped
main() async {
  var a = SomeActivity();
  print("Hello");
  a.start();
  a.start();
  a.stop();
  await a.stop();
}
