// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class GoogleUser {
  final String sub;
  final String name;
  final String givenName;
  final String familyName;
  final String picture;
  final String email;
  final bool emailVerified;
  final String locale;
  GoogleUser({
    required this.sub,
    required this.name,
    required this.givenName,
    required this.familyName,
    required this.picture,
    required this.email,
    required this.emailVerified,
    required this.locale,
  });

  GoogleUser copyWith({
    String? sub,
    String? name,
    String? givenName,
    String? familyName,
    String? picture,
    String? email,
    bool? emailVerified,
    String? locale,
    String? firebaseUserId,
  }) {
    return GoogleUser(
      sub: sub ?? this.sub,
      name: name ?? this.name,
      givenName: givenName ?? this.givenName,
      familyName: familyName ?? this.familyName,
      picture: picture ?? this.picture,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      locale: locale ?? this.locale,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sub': sub,
      'name': name,
      'given_name': givenName,
      'family_name': familyName,
      'picture': picture,
      'email': email,
      'email_verified': emailVerified,
      'locale': locale,
    };
  }

  factory GoogleUser.fromMap(Map<String, dynamic> map) {
    return GoogleUser(
      sub: map['sub'] as String? ?? '',
      name: map['name'] as String? ?? '',
      givenName: map['given_name'] as String? ?? '',
      familyName: map['family_name'] as String? ?? '',
      picture: map['picture'] as String? ?? '',
      email: map['email'] as String? ?? '',
      emailVerified: map['email_verified'] as bool? ?? false,
      locale: map['locale'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory GoogleUser.fromJson(String source) =>
      GoogleUser.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'GoogleUser(sub: $sub, name: $name, givenName: $givenName, familyName: $familyName, picture: $picture, email: $email, emailVerified: $emailVerified, locale: $locale)';
  }

  @override
  bool operator ==(covariant GoogleUser other) {
    if (identical(this, other)) return true;

    return other.sub == sub &&
        other.name == name &&
        other.givenName == givenName &&
        other.familyName == familyName &&
        other.picture == picture &&
        other.email == email &&
        other.emailVerified == emailVerified &&
        other.locale == locale;
  }

  @override
  int get hashCode {
    return sub.hashCode ^
        name.hashCode ^
        givenName.hashCode ^
        familyName.hashCode ^
        picture.hashCode ^
        email.hashCode ^
        emailVerified.hashCode ^
        locale.hashCode;
  }
}
