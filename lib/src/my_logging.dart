import 'package:simple_logger/simple_logger.dart';

final _simpleLogger = SimpleLogger();

class Logging {
  // static const _showLogs = true;
  static const _showLogs = false;

  static i(message) {
    if (_showLogs) {
      _simpleLogger.info(message);
    }
  }

  static e(message) {
    if (_showLogs) {
      _simpleLogger.severe(message);
    }
  }

  static f(message) {
    if (_showLogs) {
      _simpleLogger.shout(message);
    }
  }
}
