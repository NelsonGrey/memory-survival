/// Minimal user shape returned by the platform game-services sign-in.
class AppUser {
  const AppUser({required this.uid, this.displayName, this.email});
  final String uid;
  final String? displayName;
  final String? email;
}
