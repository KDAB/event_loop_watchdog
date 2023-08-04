A Dart package to help detect whenever your main `event loop` is blocked. Running CPU intensive code
or any blocking code in your main `Isolate` will lead to unresponsive GUIs.<br>

`event_loop_watchdog` will spawn a new `Isolate` to monitor the main one. If the main Isolate is blocked for more than X milliseconds, then a stack trace is printed, which should indicate why it is blocked.

This is a `debugging tool`, do not use it in production.<br>
`event_loop_watchdog` was designed to detect gross stalling, let's say `> 100ms`. It was **not** written to help you find why frames are taking more than `16 ms`, although, it could still be useful for that, if you build in `AOT` mode.


## Features

- Prints a stack trace of your main Isolate whenever it's blocked for a long time.
- You can configure the timeout.
- You can provide your own action callback instead of using the default (which prints a stack trace).


## Usage
The default usage requires a `debug` build. See the [AOT section](#aot) for `release`.

Simply create a `WatchDog` instance and start it.

```dart
import 'package:event_loop_watchdog/watchdog.dart';

void main() {
  final wdog =
      WatchDog(allowedEventLoopStallDuration: Duration(milliseconds: 100));
  wdog.start();
```

```bash
$ dart --enable-vm-service example/main.dart
```
or

```bash
$ cd myapp && flutter run --debug # Or similar
```

For `Flutter`, you probably want to skip `startup`, as that usually blocks the main Isolate a bit:

```dart
  Future.delayed(
    Duration(seconds: 2),
    () {
      final wdog =
          WatchDog(allowedEventLoopStallDuration: Duration(milliseconds: 100));
      wdog.start();
    },
  );
```

### Example output
```bash
Main event loop has been stalled for 199ms!
Stack trace:
    fibonacci():main.dart:16
    fibonacci():main.dart:18
    fibonacci():main.dart:18
    fibonacci():main.dart:18
    fibonacci():main.dart:18
    fibonacci():main.dart:18
    fibonacci():main.dart:18
```

## AOT

A debug build is needed since the `VM service` is required to print the main isolate stack trace.
You can however provide your own callback action which can do other things and does not require VM service. See the [example](example/main2.dart).

I suggest you write a C library that prints a native stacktrace, and call that from your custom `Action`, via FFI. This way you
can still get a stacktrace in release mode, which is better for profiling things.


## Additional information

`event_loop_watchdog` is supported and maintained by Klarälvdalens Datakonsult AB (KDAB).

Please visit <https://www.kdab.com> to meet the people who write code like this.

Stay up-to-date with KDAB product announcements:

- [KDAB Newsletter](https://news.kdab.com)
- [KDAB Blogs](https://www.kdab.com/category/blogs)
- [KDAB on Twitter](https://twitter.com/KDABQt)
