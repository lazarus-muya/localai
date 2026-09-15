sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class EngineException extends AppException {
  const EngineException(super.message);
}

class StorageException extends AppException {
  const StorageException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}
