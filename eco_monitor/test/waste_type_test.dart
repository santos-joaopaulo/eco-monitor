import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/domain/entities/waste_type.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  test("wasteTypeByName parses the canonical names", () {
    for (final WasteType type in WasteType.values) {
      expect(wasteTypeByName(type.name), type);
    }
  });

  test("wasteTypeByName accepts the legacy singular aliases", () {
    expect(wasteTypeByName("medicine"), WasteType.medicines);
    expect(wasteTypeByName("battery"), WasteType.batteries);
    expect(wasteTypeByName("electronic"), WasteType.electronics);
    expect(wasteTypeByName("glass"), WasteType.glass);
    expect(wasteTypeByName("vidro"), WasteType.glass);
  });

  test("wasteTypeByName tolerates surrounding whitespace and casing", () {
    expect(wasteTypeByName("  Medicines "), WasteType.medicines);
    expect(wasteTypeByName("BATTERIES"), WasteType.batteries);
  });

  test("wasteTypeByName returns null for unknown names", () {
    expect(wasteTypeByName("oil"), isNull);
    expect(wasteTypeByName(""), isNull);
  });

  test("wasteTypesFromJson ignores invalid entries and duplicate types", () {
    expect(
      wasteTypesFromJson(<dynamic>[
        "medicines",
        "medicine",
        "batteries",
        42,
        null,
        "oil",
      ]),
      <WasteType>{WasteType.medicines, WasteType.batteries},
    );
  });

  test("wasteTypesFromJson returns an empty set for non-list values", () {
    expect(wasteTypesFromJson(null), isEmpty);
    expect(wasteTypesFromJson("medicines"), isEmpty);
  });
}
