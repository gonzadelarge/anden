import 'package:get_storage/get_storage.dart';

/// Small key-value store. Values must be JSON-compatible.
abstract class LocalStore {
  T? read<T>(String key);
  Future<void> write(String key, Object? value);
  Future<void> remove(String key);
  Iterable<String> get keys;
}

class GetStorageStore implements LocalStore {
  GetStorageStore([String container = boxName]) : _box = GetStorage(container);

  static const boxName = 'anden';

  final GetStorage _box;

  @override
  T? read<T>(String key) => _box.read<T>(key);

  @override
  Future<void> write(String key, Object? value) => _box.write(key, value);

  @override
  Future<void> remove(String key) => _box.remove(key);

  @override
  Iterable<String> get keys => _box.getKeys<Iterable<String>>();
}

/// In-memory store for tests.
class MemoryStore implements LocalStore {
  final Map<String, Object?> _data = {};

  @override
  T? read<T>(String key) => _data[key] as T?;

  @override
  Future<void> write(String key, Object? value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Iterable<String> get keys => _data.keys.toList();
}
