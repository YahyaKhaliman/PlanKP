import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class FlutterSecureStorageAdapter implements SecureStorage {
  const FlutterSecureStorageAdapter([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }
}

class SecureStorageService {
  static SecureStorage _delegate = const FlutterSecureStorageAdapter();

  static SecureStorage get instance => _delegate;

  static set instance(SecureStorage storage) {
    _delegate = storage;
  }

  static Future<String?> read(String key) => _delegate.read(key);

  static Future<void> write(String key, String value) =>
      _delegate.write(key, value);

  static Future<void> delete(String key) => _delegate.delete(key);

  static Future<void> deleteAll() => _delegate.deleteAll();
}
