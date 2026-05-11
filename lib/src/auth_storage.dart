abstract class AuthStorage {
  Future<void> save(String token);

  Future<String?> read();
}
