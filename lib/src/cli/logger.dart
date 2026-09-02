import 'dart:io';

/// Minimalist, human-friendly CLI logger.
class Logger {
  /// Whether verbose/debug messages should be printed.
  final bool verbose;

  /// Custom output sink (defaults to stdout if null).
  final StringSink? outputSink;

  /// Custom error sink (defaults to stderr if null).
  final StringSink? errorSink;

  /// Creates a [Logger] instance with optional [verbose] logging enabled and optional custom sinks.
  const Logger({this.verbose = false, this.outputSink, this.errorSink});

  StringSink get _out => outputSink ?? stdout;
  StringSink get _err => errorSink ?? stderr;

  /// Prints standard informational message.
  void info(String message) {
    _out.writeln(message);
  }

  /// Prints a success message prefixed with a checkmark.
  void success(String message) {
    _out.writeln('✔ $message');
  }

  /// Prints a warning message prefixed with a warning sign.
  void warning(String message) {
    _out.writeln('⚠ $message');
  }

  /// Prints an error message to standard error.
  void error(String message) {
    _err.writeln('✗ $message');
  }

  /// Prints debugging/verbose information if enabled.
  void debug(String message) {
    if (verbose) {
      _out.writeln('⚙ $message');
    }
  }
}
