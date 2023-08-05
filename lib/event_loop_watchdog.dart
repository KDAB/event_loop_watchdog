/*
  This file is part of event_loop_watchdog.

  SPDX-FileCopyrightText: 2023 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
  Author: Sérgio Martins <sergio.martins@kdab.com>

  SPDX-License-Identifier: MIT
*/

import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'package:path/path.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:vm_service/vm_service.dart' hide Isolate;

typedef ActionCreator = Future<Action> Function();

/// Helper internal class to pass arguments to Isolate2
class _WorkerArgs {
  final SendPort sendPort;
  final Duration maxEventloopBlockDuration;
  final String vmServiceUri;
  final Action? _userAction;
  _WorkerArgs(this.sendPort, this.maxEventloopBlockDuration, this.vmServiceUri,
      this._userAction);

  /// Returns the action callback that should be executed when event loop blocks
  Future<Action> action() async {
    if (_userAction == null) {
      return _defaultAction();
    } else {
      return _userAction!;
    }
  }

  /// The default action is to print a stack trace
  Future<Action> _defaultAction() async {
    if (vmServiceUri.isEmpty) {
      print("No service vm url could be determined!\n"
          "Either start your Dart app with --enable-vm-service=<port> or run your Flutter app in Debug mode.\n"
          "Alternatively, you can pass the websocket uri directly through Watchdog() constructor.\n"
          "Or pass your own custom Action callback that doesn't require the vm service, this would allow to use AOT.\n");
      return NullAction();
    } else {
      return await StackTraceAction.createStackTraceAction(vmServiceUri);
    }
  }
}

/// Isolate2 entry point
void _watchdogWorker(_WorkerArgs args) async {
  /// main isolate will ping this
  final pingPort = ReceivePort();

  final stopwatch = Stopwatch();
  bool mainIsolateIsStalled = false;
  stopwatch.start();

  pingPort.listen((ping) {
    if (mainIsolateIsStalled) {
      mainIsolateIsStalled = false;
      print("WatchDog: Main event loop woke up after ${stopwatch.elapsed} ");
    }
    stopwatch.reset();
  });

  Action action = await args.action();

  args.sendPort.send(pingPort.sendPort);

  Timer.periodic(args.maxEventloopBlockDuration, (timer) {
    if (!mainIsolateIsStalled &&
        stopwatch.elapsed > args.maxEventloopBlockDuration) {
      mainIsolateIsStalled = true;

      print(
          "Main event loop has been stalled for ${stopwatch.elapsed.inMilliseconds}ms!");

      /// Print the backtrace, or whatever the provided action does
      action.run();
    }
  });
}

/// The action that will be run once the main event loop stalls
/// The default action is printing a stack trace, but users can provide
/// other actions
abstract class Action {
  void run() async {}
}

/// The default action to run, prints a stack trace, doesn't work in AOT
/// as it requires vm service
class StackTraceAction implements Action {
  final VmService serviceClient;
  StackTraceAction(this.serviceClient);

  static Future<StackTraceAction> createStackTraceAction(
      String serviceUri) async {
    final serviceClient = await vmServiceConnectUri(serviceUri);
    return StackTraceAction(serviceClient);
  }

  @override
  void run() async {
    VM vm = await serviceClient.getVM();
    final mainIsolate =
        vm.isolates!.firstWhere((isolate) => isolate.name == "main");

    serviceClient.getStack(mainIsolate.id!).then((stack) {
      print("Stack trace:");
      for (final Frame frame in stack.frames ?? []) {
        print(
            "    ${frame.function!.name}():${basename(frame.location!.script!.uri!)}:${frame.location!.line}");
      }
    });
  }
}

/// An action that doesn't do anything
class NullAction implements Action {
  @override
  void run() async {}
}

class WatchDog {
  final Duration allowedEventLoopStallDuration;
  final Duration pingFrequency;
  final String serviceUri;
  final Action? callbackAction;

  final _receivePort = ReceivePort();
  SendPort? _sendPort;

  WatchDog(
      {this.allowedEventLoopStallDuration = const Duration(milliseconds: 300),
      this.pingFrequency = const Duration(milliseconds: 10),
      this.serviceUri = "",
      this.callbackAction}) {
    _receivePort.listen((message) {
      assert(_sendPort == null);
      _sendPort = message;
      Timer.periodic(pingFrequency, (timer) {
        _sendPort!.send(null);
      });
    });
  }

  void start() async {
    if (pingFrequency >= allowedEventLoopStallDuration) {
      print(
          "ERROR: Ping frequency should be smaller than max for detection to work");
      return;
    }

    final uri = serviceUri.isEmpty ? await guessVMServiceUri() : serviceUri;
    Isolate.spawn(
        _watchdogWorker,
        _WorkerArgs(_receivePort.sendPort, allowedEventLoopStallDuration, uri,
            callbackAction),
        debugName: "event_loop_watchdog");
  }

  Future<String> guessVMServiceUri() async {
    final info = await Service.getInfo();
    return info.serverWebSocketUri?.toString() ?? "";
  }
}
