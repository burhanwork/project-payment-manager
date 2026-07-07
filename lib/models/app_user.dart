enum UserRole { developer, boss, accountant }

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<dynamic, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.boss,
      ),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get roleDisplayName {
    switch (role) {
      case UserRole.developer:
        return 'Developer';
      case UserRole.boss:
        return 'Boss';
      case UserRole.accountant:
        return 'Accountant';
    }
  }
}
