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

  test(
    "formatCampaignDateRange formats same day, same month, and cross-month",
    () {
      expect(
        formatCampaignDateRange(DateTime(2026, 12, 5), DateTime(2026, 12, 5)),
        "05/12",
      );
      expect(
        formatCampaignDateRange(DateTime(2026, 11, 15), DateTime(2026, 11, 30)),
        "15–30/11",
      );
      expect(
        formatCampaignDateRange(DateTime(2026, 11, 28), DateTime(2026, 12, 5)),
        "28/11–05/12",
      );
    },
  );

  test("formatCampaignPeriod includes dates and optional hours", () {
    expect(
      formatCampaignPeriod(DateTime(2026, 11, 15), DateTime(2026, 11, 30)),
      "15/11/2026 a 30/11/2026",
    );
    expect(
      formatCampaignPeriod(
        DateTime(2026, 11, 15, 8, 0),
        DateTime(2026, 11, 30, 17, 30),
      ),
      "15/11/2026 a 30/11/2026 · 08h às 17h30",
    );
    expect(
      formatCampaignPeriod(
        DateTime(2026, 12, 5, 9, 0),
        DateTime(2026, 12, 5, 16, 0),
      ),
      "05/12/2026 · 09h às 16h",
    );
  });
}
