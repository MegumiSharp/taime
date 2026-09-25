import 'db.dart';
import 'tracker.dart';

/// App-wide handles. Top-level variables start lazily, so tests can assign an
/// in-memory database before anything reads these.
Db db = Db();
Tracker tracker = Tracker(db);
