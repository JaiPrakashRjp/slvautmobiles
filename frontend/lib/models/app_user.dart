import 'enums.dart';

/// An authenticated app user — either the Super Admin (the owner) or an Admin
/// (staff). Customers never become an [AppUser].
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    required this.moduleAccess,
    this.photoPath,
    this.aadhaarPath,
    this.signaturePath,
    this.address,
    this.status = AccountStatus.active,
    required this.createdAt,
    this.createdBy,
  });

  final String id;
  String name;
  String phone;
  String? email;
  Role role;
  List<AppModule> moduleAccess;
  String? photoPath;
  String? aadhaarPath;
  String? signaturePath;
  String? address;
  AccountStatus status;
  final DateTime createdAt;
  final String? createdBy;

  bool get isSuperAdmin => role == Role.superAdmin;

  /// Super Admin always has every module; admins are limited to their grants.
  bool canAccess(AppModule m) => isSuperAdmin || moduleAccess.contains(m);

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    List<AppModule>? moduleAccess,
    String? photoPath,
    String? aadhaarPath,
    String? signaturePath,
    String? address,
    AccountStatus? status,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role,
      moduleAccess: moduleAccess ?? this.moduleAccess,
      photoPath: photoPath ?? this.photoPath,
      aadhaarPath: aadhaarPath ?? this.aadhaarPath,
      signaturePath: signaturePath ?? this.signaturePath,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }
}
