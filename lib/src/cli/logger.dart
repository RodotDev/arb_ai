// ignore_for_file: avoid_print
import 'dart:io';


/// Minimalist, human-friendly CLI logger.
class Logger {
  final bool verbose;

  const Logger({this.verbose = false});

  /// Prints standard informational message.
  void info(String message) {
    print(message);
  }

  /// Prints a success message prefixed with a checkmark.
  void success(String message) {
    print('✔ $message');
  }

  /// Prints a warning message prefixed with a warning sign.
  void warning(String message) {
    print('⚠ $message');
  }

  /// Prints an error message to standard error.
  void error(String message) {
    stderr.writeln('✗ $message');
  }

  /// Prints debugging/verbose information if enabled.
  void debug(String message) {
    if (verbose) {
      print('⚙ $message');
    }
  }
}
