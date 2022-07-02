import 'dart:async';

Future<void> faledFunction() async {
  final completer = Completer<void>();

  await Future.delayed(Duration(seconds: 3));

  completer.completeError("Test error", StackTrace.current);

  return completer.future;
}

void main() async {
  print("start");
  try {
    await faledFunction();
  } catch (e) {
    print("Catched");
    return;
  }

  print("end");
}
