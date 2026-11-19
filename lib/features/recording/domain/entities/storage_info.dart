import 'package:equatable/equatable.dart';

class StorageInfo extends Equatable {
  const StorageInfo({
    required this.path,
    required this.freeBytes,
    required this.totalBytes,
  });

  /// Folder recordings will be saved to.
  final String path;
  final int freeBytes;
  final int totalBytes;

  @override
  List<Object?> get props => [path, freeBytes, totalBytes];
}
