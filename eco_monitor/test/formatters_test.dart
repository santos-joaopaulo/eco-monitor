import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/utils/formatters.dart";

// Tests -------------------------------------------------------------------- //

void main() {
  test("formatDistance uses meters below one kilometer", () {
    expect(formatDistance(0), "0 m");
    expect(formatDistance(450), "450 m");
    expect(formatDistance(999.4), "999 m");
  });

  test("formatDistance uses kilometers with a decimal comma", () {
    expect(formatDistance(1000), "1,0 km");
    expect(formatDistance(1300), "1,3 km");
    expect(formatDistance(12345), "12,3 km");
  });

  test("formatDistance ignores negative values", () {
    expect(formatDistance(-450), "450 m");
  });

  test("formatDuration uses minutes below one hour", () {
    expect(formatDuration(0), "0 min");
    expect(formatDuration(6), "6 min");
    expect(formatDuration(59.4), "59 min");
  });

  test("formatDuration uses hours and minutes", () {
    expect(formatDuration(60), "1 h");
    expect(formatDuration(65), "1 h 5 min");
    expect(formatDuration(125), "2 h 5 min");
  });
}
