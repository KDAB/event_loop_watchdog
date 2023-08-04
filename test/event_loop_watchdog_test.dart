/*
  This file is part of event_loop_watchdog.

  SPDX-FileCopyrightText: 2023 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
  Author: Sérgio Martins <sergio.martins@kdab.com>

  SPDX-License-Identifier: MIT
*/

import 'dart:isolate';

import 'package:event_loop_watchdog/watchdog.dart';
import 'package:test/test.dart';

class CustomAction implements Action {
  final SendPort sendPort;

  CustomAction(this.sendPort);

  @override
  void run() {
    print("We detected the event loop was blocked!");
    sendPort.send(true);
  }
}

int fibonacci(int n) {
  if (n == 1 || n == 2) return 1;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

void main() {
  bool detected = false;
  final receivePort = ReceivePort();
  receivePort.listen((message) {
    detected = true;
  });

  final wdog = WatchDog(
      allowedEventLoopStallDuration: Duration(milliseconds: 500),
      callbackAction: CustomAction(receivePort.sendPort));

  wdog.start();

  fibonacci(5);

  test('No blockage was detected', () {
    expect(detected, false);
    fibonacci(44); // block event loop
  });

  test('Blockage was detected', () {
    expect(detected, true);
  });
}
