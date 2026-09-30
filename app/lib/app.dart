import 'db.dart';
import 'tracker.dart';

/// Keep in step with `version:` in pubspec.yaml (a test checks it).
const String kAppVersion = '2.3.0';

/// App-wide handles. Top-level variables start lazily, so tests can assign an
/// in-memory database before anything reads these.
Db db = Db();
Tracker tracker = Tracker(db);
