import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/local_store.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("InMemoryLocalStore", () {
    test("sets, gets and removes values", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();

      expect(await store.getString("str"), isNull);
      expect(await store.getInt("num"), isNull);

      await store.setString("str", "hello");
      await store.setInt("num", 42);

      expect(await store.getString("str"), "hello");
      expect(await store.getInt("num"), 42);

      await store.remove("str");
      expect(await store.getString("str"), isNull);
      expect(await store.getInt("num"), 42);
    });

    test("initializes with initial values map", () async {
      final InMemoryLocalStore store = InMemoryLocalStore(<String, Object>{
        "key1": "value1",
        "key2": 100,
      });

      expect(await store.getString("key1"), "value1");
      expect(await store.getInt("key2"), 100);
    });
  });

  group("SharedPreferencesLocalStore", () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test("interacts with SharedPreferences", () async {
      final SharedPreferencesLocalStore store = SharedPreferencesLocalStore();

      await store.setString("k1", "v1");
      await store.setInt("k2", 99);

      expect(await store.getString("k1"), "v1");
      expect(await store.getInt("k2"), 99);

      await store.remove("k1");
      expect(await store.getString("k1"), isNull);
      expect(await store.getInt("k2"), 99);
    });
  });
}
