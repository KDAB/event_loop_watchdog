/*
  This file is part of event_loop_watchdog.

  SPDX-FileCopyrightText: 2023 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
  Author: Sérgio Martins <sergio.martins@kdab.com>

  SPDX-License-Identifier: MIT
*/

/// A minimal example. fibonnacci() will block the event loop and a stack trace
/// will printed saying where it's hanging

import 'dart:async';
import 'package:event_loop_watchdog/event_loop_watchdog.dart';

int fibonacci(int n) {
  if (n == 1 || n == 2) return 1;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

void main() async {
  final wdog =
      WatchDog(allowedEventLoopStallDuration: Duration(milliseconds: 100));
  wdog.start();

  /// Run some expensive computation now and then:
  Timer.periodic(Duration(seconds: 1), (timer) {
    fibonacci(43);
  });
}
