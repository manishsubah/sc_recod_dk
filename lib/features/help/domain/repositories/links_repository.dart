/// Implementations throw a `Failure` (see `core/errors/failures.dart`).
abstract interface class LinksRepository {
  /// Opens an https:, http: or mailto: link with the default app.
  Future<void> open(Uri link);

  /// e.g. "Windows 10.0.26200", for support emails.
  String get systemDescription;
}
