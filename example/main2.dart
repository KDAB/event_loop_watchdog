/*
  This file is part of event_loop_watchdog.

  SPDX-FileCopyrightText: 2023 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
  Author: Sérgio Martins <sergio.martins@kdab.com>

  SPDX-License-Identifier: MIT
*/

/// Like main.dart, but illustrates how the user can pass a custom action callback

import 'dart:async';
import 'package:event_loop_watchdog/watchdog.dart';

// This recursive fibonacci will block our main loop
int fibonacci(int n) {
  if (n == 1 || n == 2) return 1;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

/// Our custom action will be called whenever event loop stalls
class CustomAction implements Action {
  @override
  void run() {
    print("We detected the event loop was blocked!");
  }
}

void main() {
  final wdog = WatchDog(callbackAction: CustomAction());
  wdog.start();

  /// Run some expensive computation now and then:
  Timer.periodic(Duration(seconds: 1), (timer) {
    fibonacci(43);
  });
}
