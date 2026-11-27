import 'database_bootstrap_io.dart'
    if (dart.library.html) 'database_bootstrap_web.dart' as implementation;

Future<void> initializeDatabaseForPlatform() =>
    implementation.initializeDatabaseForPlatform();