class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

class PaymentException extends AppException {
  PaymentException(super.message, {super.code});
}

class ProjectException extends AppException {
  ProjectException(super.message, {super.code});
}
