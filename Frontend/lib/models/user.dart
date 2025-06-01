class User {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final bool isStaff;
  final bool isActive;
  final bool emailVerified;
  final String? profilePictureUrl;
  final DateTime? dateOfBirth;
  final DateTime? gdprConsentDate;
  final String? referralCode;
  final DateTime? lastActive;
  final DateTime? dateJoined;
  final String timeZone;
  final String? accessToken;
  final String? refreshToken;
  final int rank;
  final int totalPoints;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isStaff,
    required this.isActive,
    required this.emailVerified,
    this.profilePictureUrl,
    this.dateOfBirth,
    this.gdprConsentDate,
    this.referralCode,
    this.lastActive,
    this.dateJoined,
    required this.timeZone,
    this.accessToken,
    this.refreshToken,
    this.rank = 0,
    this.totalPoints = 0,
  });

  String get name => '$firstName $lastName';
  bool get isAdmin => isStaff;
  String? get avatar => profilePictureUrl;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      isStaff: json['is_staff'] ?? false,
      isActive: json['is_active'] ?? true,
      emailVerified: json['email_verified'] ?? false,
      profilePictureUrl: json['profile_picture_url'],
      dateOfBirth: _parseDateTime(json['date_of_birth']),
      gdprConsentDate: _parseDateTime(json['gdpr_consent_date']),
      referralCode: json['referral_code'],
      lastActive: _parseDateTime(json['last_active']),
      dateJoined: _parseDateTime(json['date_joined']),
      timeZone: json['time_zone'] ?? 'UTC',
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      rank: json['rank'] ?? 0,
      totalPoints: json['total_points'] ?? 0,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is String) {
        return DateTime.parse(value);
      }
      return null;
    } catch (e) {
      print('Error parsing date: $value - $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'is_staff': isStaff,
      'is_active': isActive,
      'email_verified': emailVerified,
      'profile_picture_url': profilePictureUrl,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gdpr_consent_date': gdprConsentDate?.toIso8601String(),
      'referral_code': referralCode,
      'last_active': lastActive?.toIso8601String(),
      'date_joined': dateJoined?.toIso8601String(),
      'time_zone': timeZone,
      'rank': rank,
      'total_points': totalPoints,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    bool? isStaff,
    bool? isActive,
    bool? emailVerified,
    String? profilePictureUrl,
    DateTime? dateOfBirth,
    DateTime? gdprConsentDate,
    String? referralCode,
    DateTime? lastActive,
    DateTime? dateJoined,
    String? timeZone,
    String? accessToken,
    String? refreshToken,
    int? rank,
    int? totalPoints,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      isStaff: isStaff ?? this.isStaff,
      isActive: isActive ?? this.isActive,
      emailVerified: emailVerified ?? this.emailVerified,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gdprConsentDate: gdprConsentDate ?? this.gdprConsentDate,
      referralCode: referralCode ?? this.referralCode,
      lastActive: lastActive ?? this.lastActive,
      dateJoined: dateJoined ?? this.dateJoined,
      timeZone: timeZone ?? this.timeZone,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      rank: rank ?? this.rank,
      totalPoints: totalPoints ?? this.totalPoints,
    );
  }
} 