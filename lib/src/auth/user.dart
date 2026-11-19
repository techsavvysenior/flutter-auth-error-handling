import '../api/api_exception.dart';

class User {
  const User({required this.id, required this.name, required this.email});

  /// Validates the payload instead of casting, so a changed or broken API
  /// response surfaces as an [UnexpectedResponseException] and not a crash.
  factory User.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final email = json['email'];
    if (id is! String || name is! String || email is! String) {
      throw const UnexpectedResponseException();
    }
    return User(id: id, name: name, email: email);
  }

  final String id;
  final String name;
  final String email;
}
